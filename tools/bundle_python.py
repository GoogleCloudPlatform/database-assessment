import argparse
import os
import shutil
import subprocess
import sys
import tarfile
import urllib.request
import zipfile
from pathlib import Path

# Mapping from Rust target to Python Build Standalone URL (Python 3.13.9)
# Source: build.rs in pyapp 0.29.0
URLS = {
    "x86_64-unknown-linux-gnu": "https://github.com/astral-sh/python-build-standalone/releases/download/20251014/cpython-3.13.9%2B20251014-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz",
    "aarch64-unknown-linux-gnu": "https://github.com/astral-sh/python-build-standalone/releases/download/20251014/cpython-3.13.9%2B20251014-aarch64-unknown-linux-gnu-install_only_stripped.tar.gz",
    "x86_64-unknown-linux-musl": "https://github.com/astral-sh/python-build-standalone/releases/download/20251014/cpython-3.13.9%2B20251014-x86_64-unknown-linux-musl-install_only_stripped.tar.gz",
    "aarch64-apple-darwin": "https://github.com/astral-sh/python-build-standalone/releases/download/20251014/cpython-3.13.9%2B20251014-aarch64-apple-darwin-install_only_stripped.tar.gz",
    "x86_64-pc-windows-msvc": "https://github.com/astral-sh/python-build-standalone/releases/download/20251014/cpython-3.13.9%2B20251014-x86_64-pc-windows-msvc-install_only_stripped.tar.gz",
}

# Mapping from Rust target to pip platform tag
PLATFORMS = {
    "x86_64-unknown-linux-gnu": "manylinux_2_17_x86_64",
    "aarch64-unknown-linux-gnu": "manylinux_2_17_aarch64",
    "x86_64-unknown-linux-musl": "musllinux_1_1_x86_64",
    "aarch64-apple-darwin": "macosx_11_0_arm64",
    "x86_64-pc-windows-msvc": "win_amd64",
}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", required=True, help="Rust target architecture")
    parser.add_argument("--requirements", required=True, help="Path to requirements.txt")
    parser.add_argument("--output", required=True, help="Output path for the bundled distribution")
    args = parser.parse_args()

    target = args.target
    requirements = Path(args.requirements).resolve()
    output = Path(args.output).resolve()

    if target not in URLS:
        print(f"Error: Target {target} not supported.")
        sys.exit(1)

    url = URLS[target]
    platform = PLATFORMS.get(target)

    print(f"Processing target: {target}")
    print(f"URL: {url}")
    print(f"Platform: {platform}")

    work_dir = Path("build_dist_temp").resolve()
    if work_dir.exists():
        shutil.rmtree(work_dir)
    work_dir.mkdir()

    # Download
    archive_name = url.split("/")[-1]
    archive_path = work_dir / archive_name
    print(f"Downloading {url}...")
    urllib.request.urlretrieve(url, archive_path)

    # Extract
    extract_dir = work_dir / "extracted"
    print(f"Extracting to {extract_dir}...")
    if archive_name.endswith(".tar.gz"):
        with tarfile.open(archive_path, "r:gz") as tar:
            tar.extractall(extract_dir)
    elif archive_name.endswith(".zip"):
        with zipfile.ZipFile(archive_path, "r") as zip_ref:
            zip_ref.extractall(extract_dir)
    else:
        print("Unknown archive format")
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
        print(f"Error: Could not locate site-packages at {site_packages}")
        # Debug list
        for root, _, _ in os.walk(extract_dir):
            print(root)
        sys.exit(1)

    print(f"Installing dependencies to {site_packages}...")

    # We use the current python environment to run pip
    # We must use --ignore-installed to ensure we install everything into the target
    # We use --no-deps because requirements.txt from uv export should be fully resolved?
    # No, uv export includes dependencies. But pip install -t might resolve again if we don't say --no-deps.
    # However, if we use --no-deps, we rely 100% on requirements.txt being complete.
    # Given we use 'uv export', it IS complete.

    pip_cmd = [
        sys.executable,
        "-m",
        "pip",
        "install",
        "-r",
        str(requirements),
        "--target",
        str(site_packages),
        "--platform",
        platform,
        "--only-binary=:all:",
        "--no-deps",
        "--upgrade",
    ]

    # If the target is same as host, we don't strictly need --platform, but good for consistency.
    # However, `dma` itself is in requirements.txt as a file path.
    # pip install with --platform and local file path might complain if the wheel isn't tagged correctly for that platform?
    # Our wheel is `py3-none-any.whl`, so it should be fine.

    print(f"Running: {' '.join(pip_cmd)}")
    subprocess.check_call(pip_cmd)

    # Re-package
    print(f"Repackaging to {output}...")
    # Use the same format as input
    if archive_name.endswith(".tar.gz"):
        with tarfile.open(output, "w:gz") as tar:
            tar.add(python_root, arcname="python")
    elif archive_name.endswith(".zip"):
        with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as zipf:
            for root, _, files in os.walk(python_root):
                for file in files:
                    file_path = Path(root) / file
                    arcname = file_path.relative_to(python_root.parent)
                    zipf.write(file_path, arcname)

    print("Done.")


if __name__ == "__main__":
    main()
