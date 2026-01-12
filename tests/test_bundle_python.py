# Copyright 2024 Google LLC

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     https://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Tests for tools/bundle_python.py validation and helper functions."""

import sys
import urllib.error
from pathlib import Path
from unittest.mock import patch

import pytest

# Import the module under test
sys.path.insert(0, str(Path(__file__).parent.parent / "tools"))
import bundle_python


def test_validate_inputs_with_valid_target(tmp_path):
    """Test validation passes with valid target."""
    requirements_file = tmp_path / "requirements.txt"
    requirements_file.write_text("pytest\n")
    output_file = tmp_path / "output.tar.gz"

    # Should not raise any exception
    bundle_python.validate_inputs("x86_64-unknown-linux-gnu", requirements_file, output_file)


def test_validate_inputs_with_invalid_target(tmp_path):
    """Test validation fails with invalid target."""
    requirements_file = tmp_path / "requirements.txt"
    requirements_file.write_text("pytest\n")
    output_file = tmp_path / "output.tar.gz"

    with pytest.raises(SystemExit) as exc_info:
        bundle_python.validate_inputs("invalid-target", requirements_file, output_file)

    assert exc_info.value.code == 1


def test_validate_inputs_with_missing_requirements_file(tmp_path):
    """Test validation fails when requirements file does not exist."""
    requirements_file = tmp_path / "nonexistent.txt"
    output_file = tmp_path / "output.tar.gz"

    with pytest.raises(SystemExit) as exc_info:
        bundle_python.validate_inputs("x86_64-unknown-linux-gnu", requirements_file, output_file)

    assert exc_info.value.code == 1


def test_validate_inputs_with_requirements_path_is_directory(tmp_path):
    """Test validation fails when requirements path is a directory."""
    requirements_dir = tmp_path / "requirements_dir"
    requirements_dir.mkdir()
    output_file = tmp_path / "output.tar.gz"

    with pytest.raises(SystemExit) as exc_info:
        bundle_python.validate_inputs("x86_64-unknown-linux-gnu", requirements_dir, output_file)

    assert exc_info.value.code == 1


def test_validate_inputs_creates_output_directory(tmp_path):
    """Test validation creates output directory if it doesn't exist."""
    requirements_file = tmp_path / "requirements.txt"
    requirements_file.write_text("pytest\n")
    output_dir = tmp_path / "nested" / "output"
    output_file = output_dir / "bundle.tar.gz"

    bundle_python.validate_inputs("x86_64-unknown-linux-gnu", requirements_file, output_file)

    assert output_dir.exists()


def test_validate_inputs_with_non_writable_directory(tmp_path):
    """Test validation fails when output directory is not writable."""
    requirements_file = tmp_path / "requirements.txt"
    requirements_file.write_text("pytest\n")
    output_file = tmp_path / "output.tar.gz"

    # Mock os.access to return False for write permission
    with patch("bundle_python.os.access", return_value=False):
        with pytest.raises(SystemExit) as exc_info:
            bundle_python.validate_inputs("x86_64-unknown-linux-gnu", requirements_file, output_file)

        assert exc_info.value.code == 1


@pytest.mark.parametrize(
    "target,expected",
    [
        ("x86_64-unknown-linux-gnu", True),
        ("aarch64-unknown-linux-gnu", True),
        ("aarch64-apple-darwin", True),
        ("x86_64-pc-windows-msvc", True),
        ("invalid-target", False),
        ("", False),
    ],
)
def test_validate_target_support(target, expected):
    """Test target validation with various inputs."""
    is_valid = target in bundle_python.URLS
    assert is_valid == expected


def test_find_site_packages_windows(tmp_path):
    """Test finding site-packages on Windows platform."""
    python_root = tmp_path / "python"
    site_packages = python_root / "Lib" / "site-packages"
    site_packages.mkdir(parents=True)

    result = bundle_python.find_site_packages(python_root, "x86_64-pc-windows-msvc")

    assert result == site_packages


def test_find_site_packages_unix(tmp_path):
    """Test finding site-packages on Unix platform."""
    python_root = tmp_path / "python"
    site_packages = python_root / "lib" / "python3.13" / "site-packages"
    site_packages.mkdir(parents=True)

    result = bundle_python.find_site_packages(python_root, "x86_64-unknown-linux-gnu")

    assert result == site_packages


def test_find_site_packages_fallback_search(tmp_path):
    """Test finding site-packages via fallback search."""
    python_root = tmp_path / "python"
    # Create site-packages in a non-standard location
    nonstandard = python_root / "nonstandard" / "location" / "site-packages"
    nonstandard.mkdir(parents=True)

    result = bundle_python.find_site_packages(python_root, "x86_64-unknown-linux-gnu")

    assert result == nonstandard


def test_find_site_packages_not_found(tmp_path):
    """Test finding site-packages fails when it doesn't exist."""
    python_root = tmp_path / "python"
    python_root.mkdir()

    with pytest.raises(SystemExit) as exc_info:
        bundle_python.find_site_packages(python_root, "x86_64-unknown-linux-gnu")

    assert exc_info.value.code == 1


