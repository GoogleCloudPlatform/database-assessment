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
"""Unit tests for ``tools/update_oee.py`` and the ``update-oee`` / ``check_oee_release`` Make targets."""

from __future__ import annotations

import shutil
import stat
import subprocess
import sys
import urllib.error
from io import BytesIO
from pathlib import Path
from typing import Any

import pytest

from tools import update_oee

pytestmark = [pytest.mark.unit]

REPO_ROOT = Path(__file__).resolve().parents[2]


def _make_remote_entry(name: str, data: bytes, *, path_prefix: str = "estate-explorer") -> dict[str, Any]:
    """Build a GitHub Contents API response dict for a single file."""
    return {
        "name": name,
        "path": f"{path_prefix}/{name}",
        "sha": update_oee.git_blob_sha1(data),
        "size": len(data),
        "type": "file",
        "url": (
            f"https://api.github.com/repos/oracle-devrel/terraform-oci-oracle-cloud-foundation/contents/{path_prefix}/{name}?ref=main"
        ),
        "download_url": (
            f"https://raw.githubusercontent.com/oracle-devrel/terraform-oci-oracle-cloud-foundation/main/{path_prefix}/{name}"
        ),
    }


class TestHelpers:
    """Verify hash, version, URL, and filename validation helpers."""

    def test_git_blob_sha1_matches_git_hash_object(self) -> None:
        sample = REPO_ROOT / "scripts/collector/oracle/oee/oee_group_extract-SA.sh"
        actual = update_oee.git_blob_sha1(sample.read_bytes())
        git_bin = shutil.which("git")
        if git_bin:
            out = subprocess.run([git_bin, "hash-object", str(sample)], capture_output=True, text=True, check=True)
            assert actual == out.stdout.strip()
        assert len(actual) == 40

    @pytest.mark.parametrize("bad_name", ["", ".", "..", "../evil.sh", "a/b.sh", r"a\b.sql", ".hidden.sh"])
    def test_validate_safe_filename_rejects_unsafe_names(self, bad_name: str) -> None:
        with pytest.raises(update_oee.OeeUpdateError):
            update_oee.validate_safe_filename(bad_name)

    @pytest.mark.parametrize(
        "bad_url",
        [
            "http://api.github.com/repos/a/b",
            "file:///etc/passwd",
            "https://evil.example.com/oee.sh",
            "javascript:alert(1)",
        ],
    )
    def test_validate_https_url_rejects_untrusted_urls(self, bad_url: str) -> None:
        with pytest.raises(update_oee.OeeUpdateError):
            update_oee.validate_https_url(bad_url, update_oee.ALLOWED_API_HOSTS)

    def test_fetch_remote_files_filters_only_sh_and_sql(self) -> None:
        entries = [
            _make_remote_entry("Readme.md", b""),
            _make_remote_entry("oee_group_extract-SA.sh", b"#!/bin/bash\n"),
            _make_remote_entry("oee_group_metrics-SA.sql", b"select 1;\n"),
            {"name": "subdir", "type": "dir", "path": "estate-explorer/subdir"},
        ]
        found = update_oee.fetch_remote_files(
            "oracle-devrel",
            "terraform-oci-oracle-cloud-foundation",
            "main",
            "estate-explorer",
            get_json=lambda _url: entries,
        )
        assert [f.name for f in found] == ["oee_group_extract-SA.sh", "oee_group_metrics-SA.sql"]

    def test_fetch_remote_files_raises_when_empty(self) -> None:
        with pytest.raises(update_oee.OeeUpdateError, match="No managed OEE scripts"):
            update_oee.fetch_remote_files(
                "oracle-devrel",
                "terraform-oci-oracle-cloud-foundation",
                "main",
                "estate-explorer",
                get_json=lambda _url: [_make_remote_entry("Readme.md", b"docs")],
            )

    def test_rate_limit_error_includes_token_hint_without_leaking_token(self, monkeypatch: pytest.MonkeyPatch) -> None:
        api_url = "https://api.github.com/repos/x/y/contents/z"
        err_msg = "rate limit exceeded"

        def fake_urlopen(*_args: object, **_kwargs: object) -> object:
            raise urllib.error.HTTPError(
                api_url,
                403,
                err_msg,
                hdrs={},  # type: ignore[arg-type]
                fp=BytesIO(b""),
            )

        monkeypatch.setattr(update_oee.urllib.request, "urlopen", fake_urlopen)
        with pytest.raises(update_oee.OeeUpdateError, match="GITHUB_TOKEN"):
            update_oee.http_get_bytes(
                api_url,
                allowed_hosts=update_oee.ALLOWED_API_HOSTS,
                token=None,
            )

        secret_tok = "ghp_super_secret_token_value"
        with pytest.raises(update_oee.OeeUpdateError) as exc_info:
            update_oee.http_get_bytes(
                api_url,
                allowed_hosts=update_oee.ALLOWED_API_HOSTS,
                token=secret_tok,
            )
        assert secret_tok not in str(exc_info.value)


