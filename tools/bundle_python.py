#!/usr/bin/env python3
# /// script
# dependencies = [
#   "rich-click",
#   "rich",
#   "tomli; python_version < '3.11'",
# ]
# ///
"""Bundle Python dependencies into a standalone distribution for PyApp."""

import contextlib
import os
import platform as host_platform
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.error
import urllib.request
import zipfile
from pathlib import Path
from typing import Any

import rich_click as click
from rich.console import Console
from rich.rule import Rule

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover - Python 3.12+ ships tomllib
    import tomli as tomllib  # type: ignore[no-redef]


DEFAULT_PYTHON_VERSION = "3.13"
DEFAULT_INSTALL_ROOT = "~/.local"
DEFAULT_CACHE_DIRNAME = ".cache/bundler"

# Mapping from Rust target to Python Build Standalone URL (Python 3.13.9)
# Source: build.rs in pyapp 0.29.0
# Release: https://github.com/astral-sh/python-build-standalone/releases/tag/20251014
DEFAULT_URLS: dict[str, str] = {
    "x86_64-unknown-linux-gnu": "https://github.com/astral-sh/python-build-standalone/releases/download/20251014/cpython-3.13.9%2B20251014-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz",
    "aarch64-unknown-linux-gnu": "https://github.com/astral-sh/python-build-standalone/releases/download/20251014/cpython-3.13.9%2B20251014-aarch64-unknown-linux-gnu-install_only_stripped.tar.gz",
    "x86_64-apple-darwin": "https://github.com/astral-sh/python-build-standalone/releases/download/20251014/cpython-3.13.9%2B20251014-x86_64-apple-darwin-install_only_stripped.tar.gz",
    "aarch64-apple-darwin": "https://github.com/astral-sh/python-build-standalone/releases/download/20251014/cpython-3.13.9%2B20251014-aarch64-apple-darwin-install_only_stripped.tar.gz",
    "x86_64-pc-windows-msvc": "https://github.com/astral-sh/python-build-standalone/releases/download/20251014/cpython-3.13.9%2B20251014-x86_64-pc-windows-msvc-install_only_stripped.tar.gz",
}

# Mapping from Rust target to uv pip --python-platform value
# These are uv-specific platform identifiers (NOT PEP 425 wheel tags)
# Note: manylinux_2_28 required because duckdb only provides wheels for glibc 2.28+
DEFAULT_PLATFORMS: dict[str, str] = {
    "x86_64-unknown-linux-gnu": "x86_64-manylinux_2_28",
    "aarch64-unknown-linux-gnu": "aarch64-manylinux_2_28",
    "x86_64-apple-darwin": "x86_64-apple-darwin",
    "aarch64-apple-darwin": "aarch64-apple-darwin",
    "x86_64-pc-windows-msvc": "x86_64-pc-windows-msvc",
}

console = Console()


def configure_rich_click() -> None:
    """Configure rich-click styles to match DMA CLI conventions."""

    click.rich_click.USE_RICH_MARKUP = True
    click.rich_click.USE_MARKDOWN = True

    click.rich_click.STYLE_COMMAND = "bold #4285F4"
    click.rich_click.STYLE_OPTION = "bold #34A853"
    click.rich_click.STYLE_SWITCH = "bold #34A853"
    click.rich_click.STYLE_ARGUMENT = "bold cyan"
    click.rich_click.STYLE_METAVAR = "#FBBC04"

    click.rich_click.STYLE_USAGE = "bold"
    click.rich_click.STYLE_USAGE_COMMAND = "bold #4285F4"
    click.rich_click.STYLE_HELPTEXT = "dim"
    click.rich_click.STYLE_HELPTEXT_FIRST_LINE = ""
    click.rich_click.STYLE_OPTION_HELP = ""

    click.rich_click.STYLE_ERRORS_SUGGESTION = "italic #FBBC04"
    click.rich_click.STYLE_REQUIRED_SHORT = "#EA4335"
    click.rich_click.STYLE_REQUIRED_LONG = "dim #EA4335"
    click.rich_click.STYLE_ERRORS_PANEL_BORDER = "#EA4335"
    click.rich_click.STYLE_ABORTED = "#EA4335"

    click.rich_click.STYLE_OPTIONS_PANEL_BORDER = "dim #4285F4"
    click.rich_click.STYLE_COMMANDS_PANEL_BORDER = "dim #4285F4"
    click.rich_click.WIDTH = 120
    click.rich_click.MAX_WIDTH = 120
    click.rich_click.SHOW_ARGUMENTS = True
    click.rich_click.GROUP_ARGUMENTS_OPTIONS = True
    click.rich_click.SHOW_METAVARS_COLUMN = True
    click.rich_click.APPEND_METAVARS_HELP = False
    click.rich_click.COMMAND_GROUPS = {
        "bundler": [{"name": "Build", "commands": ["build"]}, {"name": "Manage", "commands": ["manage", "targets"]}]
    }


