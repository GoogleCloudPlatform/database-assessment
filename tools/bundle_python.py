# /// script
# dependencies = [
#   "rich-click",
#   "rich",
#   "python-dotenv",
#   "pip",
# ]
# ///
"""Bundle Python dependencies into a standalone distribution for offline use.

This script downloads a python-build-standalone distribution, installs project
dependencies into its site-packages, and repackages everything into a tarball
suitable for embedding in a PyApp binary.
"""

import contextlib
import os
import shutil
import subprocess
import sys
import tarfile
import urllib.error
import urllib.request
import zipfile
from pathlib import Path

import rich_click as click
from rich.console import Console

# Mapping from Rust target to Python Build Standalone URL (Python 3.13.9)
# Source: build.rs in pyapp 0.29.0
# Release: https://github.com/astral-sh/python-build-standalone/releases/tag/20251014
URLS = {
    "x86_64-unknown-linux-gnu": "https://github.com/astral-sh/python-build-standalone/releases/download/20251014/cpython-3.13.9%2B20251014-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz",
    "aarch64-unknown-linux-gnu": "https://github.com/astral-sh/python-build-standalone/releases/download/20251014/cpython-3.13.9%2B20251014-aarch64-unknown-linux-gnu-install_only_stripped.tar.gz",
    "aarch64-apple-darwin": "https://github.com/astral-sh/python-build-standalone/releases/download/20251014/cpython-3.13.9%2B20251014-aarch64-apple-darwin-install_only_stripped.tar.gz",
    "x86_64-pc-windows-msvc": "https://github.com/astral-sh/python-build-standalone/releases/download/20251014/cpython-3.13.9%2B20251014-x86_64-pc-windows-msvc-install_only_stripped.tar.gz",
}

# Mapping from Rust target to uv pip --python-platform value
# These are uv-specific platform identifiers (NOT PEP 425 wheel tags)
# Note: manylinux_2_28 required because duckdb only provides wheels for glibc 2.28+
PLATFORMS = {
    "x86_64-unknown-linux-gnu": "x86_64-manylinux_2_28",
    "aarch64-unknown-linux-gnu": "aarch64-manylinux_2_28",
    "aarch64-apple-darwin": "aarch64-apple-darwin",
    "x86_64-pc-windows-msvc": "x86_64-pc-windows-msvc",
}

console = Console()


def validate_inputs(target: str, requirements_path: Path, output_path: Path) -> None:
    """Validate all inputs before starting the build."""
    # Check target is supported
    if target not in URLS:
        available = ", ".join(sorted(URLS.keys()))
        console.print(f"[bold red]Error:[/] Unknown target '{target}'")
        console.print(f"[dim]Available targets: {available}[/]")
        sys.exit(1)

    # Check requirements file exists
    if not requirements_path.exists():
        console.print(f"[bold red]Error:[/] Requirements file not found: {requirements_path}")
        console.print("[dim]Hint: Run 'uv export --no-dev --no-hashes > requirements.txt' first[/]")
        sys.exit(1)

    if not requirements_path.is_file():
        console.print(f"[bold red]Error:[/] Requirements path is not a file: {requirements_path}")
        sys.exit(1)

    # Check output directory is writable
    output_dir = output_path.parent
    if not output_dir.exists():
        try:
            output_dir.mkdir(parents=True)
        except PermissionError:
            console.print(f"[bold red]Error:[/] Cannot create output directory: {output_dir}")
            sys.exit(1)

    if not os.access(output_dir, os.W_OK):
        console.print(f"[bold red]Error:[/] Cannot write to output directory: {output_dir}")
        sys.exit(1)


def download_with_retry(url: str, dest: Path, max_retries: int = 3) -> None:
    """Download a file with retry logic."""
    for attempt in range(max_retries):
        try:
            console.print(f"[blue]Downloading[/] {url}...")
            urllib.request.urlretrieve(url, dest)
            # Verify download succeeded
            if dest.exists() and dest.stat().st_size > 0:
                console.print(f"[green]OK[/] Downloaded {dest.stat().st_size / (1024 * 1024):.1f} MB")
                return
            console.print("[yellow]Warning:[/] Downloaded file appears empty, retrying...")
        except urllib.error.URLError as e:
            if attempt < max_retries - 1:
                console.print(f"[yellow]Warning:[/] Download failed (attempt {attempt + 1}/{max_retries}): {e}")
                console.print("[dim]Retrying...[/]")
            else:
                console.print(f"[bold red]Error:[/] Failed to download after {max_retries} attempts")
                console.print(f"[dim]URL: {url}[/]")
                console.print(f"[dim]Error: {e}[/]")
                sys.exit(1)


def find_site_packages(python_root: Path, target: str) -> Path:
    """Locate site-packages directory within extracted Python distribution."""
    if "windows" in target:
        site_packages = python_root / "Lib" / "site-packages"
    else:
        site_packages = python_root / "lib" / "python3.13" / "site-packages"

    if site_packages.exists():
        return site_packages

    # Fallback: search for site-packages
    console.print("[yellow]Warning:[/] Expected site-packages location not found, searching...")
    for root, dirs, _ in os.walk(python_root):
        if "site-packages" in dirs:
            found = Path(root) / "site-packages"
            console.print(f"[green]Found[/] site-packages at: {found}")
            return found

    # Debug output
    console.print(f"[bold red]Error:[/] Could not locate site-packages in {python_root}")
    console.print("[dim]Directory structure:[/]")
    for root, _, _ in os.walk(python_root):
        depth = root.replace(str(python_root), "").count(os.sep)
        if depth < 4:  # Limit depth for readability
            console.print(f"  {root}")
    sys.exit(1)