class TestSyncOeeFiles:
    """Exercise header-version-based sync, updating, dry-run, force, and error handling."""

    def test_identical_sha_skips_download(self, tmp_path: Path) -> None:
        script_bytes = b"#!/bin/bash\n# * OEE Group Extract Standalone v5.1\n"
        sql_bytes = b"REM * OEE Group Extract StandAlone v5.1\n"
        oee_dir = tmp_path / "oee"
        oee_dir.mkdir()
        (oee_dir / "oee_group_extract-SA.sh").write_bytes(script_bytes)
        (oee_dir / "oee_group_metrics-SA.sql").write_bytes(sql_bytes)

        downloads: list[str] = []

        def fake_get_json(_url: str) -> Any:
            return [
                _make_remote_entry("Readme.md", b""),
                _make_remote_entry("oee_group_extract-SA.sh", script_bytes),
                _make_remote_entry("oee_group_metrics-SA.sql", sql_bytes),
            ]

        summary = update_oee.sync_oee_files(
            target_dir=oee_dir,
            get_json=fake_get_json,
            fetch_bytes=lambda url: downloads.append(url) or b"",  # type: ignore[func-returns-value]
        )
        assert downloads == []
        assert summary.changed_count == 0
        assert [d.action for d in summary.decisions] == ["up_to_date", "up_to_date"]
        assert all(d.local_version == (5, 1) for d in summary.decisions)

    @pytest.mark.parametrize(
        ("local_ver", "remote_ver"),
        [
            ("v5.1", "v5.1"),
            ("v5.1", "v5.1.0"),
            ("v5.1", "v5.0"),
            ("v6.1.1", "v5.1"),
        ],
    )
    def test_same_or_older_remote_header_does_not_overwrite_local_file(
        self, tmp_path: Path, local_ver: str, remote_ver: str
    ) -> None:
        local_sh = f"#!/bin/bash\n# * OEE Group Extract Standalone {local_ver}\necho trimmed\n".encode()
        remote_sh = f"#!/bin/bash\n# * OEE Group Extract Standalone {remote_ver}\necho trimmed   \n".encode()
        oee_dir = tmp_path / "oee"
        oee_dir.mkdir()
        target = oee_dir / "oee_group_extract-SA.sh"
        target.write_bytes(local_sh)

        summary = update_oee.sync_oee_files(
            target_dir=oee_dir,
            get_json=lambda _u: [_make_remote_entry("oee_group_extract-SA.sh", remote_sh)],
            fetch_bytes=lambda _u: remote_sh,
        )
        assert summary.changed_count == 0
        assert summary.decisions[0].action == "up_to_date_diff"
        assert target.read_bytes() == local_sh

    def test_newer_remote_header_and_new_file_are_updated_with_expected_modes(self, tmp_path: Path) -> None:
        old_sh = b"#!/bin/bash\n# * OEE Group Extract Standalone v5.1\necho old\n"
        new_sh = b"#!/bin/bash\n# * OEE Group Extract Standalone v6.1.1\necho new\n"
        old_sql = b"REM * OEE Group Extract StandAlone v5.2\n"
        new_sql = b"REM * OEE Group Extract StandAlone v5.10\n"
        new_sec_sql = b"REM * OEE Group Security Extract StandAlone v6.1.1\n"

        oee_dir = tmp_path / "oee"
        oee_dir.mkdir()
        (oee_dir / "oee_group_extract-SA.sh").write_bytes(old_sh)
        (oee_dir / "oee_group_metrics-SA.sql").write_bytes(old_sql)

        payloads = {
            "oee_group_extract-SA.sh": new_sh,
            "oee_group_metrics-SA.sql": new_sql,
            "oee_group_dbsecurity-SA.sql": new_sec_sql,
        }

        summary = update_oee.sync_oee_files(
            target_dir=oee_dir,
            get_json=lambda _u: [
                _make_remote_entry("oee_group_extract-SA.sh", new_sh),
                _make_remote_entry("oee_group_metrics-SA.sql", new_sql),
                _make_remote_entry("oee_group_dbsecurity-SA.sql", new_sec_sql),
            ],
            fetch_bytes=lambda url: payloads[url.split("?", 1)[0].rsplit("/", 1)[-1]],
        )
        assert summary.changed_count == 3
        actions = {d.name: d.action for d in summary.decisions}
        assert actions == {
            "oee_group_dbsecurity-SA.sql": "new",
            "oee_group_extract-SA.sh": "updated",
            "oee_group_metrics-SA.sql": "updated",
        }
        assert (oee_dir / "oee_group_extract-SA.sh").read_bytes() == new_sh
        assert (oee_dir / "oee_group_metrics-SA.sql").read_bytes() == new_sql
        assert (oee_dir / "oee_group_dbsecurity-SA.sql").read_bytes() == new_sec_sql
        if sys.platform != "win32":
            assert stat.S_IMODE((oee_dir / "oee_group_extract-SA.sh").stat().st_mode) == 0o755
            assert stat.S_IMODE((oee_dir / "oee_group_metrics-SA.sql").stat().st_mode) == 0o644
            assert stat.S_IMODE((oee_dir / "oee_group_dbsecurity-SA.sql").stat().st_mode) == 0o644

    def test_unversioned_header_skipped_safely_without_force(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        local_sh = b"#!/bin/bash\necho no header\n"
        remote_sh = b"#!/bin/bash\n# * OEE Group Extract Standalone v6.1.1\n"
        oee_dir = tmp_path / "oee"
        oee_dir.mkdir()
        (oee_dir / "oee_group_extract-SA.sh").write_bytes(local_sh)

        summary = update_oee.sync_oee_files(
            target_dir=oee_dir,
            get_json=lambda _u: [_make_remote_entry("oee_group_extract-SA.sh", remote_sh)],
            fetch_bytes=lambda _u: remote_sh,
        )
        assert summary.changed_count == 0
        assert summary.decisions[0].action == "unversioned"
        assert (oee_dir / "oee_group_extract-SA.sh").read_bytes() == local_sh
        update_oee.print_summary(summary, check_only=False)
        assert "[skipped]" in capsys.readouterr().out

    def test_check_only_does_not_modify_local_files(self, tmp_path: Path) -> None:
        old_sh = b"#!/bin/bash\n# * OEE Group Extract Standalone v5.1\n"
        new_sh = b"#!/bin/bash\n# * OEE Group Extract Standalone v6.1.1\n"
        new_sql = b"REM * OEE Group Security Extract StandAlone v6.1.1\n"
        oee_dir = tmp_path / "oee"
        oee_dir.mkdir()
        (oee_dir / "oee_group_extract-SA.sh").write_bytes(old_sh)

        summary = update_oee.sync_oee_files(
            target_dir=oee_dir,
            check_only=True,
            get_json=lambda _u: [
                _make_remote_entry("oee_group_extract-SA.sh", new_sh),
                _make_remote_entry("oee_group_dbsecurity-SA.sql", new_sql),
            ],
            fetch_bytes=lambda url: new_sh if url.split("?", 1)[0].endswith(".sh") else new_sql,
        )
        assert summary.changed_count == 0
        assert summary.pending_count == 2
        assert (oee_dir / "oee_group_extract-SA.sh").read_bytes() == old_sh
        assert not (oee_dir / "oee_group_dbsecurity-SA.sql").exists()

    def test_force_overwrites_same_version_and_marks_forced(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        local_sh = b"#!/bin/bash\n# * OEE Group Extract Standalone v5.1\necho local\n"
        remote_sh = b"#!/bin/bash\n# * OEE Group Extract Standalone v5.1\necho upstream   \n"
        oee_dir = tmp_path / "oee"
        oee_dir.mkdir()
        target = oee_dir / "oee_group_extract-SA.sh"
        target.write_bytes(local_sh)

        summary = update_oee.sync_oee_files(
            target_dir=oee_dir,
            force=True,
            get_json=lambda _u: [_make_remote_entry("oee_group_extract-SA.sh", remote_sh)],
            fetch_bytes=lambda _u: remote_sh,
        )
        assert summary.changed_count == 1
        assert summary.decisions[0].action == "updated"
        assert summary.decisions[0].forced is True
        assert target.read_bytes() == remote_sh
        update_oee.print_summary(summary, check_only=False)
        assert "forced overwrite" in capsys.readouterr().out

    def test_sha_mismatch_aborts_without_modifying_local_file(self, tmp_path: Path) -> None:
        local_sh = b"#!/bin/bash\n# * OEE Group Extract Standalone v5.1\necho original\n"
        oee_dir = tmp_path / "oee"
        oee_dir.mkdir()
        target = oee_dir / "oee_group_extract-SA.sh"
        target.write_bytes(local_sh)

        with pytest.raises(update_oee.OeeUpdateError, match="SHA-1 mismatch"):
            update_oee.sync_oee_files(
                target_dir=oee_dir,
                get_json=lambda _u: [
                    _make_remote_entry("oee_group_extract-SA.sh", b"# * OEE Group Extract Standalone v6.1.1\n")
                ],
                fetch_bytes=lambda _u: b"CORRUPTED_BYTES",
            )
        assert target.read_bytes() == local_sh
        assert list(oee_dir.glob("*.tmp")) == []

    @pytest.mark.skipif(sys.platform == "win32", reason="Symlink test requires POSIX semantics")
    def test_refuses_to_overwrite_symlink(self, tmp_path: Path) -> None:
        oee_dir = tmp_path / "oee"
        oee_dir.mkdir()
        outside = tmp_path / "outside.txt"
        outside.write_text("keep", encoding="utf-8")
        (oee_dir / "oee_group_extract-SA.sh").symlink_to(outside)

        with pytest.raises(update_oee.OeeUpdateError, match="symlink"):
            update_oee.sync_oee_files(
                target_dir=oee_dir,
                get_json=lambda _u: [_make_remote_entry("oee_group_extract-SA.sh", b"new")],
                fetch_bytes=lambda _u: b"new",
            )
        assert outside.read_text(encoding="utf-8") == "keep"


class TestCheckOeeRelease:
    """Verify ``check_oee_release`` version header parsing, HTML link scraping, and output."""

    def test_detects_local_repo_oee_version(self) -> None:
        oee_dir = REPO_ROOT / "scripts/collector/oracle/oee"
        assert update_oee.get_local_oee_version(oee_dir) == (5, 1)

    @pytest.mark.parametrize(
        ("url", "expected"),
        [
            (
                "https://download.oracle.com/otn-pub/oss/ee/oracle-estate-explorer-v6.1.1.zip",
                (6, 1, 1),
            ),
            (
                "https://download.oracle.com/otn-pub/oss/ee/oracle-estate-explorer-6.2.zip",
                (6, 2),
            ),
            (
                "https://download.oracle.com/otn-pub/oss/ee/oee-v10.0.12.tar.gz",
                (10, 0, 12),
            ),
            (
                "https://download.oracle.com/otn-pub/oss/ee/oee_5.1.zip",
                (5, 1),
            ),
            (
                "https://download.oracle.com/otn-pub/oss/ee/oee-v6.1.1-linux.zip",
                (6, 1, 1),
            ),
            (
                "https://download.oracle.com/otn-pub/oss/ee/unversioned.zip",
                None,
            ),
        ],
    )
    def test_extract_version_from_url(self, url: str, expected: tuple[int, ...] | None) -> None:
        assert update_oee.extract_version_from_url(url) == expected

    @pytest.mark.parametrize(
        ("left", "right", "expected"),
        [
            ((6, 1, 1), (5, 1), 1),
            ((5, 10), (5, 2), 1),
            ((5, 1, 0), (5, 1), 0),
            ((6, 1, 1), (6, 1, 1), 0),
            ((5, 0), (5, 1), -1),
            ((5, 1), (6, 0), -1),
        ],
    )
    def test_compare_versions(self, left: tuple[int, ...], right: tuple[int, ...], expected: int) -> None:
        assert update_oee.compare_versions(left, right) == expected

    def test_extract_version_from_header_ignores_license_version(self) -> None:
        header = (
            "#!/bin/bash\n"
            "# Licensed under Universal Permissive License v 1.0\n"
            "# Copyright (c) 2024 Oracle\n"
            "# * OEE Group Extract Standalone v6.1.1\n"
        )
        assert update_oee.extract_version_from_header(header) == (6, 1, 1)

    def test_returns_link_when_remote_version_is_higher(self, tmp_path: Path) -> None:
        oee_dir = tmp_path / "oee"
        oee_dir.mkdir()
        (oee_dir / "oee_group_extract-SA.sh").write_text("# * OEE Group Extract Standalone v5.1\n", encoding="utf-8")
        (oee_dir / "oee_group_metrics-SA.sql").write_text("REM * OEE Group Extract StandAlone v5.1\n", encoding="utf-8")
        expected_url = "https://download.oracle.com/otn-pub/oss/ee/oracle-estate-explorer-v6.1.1.zip"
        sample_html = (
            "<html><body>"
            '<a href="https://download.oracle.com/otn-pub/oss/ee/oracle-estate-explorer-v5.0.zip">Old</a>'
            f'<a href="{expected_url}">Oracle Estate Explorer 6.1.1</a>'
            "</body></html>"
        )
        found = update_oee.check_oee_release(
            target_dir=oee_dir,
            fetch_html=lambda _url: sample_html,
        )
        assert found == expected_url

    @pytest.mark.parametrize("remote_ver", ["v5.1", "v5.1.0", "v5.0", "v4.9.9"])
    def test_returns_none_when_remote_version_not_higher(self, tmp_path: Path, remote_ver: str) -> None:
        oee_dir = tmp_path / "oee"
        oee_dir.mkdir()
        (oee_dir / "oee_group_extract-SA.sh").write_text("# * OEE Group Extract Standalone v5.1\n", encoding="utf-8")
        sample_html = (
            f'<a href="https://download.oracle.com/otn-pub/oss/ee/oracle-estate-explorer-{remote_ver}.zip">OEE</a>'
        )
        assert update_oee.check_oee_release(target_dir=oee_dir, fetch_html=lambda _url: sample_html) is None

    def test_extracts_link_from_data_attribute_or_inline_text(self) -> None:
        link = "https://download.oracle.com/otn-pub/oss/ee/oracle-estate-explorer-v7.0.2.zip"
        page = f'<button data-file="{link}">Download</button>'
        assert update_oee.extract_release_links(page) == [link]

    def test_resolves_protocol_relative_href_from_oracle_page(self, tmp_path: Path) -> None:
        oee_dir = tmp_path / "oee"
        oee_dir.mkdir()
        (oee_dir / "oee_group_extract-SA.sh").write_text("# * OEE Group Extract Standalone v5.1\n", encoding="utf-8")
        oracle_html = (
            '<a class="license-link icn-download" '
            'href="//download.oracle.com/otn-pub/oss/ee/oracle-estate-explorer-v6.1.1.zip">'
            "Oracle Estate Explorer 6.1.1</a>"
        )
        found = update_oee.check_oee_release(target_dir=oee_dir, fetch_html=lambda _url: oracle_html)
        assert found == "https://download.oracle.com/otn-pub/oss/ee/oracle-estate-explorer-v6.1.1.zip"

    def test_cli_prints_bare_link_or_null(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
    ) -> None:
        oee_dir = tmp_path / "oee"
        oee_dir.mkdir()
        (oee_dir / "oee_group_extract-SA.sh").write_text("# * OEE Group Extract Standalone v6.1.1\n", encoding="utf-8")

        link_611 = "https://download.oracle.com/otn-pub/oss/ee/oracle-estate-explorer-v6.1.1.zip"
        monkeypatch.setattr(
            update_oee,
            "fetch_release_page_html",
            lambda _url: f'<a href="{link_611}">OEE 6.1.1</a>',
        )
        rc_same = update_oee.main(["--check-release", "--target-dir", str(oee_dir)])
        assert rc_same == 0
        assert capsys.readouterr().out == "null\n"

        link_620 = "https://download.oracle.com/otn-pub/oss/ee/oracle-estate-explorer-v6.2.0.zip"
        monkeypatch.setattr(
            update_oee,
            "fetch_release_page_html",
            lambda _url: f'<a href="{link_620}">OEE 6.2.0</a>',
        )
        rc_newer = update_oee.main(["--check-release", "--target-dir", str(oee_dir)])
        assert rc_newer == 0
        assert capsys.readouterr().out == f"{link_620}\n"

    def test_raises_when_no_matching_link_found(self, tmp_path: Path) -> None:
        oee_dir = tmp_path / "oee"
        oee_dir.mkdir()
        (oee_dir / "oee_group_extract-SA.sh").write_text("# * OEE Group Extract Standalone v5.1\n", encoding="utf-8")
        with pytest.raises(update_oee.OeeUpdateError, match="No versioned OEE download link"):
            update_oee.check_oee_release(target_dir=oee_dir, fetch_html=lambda _url: "<html>no links</html>")

    def test_raises_when_local_headers_have_no_version(self, tmp_path: Path) -> None:
        oee_dir = tmp_path / "oee"
        oee_dir.mkdir()
        (oee_dir / "oee_group_extract-SA.sh").write_text("#!/bin/bash\necho hi\n", encoding="utf-8")
        with pytest.raises(update_oee.OeeUpdateError, match="No OEE version header"):
            update_oee.get_local_oee_version(oee_dir)


class TestMakefileIntegration:
    """Confirm the ``update-oee`` and ``check_oee_release`` targets in ``Makefile``."""

    @pytest.mark.skipif(shutil.which("make") is None, reason="make command not available")
    def test_makefile_declares_update_oee_and_check_release_targets(self) -> None:
        make_bin = shutil.which("make")
        assert make_bin is not None

        help_res = subprocess.run([make_bin, "help"], cwd=REPO_ROOT, capture_output=True, text=True, check=False)
        assert help_res.returncode == 0, help_res.stderr
        assert "update-oee" in help_res.stdout
        assert "check_oee_release" in help_res.stdout

        dry_res = subprocess.run(
            [make_bin, "-n", "update-oee"], cwd=REPO_ROOT, capture_output=True, text=True, check=False
        )
        assert dry_res.returncode == 0, dry_res.stderr
        assert "tools/update_oee.py" in dry_res.stdout

        flag_res = subprocess.run(
            [make_bin, "-n", "update-oee", "CHECK_ONLY=1", "FORCE=1"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        assert flag_res.returncode == 0, flag_res.stderr
        assert "--check" in flag_res.stdout
        assert "--force" in flag_res.stdout

        rel_res = subprocess.run(
            [make_bin, "-n", "check_oee_release"], cwd=REPO_ROOT, capture_output=True, text=True, check=False
        )
        assert rel_res.returncode == 0, rel_res.stderr
        assert "--check-release" in rel_res.stdout