def left_aligned_rule(title: str, style: str = "blue") -> None:
    """Create a left-aligned rule with title instead of centered."""

    rule = Rule(title, style=style, align="left")
    console.print(rule)


def resolve_project_dir(project_dir: str | None) -> Path:
    """Resolve the project directory, defaulting to the current working directory."""

    base = Path(project_dir or Path.cwd()).expanduser().resolve()
    if not base.exists():
        msg = f"Project directory not found: {base}"
        raise click.ClickException(msg)
    if not base.is_dir():
        msg = f"Project path is not a directory: {base}"
        raise click.ClickException(msg)
    return base


def load_pyproject(project_dir: Path) -> dict[str, Any]:
    """Load pyproject.toml if present."""

    pyproject_path = project_dir / "pyproject.toml"
    if not pyproject_path.exists():
        return {}
    try:
        return tomllib.loads(pyproject_path.read_text(encoding="utf-8"))
    except (OSError, tomllib.TOMLDecodeError) as exc:
        msg = f"Failed to parse {pyproject_path}: {exc}"
        raise click.ClickException(msg) from exc


def detect_project_name(project_dir: Path, override: str | None) -> str:
    """Detect project name from pyproject.toml or fallback to directory name."""

    if override:
        return override

    pyproject = load_pyproject(project_dir)
    project_name = (
        pyproject.get("project", {}).get("name")
        or pyproject.get("tool", {}).get("poetry", {}).get("name")
        or pyproject.get("tool", {}).get("hatch", {}).get("metadata", {}).get("name")
    )
    if isinstance(project_name, str) and project_name.strip():
        return project_name.strip()
    return project_dir.name


def normalize_install_root(install_root: str | None) -> Path:
    """Normalize the install root path to an absolute location."""

    root = install_root or DEFAULT_INSTALL_ROOT
    return Path(root).expanduser().resolve()


def resolve_install_dir(install_root: Path, project_name: str) -> Path:
    """Resolve the per-project install directory."""

    return (install_root / project_name).resolve()


def ensure_directory(path: Path) -> None:
    """Ensure a directory exists."""

    try:
        path.mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        msg = f"Failed to create directory {path}: {exc}"
        raise click.ClickException(msg) from exc


def guess_target() -> str | None:
    """Guess the Rust target based on the host platform."""

    machine = host_platform.machine().lower()
    system = sys.platform

    if system.startswith("linux"):
        if machine in {"x86_64", "amd64"}:
            return "x86_64-unknown-linux-gnu"
        if machine in {"aarch64", "arm64"}:
            return "aarch64-unknown-linux-gnu"
    if system == "darwin":
        if machine in {"x86_64", "amd64"}:
            return "x86_64-apple-darwin"
        if machine in {"aarch64", "arm64"}:
            return "aarch64-apple-darwin"
    if system.startswith("win"):
        return "x86_64-pc-windows-msvc"
    return None


