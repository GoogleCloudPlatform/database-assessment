# /// script
# dependencies = [
#   "rich-click",
#   "rich",
#   "python-dotenv",
#   "pip",
# ]
# ///
import contextlib
import os
import shutil
import subprocess
import sys
import tarfile
import urllib.request
import zipfile
from pathlib import Path

import rich_click as click
from rich.console import Console

# Mapping from Rust target to Python Build Standalone URL (Python 3.13.9)
# Source: build.rs in pyapp 0.29.0
URLS = {
    "x86_64-unknown-linux-gnu": "https://github.com/astral-sh/python-build-standalone/releases/download/20251014/cpython-3.13.9%2B20251014-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz",
    "aarch64-unknown-linux-gnu": "https://github.com/astral-sh/python-build-standalone/releases/download/20251014/cpython-3.13.9%2B20251014-aarch64-unknown-linux-gnu-install_only_stripped.tar.gz",
    "aarch64-apple-darwin": "https://github.com/astral-sh/python-build-standalone/releases/download/20251014/cpython-3.13.9%2B20251014-aarch64-apple-darwin-install_only_stripped.tar.gz",
    "x86_64-pc-windows-msvc": "https://github.com/astral-sh/python-build-standalone/releases/download/20251014/cpython-3.13.9%2B20251014-x86_64-pc-windows-msvc-install_only_stripped.tar.gz",
}

# Mapping from Rust target to pip platform tag
PLATFORMS = {
    "x86_64-unknown-linux-gnu": "x86_64-manylinux_2_28",
    "aarch64-unknown-linux-gnu": "aarch64-manylinux_2_28",
    "aarch64-apple-darwin": "aarch64-apple-darwin",
    "x86_64-pc-windows-msvc": "x86_64-pc-windows-msvc",
}

console = Console()


@click.command()
@click.option("--target", required=True, help="Rust target architecture")
@click.option("--requirements", required=True, help="Path to requirements.txt")
@click.option("--output", required=True, help="Output path for the bundled distribution")
def main(target: str, requirements: str, output: str) -> None:
    """Bundle Python dependencies into a standalone distribution."""
    requirements_path = Path(requirements).resolve()
    output_path = Path(output).resolve()

    if target not in URLS:
        console.print(f"[bold red]Error:[/bold red] Target {target} not supported.")
        sys.exit(1)

    url = URLS[target]
    platform = PLATFORMS.get(target)

    console.print(f"[bold blue]Processing target:[/bold blue] {target}")
    console.print(f"[bold blue]URL:[/bold blue] {url}")
    console.print(f"[bold blue]Platform:[/bold blue] {platform}")

    work_dir = Path("build_dist_temp").resolve()
    if work_dir.exists():
        shutil.rmtree(work_dir)
    work_dir.mkdir()

    # Download
    archive_name = url.split("/")[-1]
    archive_path = work_dir / archive_name
    console.print(f"Downloading {url}...")
    urllib.request.urlretrieve(url, archive_path)

    # Extract
    extract_dir = work_dir / "extracted"
    console.print(f"Extracting to {extract_dir}...")
    if archive_name.endswith(".tar.gz"):
        with tarfile.open(archive_path, "r:gz") as tar:
            tar.extractall(extract_dir)
    elif archive_name.endswith(".zip"):
        with zipfile.ZipFile(archive_path, "r") as zip_ref:
            zip_ref.extractall(extract_dir)
    else:
        console.print("[bold red]Unknown archive format[/bold red]")
        sys.exit(1)

    # Determine site-packages
    python_root = extract_dir / "python"
    if not python_root.exists():
        # Sometimes it extracts to ./python directly or <archive_name>/python
        # Check what we have
        contents = list(extract_dir.iterdir())
        if len(contents) == 1 and contents[0].is_dir():
            # Handle nested root if any (though PBS usually extracts 'python')
            python_root = contents[0]

    if "windows" in target:
        site_packages = python_root / "Lib" / "site-packages"
    else:
        # Assuming python 3.13
        site_packages = python_root / "lib" / "python3.13" / "site-packages"

    if not site_packages.exists():
        console.print(f"[bold red]Error:[/bold red] Could not locate site-packages at {site_packages}")
        # Debug list
        for root, _, _ in os.walk(extract_dir):
            console.print(root)
        sys.exit(1)

    console.print(f"Installing dependencies to {site_packages}...")

    # We use the current python environment to run pip
    # We must use --ignore-installed to ensure we install everything into the target
    # We use --no-deps because requirements.txt from uv export should be fully resolved?
    # No, uv export includes dependencies. But pip install -t might resolve again if we don't say --no-deps.
    # However, if we use --no-deps, we rely 100% on requirements.txt being complete.
    # Given we use 'uv export', it IS complete.

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

    console.print(f"Running: {' '.join(pip_cmd)}")
    try:
        subprocess.check_call(pip_cmd)
    except subprocess.CalledProcessError as e:
        console.print(f"[bold red]Error running pip:[/bold red] {e}")
        sys.exit(1)

    # Re-package
    console.print(f"Repackaging to {output_path}...")
    # Use the same format as input
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

    console.print("[bold green]Done.[/bold green]")


if __name__ == "__main__":
    main()