@click.command()
@click.option("--target", required=True, help="Rust target architecture (e.g., x86_64-unknown-linux-gnu)")
@click.option("--requirements", required=True, help="Path to requirements.txt")
@click.option("--output", required=True, help="Output path for the bundled distribution (.tar.gz)")
@click.option("--work-dir", default="build_dist_temp", help="Working directory for temporary files")
@click.option("--keep-temp", is_flag=True, help="Keep temporary working directory after completion")
def main(target: str, requirements: str, output: str, work_dir: str, keep_temp: bool) -> None:
    """Bundle Python dependencies into a standalone distribution.

    This script creates a self-contained Python distribution with all dependencies
    pre-installed, suitable for embedding in a PyApp binary for offline use.
    """
    requirements_path = Path(requirements).resolve()
    output_path = Path(output).resolve()
    work_dir_path = Path(work_dir).resolve()

    # Validate inputs before doing any work
    validate_inputs(target, requirements_path, output_path)

    url = URLS[target]
    platform = PLATFORMS[target]

    console.print()
    console.print("[bold]Bundle Python Distribution[/]")
    console.print(f"  Target:       {target}")
    console.print(f"  Platform:     {platform}")
    console.print(f"  Requirements: {requirements_path}")
    console.print(f"  Output:       {output_path}")
    console.print()

    # Clean and create work directory
    if work_dir_path.exists():
        shutil.rmtree(work_dir_path)
    work_dir_path.mkdir(parents=True)

    try:
        # Download Python distribution
        archive_name = url.split("/")[-1]
        archive_path = work_dir_path / archive_name
        download_with_retry(url, archive_path)

        # Extract
        extract_dir = work_dir_path / "extracted"
        console.print(f"[blue]Extracting[/] to {extract_dir}...")
        if archive_name.endswith(".tar.gz"):
            with tarfile.open(archive_path, "r:gz") as tar:
                tar.extractall(extract_dir, filter="data")
        elif archive_name.endswith(".zip"):
            with zipfile.ZipFile(archive_path, "r") as zip_ref:
                zip_ref.extractall(extract_dir)
        else:
            console.print(f"[bold red]Error:[/] Unknown archive format: {archive_name}")
            sys.exit(1)

        # Determine python root
        python_root = extract_dir / "python"
        if not python_root.exists():
            contents = list(extract_dir.iterdir())
            if len(contents) == 1 and contents[0].is_dir():
                python_root = contents[0]
            else:
                console.print(f"[bold red]Error:[/] Unexpected archive structure in {extract_dir}")
                console.print(f"[dim]Contents: {[c.name for c in contents]}[/]")
                sys.exit(1)

        # Find site-packages
        site_packages = find_site_packages(python_root, target)
        console.print(f"[blue]Installing dependencies[/] to {site_packages}...")

        # Build pip command
        pip_cmd = [
            "uv",
            "pip",
            "install",
            "-r",
            str(requirements_path),
            "--target",
            str(site_packages),
            "--python-platform",
            str(platform),
            "--python-version",
            "3.13",
            "--only-binary=:all:",
            "--no-deps",
            "--upgrade",
        ]

        # Detect if we are on a Google-internal "Rodete" machine
        # and force the public PyPI index if so, as the internal mirror may miss packages.
        with contextlib.suppress(OSError):
            os_release = Path("/etc/os-release")
            if os_release.exists() and "rodete" in os_release.read_text(encoding="utf-8").lower():
                pip_cmd.extend(["--index-url", "https://pypi.org/simple"])

        console.print(f"[dim]Running: {' '.join(pip_cmd)}[/]")
        try:
            subprocess.check_call(pip_cmd)
        except subprocess.CalledProcessError as e:
            console.print(f"[bold red]Error:[/] pip install failed with exit code {e.returncode}")
            console.print("[dim]Hint: Check that all dependencies have wheels for the target platform[/]")
            sys.exit(1)

        # Repackage
        console.print(f"[blue]Repackaging[/] to {output_path}...")
        if archive_name.endswith(".tar.gz"):
            with tarfile.open(output_path, "w:gz") as tar:
                tar.add(python_root, arcname="python")
        elif archive_name.endswith(".zip"):
            with zipfile.ZipFile(output_path, "w", zipfile.ZIP_DEFLATED) as zipf:
                for root, _, files in os.walk(python_root):
                    for file in files:
                        file_path = Path(root) / file
                        arcname = file_path.relative_to(python_root.parent)
                        zipf.write(file_path, arcname)

        output_size = output_path.stat().st_size / (1024 * 1024)
        console.print()
        console.print(f"[bold green]Success![/] Created {output_path.name} ({output_size:.1f} MB)")

    finally:
        # Clean up work directory unless --keep-temp is specified
        if not keep_temp and work_dir_path.exists():
            shutil.rmtree(work_dir_path)


if __name__ == "__main__":
    main()