def infer_python_version(url: str) -> str:
    """Infer python major.minor version from a python-build-standalone URL."""

    match = re.search(r"cpython-(\d+)\.(\d+)\.\d+", url)
    if match:
        return f"{match.group(1)}.{match.group(2)}"
    return DEFAULT_PYTHON_VERSION


def resolve_output_path(output: str | None, output_name: str | None, project_dir: Path, target: str) -> Path:
    """Resolve output path for the bundled distribution."""

    if output:
        return Path(output).expanduser().resolve()
    dist_dir = project_dir / "dist"
    ensure_directory(dist_dir)
    filename = output_name or f"python-dist-{target}.tar.gz"
    return (dist_dir / filename).resolve()


def resolve_cache_dir(cache_dir: str | None, project_dir: Path) -> Path:
    """Resolve the cache directory for downloads."""

    if cache_dir:
        return Path(cache_dir).expanduser().resolve()
    return (project_dir / DEFAULT_CACHE_DIRNAME).resolve()


def validate_requirements(requirements_path: Path) -> None:
    """Validate the requirements file."""

    if not requirements_path.exists():
        msg = f"Requirements file not found: {requirements_path}"
        raise click.ClickException(msg)
    if not requirements_path.is_file():
        msg = f"Requirements path is not a file: {requirements_path}"
        raise click.ClickException(msg)


def download_with_retry(url: str, dest: Path, max_retries: int = 3) -> None:
    """Download a file with retry logic."""

    for attempt in range(max_retries):
        try:
            console.print(f"[blue]Downloading[/] {url}...")
            urllib.request.urlretrieve(url, dest)
            if dest.exists() and dest.stat().st_size > 0:
                size_mb = dest.stat().st_size / (1024 * 1024)
                console.print(f"[green]OK[/] Downloaded {size_mb:.1f} MB")
                return
            console.print("[yellow]Warning:[/] Downloaded file appears empty, retrying...")
        except urllib.error.URLError as exc:
            if attempt < max_retries - 1:
                console.print(f"[yellow]Warning:[/] Download failed (attempt {attempt + 1}/{max_retries}): {exc}")
                console.print("[dim]Retrying...[/]")
            else:
                msg = f"Failed to download after {max_retries} attempts: {exc}"
                raise click.ClickException(msg) from exc


def find_site_packages(python_root: Path, target: str, python_version: str) -> Path:
    """Locate site-packages directory within extracted Python distribution."""

    if "windows" in target:
        site_packages = python_root / "Lib" / "site-packages"
    else:
        major_minor = ".".join(python_version.split(".")[:2])
        site_packages = python_root / "lib" / f"python{major_minor}" / "site-packages"

    if site_packages.exists():
        return site_packages

    console.print("[yellow]Warning:[/] Expected site-packages location not found, searching...")
    for root, dirs, _ in os.walk(python_root):
        if "site-packages" in dirs:
            found = Path(root) / "site-packages"
            console.print(f"[green]Found[/] site-packages at: {found}")
            return found

    console.print(f"[bold red]Error:[/] Could not locate site-packages in {python_root}")
    console.print("[dim]Directory structure:[/]")
    for root, _, _ in os.walk(python_root):
        depth = root.replace(str(python_root), "").count(os.sep)
        if depth < 4:
            console.print(f"  {root}")
    msg = "Unable to locate site-packages in extracted Python distribution"
    raise click.ClickException(msg)


def ensure_uv_available() -> None:
    """Ensure uv is available on PATH."""

    if shutil.which("uv"):
        return
    msg = "uv is required but not found on PATH"
    raise click.ClickException(msg)


