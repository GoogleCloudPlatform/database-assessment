#!/usr/bin/env python3
# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Check upstream GitHub/oracle.com for newer Oracle Estate Explorer (OEE) scripts via version headers."""

from __future__ import annotations

import argparse
import dataclasses
import gzip
import hashlib
import html
import json
import os
import re
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from html.parser import HTMLParser
from pathlib import Path
from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    from collections.abc import Callable

DEFAULT_OWNER = "oracle-devrel"
DEFAULT_REPO = "terraform-oci-oracle-cloud-foundation"
DEFAULT_REF = "main"
DEFAULT_REMOTE_PATH = "estate-explorer"
DEFAULT_TARGET_DIR = Path("scripts/collector/oracle/oee")
DEFAULT_TIMEOUT_SECONDS = 30
DEFAULT_RELEASE_PAGE_URL = "https://www.oracle.com/downloads/opensource/estate-explorer-source-code-downloads.html"
DEFAULT_RELEASE_LINK_PREFIX = "https://download.oracle.com/otn-pub/oss/ee/"

ALLOWED_API_HOSTS = frozenset({"api.github.com"})
ALLOWED_ORACLE_HOSTS = frozenset({"www.oracle.com", "oracle.com"})
MANAGED_EXTENSIONS = frozenset({".sh", ".sql"})
HTTP_RATE_LIMIT_CODES = frozenset({403, 429})
HEADER_SCAN_LINES = 25

_HEADER_VERSION_RE = re.compile(
    r"(?:OEE|Oracle\s+Estate\s+Explorer)[^\r\n]*?\bv?(\d+(?:\.\d+)+)\b",
    re.IGNORECASE,
)
_ARCHIVE_SUFFIX_RE = re.compile(r"\.(?:tar\.(?:gz|bz2|xz)|tgz|zip|tar)$", re.IGNORECASE)
_URL_VERSION_RE = re.compile(r"(?:^|[-_/vV])(\d+(?:\.\d+)+)(?=$|[-_.])")


@dataclasses.dataclass(frozen=True)
class RemoteFile:
    """Metadata for a single file retrieved from the GitHub Contents API."""

    name: str
    path: str
    sha: str
    size: int
    download_url: str


@dataclasses.dataclass(frozen=True)
class FileDecision:
    """Outcome for a single managed OEE file during synchronization."""

    name: str
    action: str  # "up_to_date", "up_to_date_diff", "unversioned", "new", "updated", "pending_new", "pending_update"
    remote_sha: str
    local_sha: str | None = None
    remote_version: tuple[int, ...] | None = None
    local_version: tuple[int, ...] | None = None
    forced: bool = False


@dataclasses.dataclass
class SyncSummary:
    """Aggregate outcomes from a full OEE sync run."""

    decisions: list[FileDecision] = dataclasses.field(default_factory=list)

    @property
    def changed_count(self) -> int:
        """Return count of files written locally."""
        return sum(1 for d in self.decisions if d.action in {"new", "updated"})

    @property
    def pending_count(self) -> int:
        """Return count of files that would be written during a dry run."""
        return sum(1 for d in self.decisions if d.action in {"pending_new", "pending_update"})


class OeeUpdateError(RuntimeError):
    """Raised when querying, validating, or downloading upstream OEE files fails."""


def git_blob_sha1(data: bytes) -> str:
    """Compute the Git blob SHA-1 digest matching GitHub Contents API ``sha`` values."""
    header = f"blob {len(data)}\0".encode("ascii")
    return hashlib.sha1(header + data, usedforsecurity=False).hexdigest()


def parse_version_tuple(version_str: str) -> tuple[int, ...]:
    """Parse a dot-separated numeric version string into a tuple of ints."""
    parts = [p for p in version_str.strip().lstrip("vV").split(".") if p]
    if not parts or not all(p.isdigit() for p in parts):
        msg = f"Invalid version string: {version_str!r}"
        raise OeeUpdateError(msg)
    return tuple(int(p) for p in parts)


def format_version(version: tuple[int, ...] | None) -> str:
    """Format a version tuple like ``(5, 1)`` as ``'v5.1'`` (or ``'unknown'``)."""
    if version is None:
        return "unknown"
    return f"v{'.'.join(str(p) for p in version)}"