def test_download_with_retry_success(tmp_path):
    """Test successful download."""
    dest = tmp_path / "download.tar.gz"
    url = "https://example.com/file.tar.gz"

    # Mock urllib.request.urlretrieve to simulate successful download
    def side_effect(_url: str, dest_path: str) -> None:
        Path(dest_path).write_bytes(b"fake content" * 1000)  # Create non-empty file

    with patch("bundle_python.urllib.request.urlretrieve") as mock_retrieve:
        mock_retrieve.side_effect = side_effect

        bundle_python.download_with_retry(url, dest, max_retries=3)

        assert dest.exists()
        assert dest.stat().st_size > 0


def test_download_with_retry_empty_file_retries(tmp_path):
    """Test download retries when file is empty."""
    dest = tmp_path / "download.tar.gz"
    url = "https://example.com/file.tar.gz"

    call_count = 0

    def side_effect(_url: str, dest_path: str) -> None:
        nonlocal call_count
        call_count += 1
        if call_count < 3:
            # First two attempts create empty file
            Path(dest_path).write_bytes(b"")
        else:
            # Third attempt succeeds
            Path(dest_path).write_bytes(b"fake content" * 1000)

    with patch("bundle_python.urllib.request.urlretrieve") as mock_retrieve:
        mock_retrieve.side_effect = side_effect
        bundle_python.download_with_retry(url, dest, max_retries=3)
        assert call_count == 3
        assert dest.exists()
        assert dest.stat().st_size > 0


def test_download_with_retry_network_error_retries(tmp_path):
    """Test download retries on network errors."""
    dest = tmp_path / "download.tar.gz"
    url = "https://example.com/file.tar.gz"

    call_count = 0

    network_error = urllib.error.URLError("Network error")

    def side_effect(_url: str, dest_path: str) -> None:
        nonlocal call_count
        call_count += 1
        if call_count < 2:
            # First attempt fails
            raise network_error
        # Second attempt succeeds
        Path(dest_path).write_bytes(b"fake content" * 1000)

    with patch("bundle_python.urllib.request.urlretrieve") as mock_retrieve:
        mock_retrieve.side_effect = side_effect
        bundle_python.download_with_retry(url, dest, max_retries=3)
        assert call_count == 2
        assert dest.exists()


def test_download_with_retry_exhausts_retries(tmp_path):
    """Test download fails after exhausting all retries."""
    dest = tmp_path / "download.tar.gz"
    url = "https://example.com/file.tar.gz"

    with patch("bundle_python.urllib.request.urlretrieve") as mock_retrieve:
        mock_retrieve.side_effect = urllib.error.URLError("Persistent network error")

        with pytest.raises(SystemExit) as exc_info:
            bundle_python.download_with_retry(url, dest, max_retries=3)

        assert exc_info.value.code == 1


def test_urls_mapping_completeness():
    """Test that URLS mapping contains all expected targets."""
    expected_targets = [
        "x86_64-unknown-linux-gnu",
        "aarch64-unknown-linux-gnu",
        "aarch64-apple-darwin",
        "x86_64-pc-windows-msvc",
    ]

    for target in expected_targets:
        assert target in bundle_python.URLS, f"Missing URL mapping for {target}"
        assert bundle_python.URLS[target].startswith("https://"), f"Invalid URL for {target}"


def test_platforms_mapping_completeness():
    """Test that PLATFORMS mapping contains all expected targets."""
    expected_targets = [
        "x86_64-unknown-linux-gnu",
        "aarch64-unknown-linux-gnu",
        "aarch64-apple-darwin",
        "x86_64-pc-windows-msvc",
    ]

    for target in expected_targets:
        assert target in bundle_python.PLATFORMS, f"Missing platform mapping for {target}"


@pytest.mark.parametrize(
    "target,expected_platform",
    [
        ("x86_64-unknown-linux-gnu", "x86_64-manylinux_2_17"),
        ("aarch64-unknown-linux-gnu", "aarch64-manylinux_2_17"),
        ("aarch64-apple-darwin", "aarch64-apple-darwin"),
        ("x86_64-pc-windows-msvc", "x86_64-pc-windows-msvc"),
    ],
)
def test_platform_tag_mapping(target, expected_platform):
    """Test platform tag mapping for each target."""
    assert bundle_python.PLATFORMS[target] == expected_platform


def test_console_initialization():
    """Test that console is properly initialized."""
    assert bundle_python.console is not None
    assert hasattr(bundle_python.console, "print")


def test_main_function_exists():
    """Test that main function is defined and callable."""
    assert callable(bundle_python.main)
    assert hasattr(bundle_python.main, "params")  # Click adds this attribute


def test_validate_inputs_with_permission_error_creating_directory(tmp_path):
    """Test validation handles PermissionError when creating output directory."""
    requirements_file = tmp_path / "requirements.txt"
    requirements_file.write_text("pytest\n")
    output_dir = tmp_path / "protected" / "output"
    output_file = output_dir / "bundle.tar.gz"

    # Mock mkdir to raise PermissionError
    with patch("pathlib.Path.mkdir", side_effect=PermissionError("Access denied")):
        with pytest.raises(SystemExit) as exc_info:
            bundle_python.validate_inputs("x86_64-unknown-linux-gnu", requirements_file, output_file)

        assert exc_info.value.code == 1