def install_requirements(
    requirements_path: Path,
    site_packages: Path,
    platform: str,
    python_version: str,
    index_url: str | None,
    extra_index_urls: tuple[str, ...],
    allow_source: bool,
    include_deps: bool,
) -> None:
    """Install requirements into site-packages using uv pip."""

    pip_cmd = [
        "uv",
        "pip",
        "install",
        "-r",
        str(requirements_path),
        "--target",
        str(site_packages),
        "--python-platform",
        platform,
        "--python-version",
        python_version,
        "--upgrade",
    ]

    if not include_deps:
        pip_cmd.append("--no-deps")
    if not allow_source:
        pip_cmd.append("--only-binary=:all:")

    if index_url:
        pip_cmd.extend(["--index-url", index_url])
    for extra_url in extra_index_urls:
        pip_cmd.extend(["--extra-index-url", extra_url])

    with contextlib.suppress(OSError):
        os_release = Path("/etc/os-release")
        if (
            os_release.exists()
            and "rodete" in os_release.read_text(encoding="utf-8").lower()
            and "--index-url" not in pip_cmd
        ):
            pip_cmd.extend(["--index-url", "https://pypi.org/simple"])

    console.print(f"[dim]Running: {' '.join(pip_cmd)}[/]")
    try:
        subprocess.check_call(pip_cmd)
    except subprocess.CalledProcessError as exc:
        msg = f"pip install failed with exit code {exc.returncode}"
        raise click.ClickException(msg) from exc


def extract_archive(archive_path: Path, extract_dir: Path) -> None:
    """Extract a python-build-standalone archive."""

    name = archive_path.name
    console.print(f"[blue]Extracting[/] to {extract_dir}...")
    if name.endswith(".tar.gz"):
        with tarfile.open(archive_path, "r:gz") as tar:
            tar.extractall(extract_dir, filter="data")
        return
    if name.endswith(".zip"):
        with zipfile.ZipFile(archive_path, "r") as zip_ref:
            zip_ref.extractall(extract_dir)
        return
    msg = f"Unknown archive format: {name}"
    raise click.ClickException(msg)


def resolve_python_root(extract_dir: Path) -> Path:
    """Resolve the python root directory after extraction."""

    python_root = extract_dir / "python"
    if python_root.exists():
        return python_root

    contents = [entry for entry in extract_dir.iterdir() if entry.is_dir()]
    if len(contents) == 1:
        return contents[0]
    msg = f"Unexpected archive structure in {extract_dir} (found {len(contents)} directories)"
    raise click.ClickException(msg)


def rust_string_literal(value: str) -> str:
    """Return a safe Rust string literal for a given value."""

    if '"' not in value and "\\" not in value:
        return f'"{value}"'

    for hashes in range(1, 5):
        fence = "#" * hashes
        if f'{fence}"' not in value:
            return f'r{fence}"{value}"{fence}'

    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def render_install_dir_expression(install_dir: Path) -> str:
    """Render a Rust expression for the install directory."""

    install_dir = install_dir.expanduser().resolve()
    home_dir = Path.home().resolve()
    with contextlib.suppress(ValueError):
        relative = install_dir.relative_to(home_dir)
        expression = 'dirs::home_dir().expect("could not find home directory")'
        for part in relative.parts:
            expression += f".join({rust_string_literal(part)})"
        return expression
    return f"std::path::PathBuf::from({rust_string_literal(str(install_dir))})"


def patch_pyapp_install_dir(pyapp_dir: Path, install_dir: Path) -> None:
    """Patch PyApp to use a custom default installation directory."""

    app_rs = pyapp_dir / "src" / "app.rs"
    if not app_rs.exists():
        msg = f"PyApp source not found at {app_rs}"
        raise click.ClickException(msg)

    content = app_rs.read_text(encoding="utf-8")
    pattern = re.compile(
        r"platform_dirs\\(\\)\\s*\\.data_local_dir\\(\\)\\s*"
        r"\\.join\\(project_name\\(\\)\\)\\s*"
        r"\\.join\\(distribution_id\\(\\)\\)\\s*"
        r"\\.join\\(project_version\\(\\)\\)"
    )
    if not pattern.search(content):
        msg = "Failed to locate the PyApp installation directory block in src/app.rs"
        raise click.ClickException(msg)

    replacement = render_install_dir_expression(install_dir)
    updated = pattern.sub(replacement, content, count=1)
    app_rs.write_text(updated, encoding="utf-8")
    console.print(f"[green]Patched[/] PyApp install dir -> {install_dir}")