def compare_versions(left: tuple[int, ...], right: tuple[int, ...]) -> int:
    """Compare two numeric version tuples with zero-padding (``(5, 1) == (5, 1, 0)``)."""
    width = max(len(left), len(right))
    padded_left = left + (0,) * (width - len(left))
    padded_right = right + (0,) * (width - len(right))
    if padded_left < padded_right:
        return -1
    if padded_left > padded_right:
        return 1
    return 0


def _version_sort_key(version: tuple[int, ...]) -> tuple[int, ...]:
    """Strip trailing zero components so ``max()`` orders semantic numeric versions canonically."""
    trimmed = list(version)
    while len(trimmed) > 1 and trimmed[-1] == 0:
        trimmed.pop()
    return tuple(trimmed)


def extract_version_from_header(text: str) -> tuple[int, ...] | None:
    """Extract the OEE version from the top comment header lines of an OEE script file."""
    for line in text.splitlines()[:HEADER_SCAN_LINES]:
        match = _HEADER_VERSION_RE.search(line)
        if match:
            return parse_version_tuple(match.group(1))
    return None


def extract_version_from_url(url: str) -> tuple[int, ...] | None:
    """Extract a numeric version tuple from the filename component of an Oracle OEE archive URL."""
    path_name = urllib.parse.urlparse(url).path.rsplit("/", 1)[-1]
    stem = _ARCHIVE_SUFFIX_RE.sub("", path_name)
    matches = _URL_VERSION_RE.findall(stem)
    if not matches:
        return None
    return parse_version_tuple(matches[-1])


def get_local_oee_version(target_dir: Path) -> tuple[int, ...]:
    """Read header comments in ``target_dir`` scripts and return the highest detected version."""
    if not target_dir.is_dir():
        msg = f"Local OEE directory not found: {target_dir}"
        raise OeeUpdateError(msg)

    versions: list[tuple[int, ...]] = []
    for path in sorted(target_dir.iterdir()):
        if not path.is_file() or path.is_symlink():
            continue
        if path.suffix.lower() not in MANAGED_EXTENSIONS:
            continue
        content = path.read_text(encoding="utf-8", errors="replace")
        ver = extract_version_from_header(content)
        if ver is not None:
            versions.append(ver)

    if not versions:
        msg = f"No OEE version header found in scripts inside {target_dir}"
        raise OeeUpdateError(msg)
    return max(versions, key=_version_sort_key)


def validate_safe_filename(name: str) -> str:
    """Validate that ``name`` is a plain basename with no path traversal or separators."""
    if not name or name in {".", ".."} or "/" in name or "\\" in name or name.startswith("."):
        msg = f"Unsafe upstream filename rejected: {name!r}"
        raise OeeUpdateError(msg)
    if Path(name).name != name:
        msg = f"Upstream filename must be a plain basename: {name!r}"
        raise OeeUpdateError(msg)
    return name


def validate_https_url(url: str, allowed_hosts: frozenset[str]) -> str:
    """Ensure ``url`` uses HTTPS and targets one of ``allowed_hosts``."""
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or parsed.hostname not in allowed_hosts:
        msg = f"Refusing untrusted upstream URL: {url!r}"
        raise OeeUpdateError(msg)
    return url