def summarize_paths(
    project_dir: Path,
    install_root: Path,
    install_dir: Path,
    cache_dir: Path,
    output_path: Path,
    requirements_path: Path | None,
) -> None:
    """Print a summary of key paths."""

    left_aligned_rule("Paths", style="#4285F4")
    console.print(f"  Project dir:  {project_dir}")
    console.print(f"  Install root: {install_root}")
    console.print(f"  Install dir:  {install_dir}")
    console.print(f"  Cache dir:    {cache_dir}")
    console.print(f"  Output:       {output_path}")
    if requirements_path:
        console.print(f"  Requirements: {requirements_path}")
    console.print()


@click.group(
    name="bundler",
    help="Bundle Python dependencies for PyApp embedding.",
    context_settings={"help_option_names": ["-h", "--help"]},
    invoke_without_command=True,
)
@click.pass_context
def cli(ctx: click.Context) -> None:
    """Root command for the bundler tool."""

    if ctx.invoked_subcommand is None:
        click.echo(ctx.get_help())


@cli.command("targets", help="List supported Rust targets and uv platforms.")
def list_targets() -> None:
    """Print available target mappings."""

    left_aligned_rule("Targets", style="#4285F4")
    for target in sorted(DEFAULT_URLS):
        platform = DEFAULT_PLATFORMS.get(target, "unknown")
        console.print(f"  {target} -> {platform}")
    console.print()


@cli.group("manage", help="Manage bundler caches and paths.")
def manage() -> None:
    """Management commands for the bundler."""


@manage.command("paths", help="Show resolved paths for a project.")
@click.option("--project-dir", type=click.Path(path_type=Path), help="Project directory")
@click.option("--project-name", help="Override project name")
@click.option("--install-root", help="Install root (default: ~/.local)")
@click.option("--cache-dir", help="Override cache directory")
@click.option("--target", help="Rust target (affects default output filename)")
@click.option("--output", help="Override output path")
@click.option("--output-name", help="Override output filename (stored under dist/)")
def manage_paths(
    project_dir: Path | None,
    project_name: str | None,
    install_root: str | None,
    cache_dir: str | None,
    target: str | None,
    output: str | None,
    output_name: str | None,
) -> None:
    """Show resolved bundler paths."""

    resolved_project = resolve_project_dir(str(project_dir) if project_dir else None)
    resolved_name = detect_project_name(resolved_project, project_name)
    resolved_install = normalize_install_root(install_root)
    resolved_install_dir = resolve_install_dir(resolved_install, resolved_name)
    resolved_cache = resolve_cache_dir(cache_dir, resolved_project)
    resolved_target = target or guess_target() or "unknown-target"
    resolved_output = resolve_output_path(output, output_name, resolved_project, resolved_target)

    summarize_paths(resolved_project, resolved_install, resolved_install_dir, resolved_cache, resolved_output, None)


@manage.command("cache", help="List or clear cached downloads.")
@click.option("--project-dir", type=click.Path(path_type=Path), help="Project directory")
@click.option("--cache-dir", help="Override cache directory")
@click.option("--target", help="Filter cache entries for a specific target")
@click.option("--clear", is_flag=True, help="Delete cached entries")
def manage_cache(project_dir: Path | None, cache_dir: str | None, target: str | None, clear: bool) -> None:
    """Manage cached python build downloads."""

    resolved_project = resolve_project_dir(str(project_dir) if project_dir else None)
    resolved_cache = resolve_cache_dir(cache_dir, resolved_project)
    cache_root = resolved_cache / "python-build-standalone"

    if not cache_root.exists():
        console.print(f"No cache found at {cache_root}")
        return

    if clear:
        if target:
            target_dir = cache_root / target
            if target_dir.exists():
                shutil.rmtree(target_dir)
                console.print(f"Cleared cache for {target}")
                return
            console.print(f"No cache found for target {target}")
            return
        shutil.rmtree(cache_root)
        console.print("Cleared all cached python build archives")
        return

    left_aligned_rule("Cache", style="#4285F4")
    for entry in sorted(cache_root.rglob("*")):
        if entry.is_file():
            size_mb = entry.stat().st_size / (1024 * 1024)
            console.print(f"  {entry.relative_to(cache_root)} ({size_mb:.1f} MB)")
    console.print()


@cli.command("build", help="Bundle dependencies into a PyApp-ready distribution.")
@click.option("--target", help="Rust target architecture")
@click.option("--requirements", type=click.Path(path_type=Path), help="Path to requirements.txt")
@click.option("--output", help="Output path for the bundled distribution (.tar.gz)")
@click.option("--project-dir", type=click.Path(path_type=Path), help="Project directory")
@click.option("--project-name", help="Override project name used in bundle paths")
@click.option("--install-root", help="Install root (default: ~/.local)")
@click.option("--cache-dir", help="Override cache directory")
@click.option("--python-url", help="Override python-build-standalone URL")
@click.option(
    "--python-archive",
    type=click.Path(path_type=Path),
    help="Use a local python-build-standalone archive instead of downloading",
)
@click.option("--python-version", help="Python version for uv wheel selection")
@click.option("--platform", help="Override uv --python-platform value")
@click.option("--index-url", help="Custom Python package index URL")
@click.option("--extra-index-url", multiple=True, help="Additional package index URLs")
@click.option("--allow-source", is_flag=True, help="Allow source builds when wheels are missing")
@click.option("--include-deps", is_flag=True, help="Allow uv to resolve dependencies (omit --no-deps)")
@click.option("--work-dir", type=click.Path(path_type=Path), help="Working directory for temporary files")
@click.option("--keep-temp", is_flag=True, help="Keep temporary working directory after completion")
@click.option("--refresh", is_flag=True, help="Force re-download of python build archives")
@click.option("--output-name", help="Override output filename (stored under dist/)")
@click.option("--pyapp-dir", type=click.Path(path_type=Path), help="Path to a PyApp checkout to patch install dir")
def build_bundle(
    target: str | None,
    requirements: Path | None,
    output: str | None,
    project_dir: Path | None,
    project_name: str | None,
    install_root: str | None,
    cache_dir: str | None,
    python_url: str | None,
    python_archive: Path | None,
    python_version: str | None,
    platform: str | None,
    index_url: str | None,
    extra_index_url: tuple[str, ...],
    allow_source: bool,
    include_deps: bool,
    work_dir: Path | None,
    keep_temp: bool,
    refresh: bool,
    output_name: str | None,
    pyapp_dir: Path | None,
) -> None:
    """Bundle a python distribution with dependencies for PyApp."""

    ensure_uv_available()

    resolved_project = resolve_project_dir(str(project_dir) if project_dir else None)
    resolved_name = detect_project_name(resolved_project, project_name)
    resolved_install = normalize_install_root(install_root)
    resolved_install_dir = resolve_install_dir(resolved_install, resolved_name)
    resolved_cache = resolve_cache_dir(cache_dir, resolved_project)

    resolved_target = target or os.environ.get("CARGO_BUILD_TARGET") or guess_target()
    if not resolved_target:
        msg = "Rust target not provided. Pass --target or set CARGO_BUILD_TARGET."
        raise click.ClickException(msg)

    requirements_path = requirements if requirements is not None else resolved_project / "requirements.txt"
    validate_requirements(requirements_path)

    url = python_url or DEFAULT_URLS.get(resolved_target)
    if python_archive is None and not url:
        available = ", ".join(sorted(DEFAULT_URLS.keys()))
        msg = f"Unknown target '{resolved_target}'. Available targets: {available}"
        raise click.ClickException(msg)

    resolved_platform = platform or DEFAULT_PLATFORMS.get(resolved_target)
    if not resolved_platform:
        msg = f"No platform mapping for target '{resolved_target}'. Use --platform to override."
        raise click.ClickException(msg)

    resolved_python_version = python_version or (infer_python_version(url) if url else DEFAULT_PYTHON_VERSION)
    resolved_output = resolve_output_path(output, output_name, resolved_project, resolved_target)

    summarize_paths(
        resolved_project, resolved_install, resolved_install_dir, resolved_cache, resolved_output, requirements_path
    )

    left_aligned_rule("Bundle", style="#4285F4")
    console.print(f"  Target:       {resolved_target}")
    console.print(f"  Platform:     {resolved_platform}")
    console.print(f"  Python:       {resolved_python_version}")
    if url:
        console.print(f"  Source URL:   {url}")
    if python_archive:
        console.print(f"  Source file:  {python_archive}")
    console.print()

    if pyapp_dir:
        patch_pyapp_install_dir(pyapp_dir.expanduser().resolve(), resolved_install_dir)
    else:
        console.print("[dim]Note:[/] pass --pyapp-dir to patch PyApp for the install directory.")

    work_dir_path: Path
    if work_dir:
        work_dir_path = work_dir.expanduser().resolve()
        if work_dir_path.exists():
            shutil.rmtree(work_dir_path)
        ensure_directory(work_dir_path)
    else:
        work_dir_path = Path(tempfile.mkdtemp(prefix="bundler-"))

    try:
        archive_path: Path
        if python_archive:
            archive_path = python_archive.expanduser().resolve()
        else:
            cache_root = resolved_cache / "python-build-standalone" / resolved_target
            ensure_directory(cache_root)
            archive_name = Path(url).name
            archive_path = cache_root / archive_name
            if refresh and archive_path.exists():
                archive_path.unlink()
            if not archive_path.exists():
                download_with_retry(url, archive_path)

        extract_dir = work_dir_path / "extracted"
        extract_dir.mkdir(parents=True, exist_ok=True)
        extract_archive(archive_path, extract_dir)

        python_root = resolve_python_root(extract_dir)
        site_packages = find_site_packages(python_root, resolved_target, resolved_python_version)
        console.print(f"[blue]Installing dependencies[/] to {site_packages}...")

        install_requirements(
            requirements_path=requirements_path,
            site_packages=site_packages,
            platform=resolved_platform,
            python_version=resolved_python_version,
            index_url=index_url,
            extra_index_urls=extra_index_url,
            allow_source=allow_source,
            include_deps=include_deps,
        )

        console.print(f"[blue]Repackaging[/] to {resolved_output}...")
        ensure_directory(resolved_output.parent)
        if archive_path.name.endswith(".tar.gz"):
            with tarfile.open(resolved_output, "w:gz") as tar:
                tar.add(python_root, arcname="python")
        elif archive_path.name.endswith(".zip"):
            with zipfile.ZipFile(resolved_output, "w", zipfile.ZIP_DEFLATED) as zipf:
                for root, _, files in os.walk(python_root):
                    for file in files:
                        file_path = Path(root) / file
                        arcname = file_path.relative_to(python_root.parent)
                        zipf.write(file_path, arcname)
        else:
            msg = f"Unknown archive format: {archive_path.name}"
            raise click.ClickException(msg)

        output_size = resolved_output.stat().st_size / (1024 * 1024)
        console.print()
        console.print(f"[bold green]Success![/] Created {resolved_output} ({output_size:.1f} MB)")
    finally:
        if not keep_temp and work_dir_path.exists():
            shutil.rmtree(work_dir_path)


def main() -> None:
    """Entry point for the bundler CLI."""

    configure_rich_click()
    cli()


if __name__ == "__main__":
    main()