def _build_github_headers(token: str | None, accept: str) -> dict[str, str]:
    headers = {
        "User-Agent": "database-assessment-update-oee",
        "Accept": accept,
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return headers


def http_get_bytes(url: str, *, allowed_hosts: frozenset[str], token: str | None = None, accept: str = "*/*") -> bytes:
    """Fetch bytes from a validated HTTPS GitHub URL."""
    safe_url = validate_https_url(url, allowed_hosts)
    req = urllib.request.Request(safe_url, headers=_build_github_headers(token, accept))
    try:
        with urllib.request.urlopen(req, timeout=DEFAULT_TIMEOUT_SECONDS) as resp:
            return bytes(resp.read())
    except urllib.error.HTTPError as exc:
        if exc.code in HTTP_RATE_LIMIT_CODES:
            hint = " (set GITHUB_TOKEN or GH_TOKEN to raise the GitHub API rate limit)" if not token else ""
            msg = f"GitHub request returned HTTP {exc.code} for {safe_url}{hint}"
            raise OeeUpdateError(msg) from exc
        msg = f"GitHub request failed with HTTP {exc.code} ({exc.reason}) for {safe_url}"
        raise OeeUpdateError(msg) from exc
    except urllib.error.URLError as exc:
        msg = f"Network error fetching {safe_url}: {exc.reason}"
        raise OeeUpdateError(msg) from exc


def http_get_json(url: str, *, token: str | None = None) -> Any:
    """Fetch and decode JSON from the GitHub REST API."""
    raw = http_get_bytes(url, allowed_hosts=ALLOWED_API_HOSTS, token=token, accept="application/vnd.github+json")
    try:
        return json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        msg = f"Invalid JSON received from GitHub API ({url}): {exc}"
        raise OeeUpdateError(msg) from exc


def fetch_remote_files(
    owner: str,
    repo: str,
    ref: str,
    remote_path: str,
    *,
    get_json: Callable[[str], Any],
) -> list[RemoteFile]:
    """List upstream OEE script files (``.sh`` / ``.sql``) in the configured GitHub directory."""
    encoded_path = urllib.parse.quote(remote_path.strip("/"), safe="/")
    encoded_ref = urllib.parse.quote(ref, safe="")
    url = f"https://api.github.com/repos/{owner}/{repo}/contents/{encoded_path}?ref={encoded_ref}"
    payload = get_json(url)
    if not isinstance(payload, list):
        msg = f"Expected a directory listing from GitHub API at {url}"
        raise OeeUpdateError(msg)

    files: list[RemoteFile] = []
    for item in payload:
        if not isinstance(item, dict) or item.get("type") != "file":
            continue
        raw_name = item.get("name")
        if not isinstance(raw_name, str):
            continue
        name = validate_safe_filename(raw_name)
        if Path(name).suffix.lower() not in MANAGED_EXTENSIONS:
            continue
        sha = item.get("sha")
        item_path = item.get("path")
        encoded_file_path = urllib.parse.quote(item_path.strip("/"), safe="/") if isinstance(item_path, str) else ""
        content_url = (
            item.get("url")
            if isinstance(item.get("url"), str)
            else (f"https://api.github.com/repos/{owner}/{repo}/contents/{encoded_file_path}?ref={encoded_ref}")
        )
        size = item.get("size", 0)
        if not isinstance(sha, str) or not isinstance(item_path, str) or not content_url:
            msg = f"Incomplete GitHub API metadata for {name}"
            raise OeeUpdateError(msg)
        validate_https_url(content_url, ALLOWED_API_HOSTS)
        files.append(
            RemoteFile(
                name=name,
                path=item_path,
                sha=sha,
                size=int(size) if isinstance(size, int) else 0,
                download_url=content_url,
            )
        )

    if not files:
        msg = f"No managed OEE scripts ({', '.join(sorted(MANAGED_EXTENSIONS))}) found at {owner}/{repo}/{remote_path}@{ref}"
        raise OeeUpdateError(msg)
    return sorted(files, key=lambda entry: entry.name)


def atomic_write_file(dest: Path, content: bytes, mode: int) -> None:
    """Write ``content`` to ``dest`` atomically, setting permissions before renaming."""
    if dest.is_symlink():
        msg = f"Refusing to overwrite symlink: {dest}"
        raise OeeUpdateError(msg)
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(dir=dest.parent, prefix=f".{dest.name}.", suffix=".tmp", delete=False) as fh:
            tmp_path = Path(fh.name)
            fh.write(content)
            fh.flush()
            os.fsync(fh.fileno())
        tmp_path.chmod(mode)
        tmp_path.replace(dest)
        tmp_path = None
    finally:
        if tmp_path is not None and tmp_path.exists():
            tmp_path.unlink(missing_ok=True)


def _download_verified(remote: RemoteFile, fetch_bytes: Callable[[str], bytes]) -> bytes:
    """Download ``remote`` bytes and verify integrity against its GitHub blob SHA-1."""
    data = fetch_bytes(remote.download_url)
    actual_sha = git_blob_sha1(data)
    if actual_sha != remote.sha:
        msg = f"SHA-1 mismatch for {remote.name}: expected GitHub blob {remote.sha}, got {actual_sha}"
        raise OeeUpdateError(msg)
    return data


def _target_mode_for(filename: str) -> int:
    return 0o755 if filename.endswith(".sh") else 0o644


def sync_oee_files(
    *,
    target_dir: Path,
    owner: str = DEFAULT_OWNER,
    repo: str = DEFAULT_REPO,
    ref: str = DEFAULT_REF,
    remote_path: str = DEFAULT_REMOTE_PATH,
    check_only: bool = False,
    force: bool = False,
    get_json: Callable[[str], Any] | None = None,
    fetch_bytes: Callable[[str], bytes] | None = None,
    token: str | None = None,
) -> SyncSummary:
    """Compare local OEE scripts against GitHub file header versions and update any missing or newer files."""
    if token is None:
        token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN") or None

    json_fetcher = get_json or (lambda url: http_get_json(url, token=token))
    bytes_fetcher = fetch_bytes or (
        lambda url: http_get_bytes(
            url,
            allowed_hosts=ALLOWED_API_HOSTS,
            token=token,
            accept="application/vnd.github.raw+json",
        )
    )

    remote_files = fetch_remote_files(owner, repo, ref, remote_path, get_json=json_fetcher)
    summary = SyncSummary()

    for remote in remote_files:
        local_path = target_dir / remote.name
        if local_path.is_symlink():
            msg = f"Refusing to manage symlink at {local_path}"
            raise OeeUpdateError(msg)

        if not local_path.exists():
            if check_only:
                summary.decisions.append(
                    FileDecision(
                        name=remote.name,
                        action="pending_new",
                        remote_sha=remote.sha,
                    )
                )
            else:
                data = _download_verified(remote, bytes_fetcher)
                remote_ver = extract_version_from_header(data.decode("utf-8", errors="replace"))
                atomic_write_file(local_path, data, _target_mode_for(remote.name))
                summary.decisions.append(
                    FileDecision(
                        name=remote.name,
                        action="new",
                        remote_sha=remote.sha,
                        remote_version=remote_ver,
                    )
                )
            continue

        local_bytes = local_path.read_bytes()
        local_sha = git_blob_sha1(local_bytes)
        local_ver = extract_version_from_header(local_bytes.decode("utf-8", errors="replace"))
        if local_sha == remote.sha and not force:
            summary.decisions.append(
                FileDecision(
                    name=remote.name,
                    action="up_to_date",
                    remote_sha=remote.sha,
                    local_sha=local_sha,
                    remote_version=local_ver,
                    local_version=local_ver,
                )
            )
            continue

        remote_bytes = _download_verified(remote, bytes_fetcher)
        remote_ver = extract_version_from_header(remote_bytes.decode("utf-8", errors="replace"))

        is_newer = local_ver is not None and remote_ver is not None and compare_versions(remote_ver, local_ver) > 0
        if force or is_newer:
            is_forced = force and not is_newer
            if check_only:
                summary.decisions.append(
                    FileDecision(
                        name=remote.name,
                        action="pending_update",
                        remote_sha=remote.sha,
                        local_sha=local_sha,
                        remote_version=remote_ver,
                        local_version=local_ver,
                        forced=is_forced,
                    )
                )
            else:
                atomic_write_file(local_path, remote_bytes, _target_mode_for(remote.name))
                summary.decisions.append(
                    FileDecision(
                        name=remote.name,
                        action="updated",
                        remote_sha=remote.sha,
                        local_sha=local_sha,
                        remote_version=remote_ver,
                        local_version=local_ver,
                        forced=is_forced,
                    )
                )
        elif local_ver is None or remote_ver is None:
            summary.decisions.append(
                FileDecision(
                    name=remote.name,
                    action="unversioned",
                    remote_sha=remote.sha,
                    local_sha=local_sha,
                    remote_version=remote_ver,
                    local_version=local_ver,
                )
            )
        else:
            summary.decisions.append(
                FileDecision(
                    name=remote.name,
                    action="up_to_date_diff",
                    remote_sha=remote.sha,
                    local_sha=local_sha,
                    remote_version=remote_ver,
                    local_version=local_ver,
                )
            )

    return summary


def print_summary(summary: SyncSummary, *, check_only: bool) -> None:
    """Print a concise per-file status report for ``summary``."""
    for d in summary.decisions:
        r_ver = format_version(d.remote_version)
        l_ver = format_version(d.local_version)

        if d.action == "up_to_date":
            print(f"  [up to date] {d.name} ({l_ver}; matches GitHub blob {d.remote_sha[:12]})")
        elif d.action == "up_to_date_diff":
            print(
                f"  [up to date] {d.name} (GitHub {r_ver} <= local {l_ver}; content differs, pass FORCE=1 to overwrite)"
            )
        elif d.action == "unversioned":
            print(
                f"  [skipped]    {d.name} "
                f"(unable to compare header versions: GitHub {r_ver}, local {l_ver}; pass FORCE=1 to overwrite)"
            )
        elif d.action == "new":
            print(f"  [added]      {d.name} ({r_ver})")
        elif d.action == "updated":
            reason = "forced overwrite" if d.forced else f"{l_ver} -> {r_ver}"
            print(f"  [updated]    {d.name} ({reason})")
        elif d.action == "pending_new":
            print(f"  [new avail]  {d.name} (dry-run)")
        elif d.action == "pending_update":
            reason = f"forced overwrite, GitHub {r_ver}, local {l_ver}" if d.forced else f"{l_ver} -> {r_ver}"
            print(f"  [newer]      {d.name} ({reason}; dry-run)")

    if check_only:
        print(f"Check complete: {summary.pending_count} file(s) would be added/updated.")
    elif summary.changed_count > 0:
        print(f"Updated {summary.changed_count} Oracle Estate Explorer file(s).")
    else:
        print("All local Oracle Estate Explorer files are already up to date.")


class _ReleaseLinkParser(HTMLParser):
    """Collect candidate download links matching ``prefix`` from HTML attributes."""

    def __init__(self, prefix: str, base_url: str) -> None:
        super().__init__(convert_charrefs=True)
        self._prefix = prefix
        self._base_url = base_url
        self.links: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        del tag
        for attr_name, attr_val in attrs:
            if not attr_val or attr_name.lower() not in {"href", "data-file", "data-url", "data-download"}:
                continue
            resolved = urllib.parse.urljoin(self._base_url, attr_val.strip())
            if resolved.startswith(self._prefix) and resolved not in self.links:
                self.links.append(resolved)


def extract_release_links(
    page_html: str,
    prefix: str = DEFAULT_RELEASE_LINK_PREFIX,
    *,
    base_url: str = DEFAULT_RELEASE_PAGE_URL,
) -> list[str]:
    """Find unique download URLs starting with ``prefix`` inside an HTML document."""
    parser = _ReleaseLinkParser(prefix, base_url)
    parser.feed(page_html)
    parser.close()

    links = list(parser.links)
    parsed_prefix = urllib.parse.urlparse(prefix)
    no_scheme_prefix = prefix.removeprefix(f"{parsed_prefix.scheme}:") if parsed_prefix.scheme else prefix
    patterns = [prefix]
    if no_scheme_prefix != prefix and no_scheme_prefix.startswith("//"):
        patterns.append(no_scheme_prefix)

    unescaped = html.unescape(page_html)
    for pat in patterns:
        url_re = re.compile(re.escape(pat) + r"""[^\s"'<>()]+""")
        for match in url_re.finditer(unescaped):
            candidate = urllib.parse.urljoin(base_url, match.group(0).rstrip(".,;:"))
            if candidate.startswith(prefix) and candidate not in links:
                links.append(candidate)
    return links


def fetch_release_page_html(page_url: str = DEFAULT_RELEASE_PAGE_URL) -> str:
    """Download the Oracle Estate Explorer open-source downloads HTML page."""
    safe_url = validate_https_url(page_url, ALLOWED_ORACLE_HOSTS)
    headers = {
        "User-Agent": "Mozilla/5.0 (compatible; database-assessment-oee-check/1.0)",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Encoding": "gzip, identity",
    }
    req = urllib.request.Request(safe_url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=DEFAULT_TIMEOUT_SECONDS) as resp:
            raw = bytes(resp.read())
            encoding = (resp.headers.get("Content-Encoding") or "").lower()
    except urllib.error.HTTPError as exc:
        msg = f"Failed to fetch Oracle release page ({safe_url}): HTTP {exc.code} ({exc.reason})"
        raise OeeUpdateError(msg) from exc
    except urllib.error.URLError as exc:
        msg = f"Network error fetching Oracle release page ({safe_url}): {exc.reason}"
        raise OeeUpdateError(msg) from exc

    if encoding == "gzip" or raw.startswith(b"\x1f\x8b"):
        raw = gzip.decompress(raw)
    return raw.decode("utf-8", errors="replace")


def check_oee_release(
    *,
    target_dir: Path,
    page_url: str = DEFAULT_RELEASE_PAGE_URL,
    link_prefix: str = DEFAULT_RELEASE_LINK_PREFIX,
    fetch_html: Callable[[str], str] | None = None,
) -> str | None:
    """Return the latest download URL if higher than the local OEE header version, else ``None``."""
    local_version = get_local_oee_version(target_dir)
    html_fetcher = fetch_html or fetch_release_page_html
    page_html = html_fetcher(page_url)

    candidates = extract_release_links(page_html, link_prefix, base_url=page_url)
    versioned: list[tuple[tuple[int, ...], str]] = []
    for link in candidates:
        ver = extract_version_from_url(link)
        if ver is not None:
            versioned.append((ver, link))

    if not versioned:
        msg = f"No versioned OEE download link starting with {link_prefix!r} found at {page_url}"
        raise OeeUpdateError(msg)

    latest_version, latest_link = max(versioned, key=lambda pair: _version_sort_key(pair[0]))
    if compare_versions(latest_version, local_version) > 0:
        return latest_link
    return None


def build_arg_parser() -> argparse.ArgumentParser:
    """Build CLI argument parser for ``update_oee.py``."""
    parser = argparse.ArgumentParser(
        description="Check upstream GitHub for newer Oracle Estate Explorer (OEE) scripts by file header version.",
    )
    parser.add_argument("--owner", default=DEFAULT_OWNER, help=f"GitHub owner/org (default: {DEFAULT_OWNER})")
    parser.add_argument("--repo", default=DEFAULT_REPO, help=f"GitHub repo (default: {DEFAULT_REPO})")
    parser.add_argument("--ref", default=DEFAULT_REF, help=f"Git ref/branch/tag (default: {DEFAULT_REF})")
    parser.add_argument(
        "--remote-path",
        default=DEFAULT_REMOTE_PATH,
        help=f"Path inside repository (default: {DEFAULT_REMOTE_PATH})",
    )
    parser.add_argument(
        "--target-dir",
        type=Path,
        default=DEFAULT_TARGET_DIR,
        help=f"Local OEE script directory (default: {DEFAULT_TARGET_DIR})",
    )
    parser.add_argument("--check", action="store_true", help="Check for updates without modifying local files.")
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite local files with exact upstream copies regardless of header version.",
    )
    parser.add_argument(
        "--check-release",
        action="store_true",
        help="Check oracle.com download page and print the newer OEE release link, or 'null'.",
    )
    parser.add_argument(
        "--release-page-url",
        default=DEFAULT_RELEASE_PAGE_URL,
        help=f"Oracle downloads page URL for --check-release (default: {DEFAULT_RELEASE_PAGE_URL})",
    )
    parser.add_argument(
        "--release-link-prefix",
        default=DEFAULT_RELEASE_LINK_PREFIX,
        help=f"Expected OEE download link prefix (default: {DEFAULT_RELEASE_LINK_PREFIX})",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    """CLI entrypoint for checking/updating OEE scripts."""
    args = build_arg_parser().parse_args(argv)
    repo_root = Path(__file__).resolve().parents[1]
    target_dir = args.target_dir if args.target_dir.is_absolute() else (repo_root / args.target_dir)

    if args.check_release:
        try:
            newer_link = check_oee_release(
                target_dir=target_dir,
                page_url=args.release_page_url,
                link_prefix=args.release_link_prefix,
            )
        except OeeUpdateError as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return 1
        print(newer_link if newer_link is not None else "null")
        return 0

    print(f"Source: https://github.com/{args.owner}/{args.repo}/tree/{args.ref}/{args.remote_path}")
    print(f"Target: {target_dir}")
    try:
        summary = sync_oee_files(
            target_dir=target_dir,
            owner=args.owner,
            repo=args.repo,
            ref=args.ref,
            remote_path=args.remote_path,
            check_only=args.check,
            force=args.force,
        )
    except OeeUpdateError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    print_summary(summary, check_only=args.check)
    return 0


if __name__ == "__main__":
    sys.exit(main())
