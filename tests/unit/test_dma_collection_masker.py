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
"""Unit and security regression tests for scripts/masker/dma-collection-masker (b/586644803)."""

from __future__ import annotations

import gzip
import hashlib
import io
import logging
import os
import stat
import subprocess
import sys
import tarfile
import zipfile
from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
from typing import Any

import pytest

pytestmark = pytest.mark.unit

REPO_ROOT = Path(__file__).resolve().parents[2]
MASKER_PATH = REPO_ROOT / "scripts" / "masker" / "dma-collection-masker"


def _load_masker_module() -> Any:
    module_name = "dma_collection_masker_under_test"
    if module_name in sys.modules:
        return sys.modules[module_name]
    loader = SourceFileLoader(module_name, str(MASKER_PATH))
    spec = spec_from_file_location(module_name, str(MASKER_PATH), loader=loader)
    assert spec is not None
    module = module_from_spec(spec)
    sys.modules[module_name] = module
    loader.exec_module(module)
    return module


MASKER = _load_masker_module()
ApplicationError = MASKER.ApplicationError


def _write_tar_gz(archive_path: Path, entries: list[tuple[tarfile.TarInfo, bytes | None]]) -> Path:
    with tarfile.open(archive_path, "w:gz") as tf:
        for info, payload in entries:
            if payload is None:
                tf.addfile(info)
            else:
                info.size = len(payload)
                tf.addfile(info, io.BytesIO(payload))
    return archive_path


def _tar_reg(name: str, payload: bytes = b"col1|col2\n", mode: int = 0o644) -> tuple[tarfile.TarInfo, bytes]:
    info = tarfile.TarInfo(name=name)
    info.type = tarfile.REGTYPE
    info.mode = mode
    return info, payload


def _tar_dir(name: str, mode: int = 0o755) -> tuple[tarfile.TarInfo, None]:
    info = tarfile.TarInfo(name=name)
    info.type = tarfile.DIRTYPE
    info.mode = mode
    return info, None


def _tar_link(name: str, linkname: str, *, hard: bool = False) -> tuple[tarfile.TarInfo, None]:
    info = tarfile.TarInfo(name=name)
    info.type = tarfile.LNKTYPE if hard else tarfile.SYMTYPE
    info.linkname = linkname
    return info, None


def _write_zip(archive_path: Path, entries: list[tuple[str, bytes, int | None]]) -> Path:
    with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for name, payload, external_attr in entries:
            info = zipfile.ZipInfo(name)
            if external_attr is not None:
                info.external_attr = external_attr
            zf.writestr(info, payload)
    return archive_path


# ---------------------------------------------------------------------------
# TAR (.tar.gz / .gz / .tgz) safety tests
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "unsafe_name",
    [
        "../../../../victim/PWNED",
        "../../../../victim/PWNED.csv",
        "../escape.csv",
        "./../escape.csv",
        "././../escape.csv",
        "sub/../../escape.csv",
        "/etc/passwd",
        "/victim/escape.csv",
        ".//escape.csv",
        "subdir/opdb__table__tag.csv",
        "./subdir/opdb__table__tag.csv",
        r"..\..\escape.csv",
        r"subdir\opdb__table__tag.csv",
        "C:opdb__table__tag.csv",
        "C:/opdb__table__tag.csv",
        "C:\\opdb__table__tag.csv",
        "//server/share/opdb__table__tag.csv",
        "\\\\server\\share\\opdb__table__tag.csv",
        "opdb__file.csv:$DATA",
        "opdb__a:b.csv",
        "..",
        ".",
        "./",
        ".bashrc",
        "./.bashrc",
        ".hidden.csv",
        ".csv",
        "opdb__a\n.csv",
        "opdb__a\x7f.csv",
        "opdb__trailing_dot.csv.",
        "opdb__trailing_space.csv ",
        "CON.csv",
        "nul.log",
        "COM1.txt",
        "LPT9.csv",
        "payload.sh",
        "script.py",
        "binary.exe",
        "no_extension",
        "evil.zip",
        "../mpack_evil.zip",
        "subdir/mpack_evil.zip",
        "MPACK_upper.zip",
    ],
)
def test_extract_tar_rejects_unsafe_or_disallowed_member_names(tmp_path: Path, unsafe_name: str) -> None:
    archive = _write_tar_gz(
        tmp_path / "opdb_oracle_Demo__1_4.3.48_h_d_i_20260101000000.tar.gz",
        [
            _tar_reg("opdb__valid__tag.csv", b"ok\n"),
            _tar_reg(unsafe_name, b"ATTACKER-PAYLOAD\n"),
        ],
    )
    extract_dir = tmp_path / "extract"

    with pytest.raises(ApplicationError):
        MASKER._extract_collection(archive, extract_dir)

    # Atomicity: two-pass validation rejects BEFORE any member is written to disk.
    assert not list(extract_dir.iterdir())


def test_extract_tar_pax_rejects_embedded_nul_and_traversal(tmp_path: Path) -> None:
    for pax_path in ("opdb__a.csv\x00.txt", "../../../../victim/PWNED.csv"):
        archive_path = tmp_path / f"pax_{abs(hash(pax_path))}.tar.gz"
        with tarfile.open(archive_path, "w:gz", format=tarfile.PAX_FORMAT) as tf:
            info = tarfile.TarInfo(name="opdb__safe_placeholder.csv")
            info.pax_headers = {"path": pax_path}
            payload = b"evil\n"
            info.size = len(payload)
            tf.addfile(info, io.BytesIO(payload))

        extract_dir = tmp_path / f"extract_pax_{abs(hash(pax_path))}"
        with pytest.raises(ApplicationError):
            MASKER._extract_collection(archive_path, extract_dir)
        assert not list(extract_dir.iterdir())


def test_normalize_archive_filename_rejects_embedded_nul_byte() -> None:
    with pytest.raises(ApplicationError, match="Unsafe archive member name"):
        MASKER._normalize_archive_filename("opdb__a.csv\x00.txt")


def test_extract_tar_rejects_symlink_and_symlink_chain(tmp_path: Path) -> None:
    victim_dir = tmp_path / "victim"
    victim_dir.mkdir()
    archive = _write_tar_gz(
        tmp_path / "opdb_oracle_Demo__1_4.3.48_h_d_i_20260101000000.tar.gz",
        [
            _tar_link("link", str(victim_dir)),
            _tar_reg("link/PWNED.csv", b"evil\n"),
        ],
    )
    extract_dir = tmp_path / "extract"

    with pytest.raises(ApplicationError, match="link"):
        MASKER._extract_collection(archive, extract_dir)

    assert not (victim_dir / "PWNED.csv").exists()
    assert not list(extract_dir.iterdir())


def test_extract_tar_rejects_relative_symlink_even_inside_extract_dir(tmp_path: Path) -> None:
    archive = _write_tar_gz(
        tmp_path / "opdb_oracle_Demo__1_4.3.48_h_d_i_20260101000000.tar.gz",
        [
            _tar_reg("opdb__real__tag.csv", b"real\n"),
            _tar_link("opdb__alias__tag.csv", "opdb__real__tag.csv"),
        ],
    )
    extract_dir = tmp_path / "extract"

    with pytest.raises(ApplicationError, match="link"):
        MASKER._extract_collection(archive, extract_dir)

    assert not list(extract_dir.iterdir())


def test_extract_tar_rejects_symlink_named_like_mpack_or_root(tmp_path: Path) -> None:
    for link_name in (".", "./", "mpack_DMA-OEE-PROD.zip"):
        archive = _write_tar_gz(
            tmp_path / f"bad_{abs(hash(link_name))}.tar.gz",
            [_tar_link(link_name, "/etc/passwd")],
        )
        extract_dir = tmp_path / f"extract_{abs(hash(link_name))}"
        with pytest.raises(ApplicationError, match="link"):
            MASKER._extract_collection(archive, extract_dir)


def test_extract_tar_rejects_hardlink(tmp_path: Path) -> None:
    archive = _write_tar_gz(
        tmp_path / "opdb_oracle_Demo__1_4.3.48_h_d_i_20260101000000.tar.gz",
        [_tar_link("opdb__hard__tag.csv", "/etc/passwd", hard=True)],
    )
    with pytest.raises(ApplicationError, match="link"):
        MASKER._extract_collection(archive, tmp_path / "extract")


@pytest.mark.parametrize("member_type", [tarfile.FIFOTYPE, tarfile.CHRTYPE, tarfile.BLKTYPE])
def test_extract_tar_rejects_special_file_types(tmp_path: Path, member_type: bytes) -> None:
    info = tarfile.TarInfo(name="opdb__special__tag.csv")
    info.type = member_type
    archive = _write_tar_gz(tmp_path / "special.tar.gz", [(info, None)])

    with pytest.raises(ApplicationError, match="non-regular"):
        MASKER._extract_collection(archive, tmp_path / "extract")


@pytest.mark.parametrize("dir_name", ["subdir/", "./subdir/", "/", "../", ""])
def test_extract_tar_rejects_non_root_directory_entry(tmp_path: Path, dir_name: str) -> None:
    archive = _write_tar_gz(
        tmp_path / "nested_dir.tar.gz",
        [_tar_dir(dir_name)],
    )
    with pytest.raises(ApplicationError, match="directory"):
        MASKER._extract_collection(archive, tmp_path / "extract")


@pytest.mark.parametrize(
    ("first", "second"),
    [
        ("opdb__dup__tag.csv", "opdb__dup__tag.csv"),
        ("opdb__dup__tag.csv", "./opdb__dup__tag.csv"),
        ("opdb__dup__tag.csv", "OPDB__DUP__TAG.CSV"),
        ("mpack_oee.zip", "mpack_OEE.zip"),
    ],
)
def test_extract_tar_rejects_duplicate_and_case_colliding_members(tmp_path: Path, first: str, second: str) -> None:
    archive = _write_tar_gz(
        tmp_path / "dup.tar.gz",
        [_tar_reg(first, b"one\n"), _tar_reg(second, b"two\n")],
    )
    extract_dir = tmp_path / "extract"

    with pytest.raises(ApplicationError, match="Duplicate"):
        MASKER._extract_collection(archive, extract_dir)

    assert not list(extract_dir.iterdir())


def test_extract_tar_rejects_uncompressed_tar_disguised_as_gz(tmp_path: Path) -> None:
    fake_gz = tmp_path / "opdb_oracle_Demo__1_4.3.48_h_d_i_20260101000000.tar.gz"
    with tarfile.open(fake_gz, "w") as tf:
        info, payload = _tar_reg("opdb__a__tag.csv", b"hello\n")
        info.size = len(payload)
        tf.addfile(info, io.BytesIO(payload))

    with pytest.raises(ApplicationError, match="Failed to extract gzip tar archive"):
        MASKER._extract_collection(fake_gz, tmp_path / "extract")


def test_extract_tar_rejects_plain_gzip_non_tar(tmp_path: Path) -> None:
    plain_gz = tmp_path / "opdb_oracle_Demo__1_4.3.48_h_d_i_20260101000000.gz"
    plain_gz.write_bytes(gzip.compress(b"not a tar archive"))

    with pytest.raises(ApplicationError, match="Failed to extract gzip tar archive"):
        MASKER._extract_collection(plain_gz, tmp_path / "extract")


def test_extract_tar_accepts_valid_flat_and_dot_slash_members(tmp_path: Path, caplog: pytest.LogCaptureFixture) -> None:
    oee_bytes = b"PK\x03\x04fake-oee-archive"
    archive = _write_tar_gz(
        tmp_path / "opdb_oracle_Demo__1_4.3.48_h_d_i_20260101000000.tar.gz",
        [
            _tar_dir("."),
            _tar_reg("./opdb__dbsummary__tag.csv", b"PKEY|DB\nk|v\n"),
            _tar_reg("opdb__tag_errors.log", b""),
            _tar_reg("./opdb__manifest__tag.txt", b"oracle|abc|x\n"),
            _tar_reg("mpack_DMA-OEE-PROD.tag.zip", oee_bytes),
        ],
    )
    original_digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    extract_dir = tmp_path / "extract"

    with caplog.at_level(logging.WARNING):
        MASKER._extract_collection(archive, extract_dir)

    assert sorted(p.name for p in extract_dir.iterdir()) == [
        "opdb__dbsummary__tag.csv",
        "opdb__manifest__tag.txt",
        "opdb__tag_errors.log",
    ]
    assert (extract_dir / "opdb__dbsummary__tag.csv").read_bytes() == b"PKEY|DB\nk|v\n"
    assert (extract_dir / "opdb__tag_errors.log").read_bytes() == b""
    assert not (extract_dir / "mpack_DMA-OEE-PROD.tag.zip").exists()
    assert "mpack_DMA-OEE-PROD.tag.zip" in caplog.text
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == original_digest


def test_extract_tar_does_not_preserve_dangerous_mode_bits(tmp_path: Path) -> None:
    archive = _write_tar_gz(
        tmp_path / "modes.tar.gz",
        [
            _tar_reg("opdb__suid__tag.csv", b"a\n", mode=0o4777),
            _tar_reg("opdb__ro__tag.log", b"b\n", mode=0o000),
        ],
    )
    extract_dir = tmp_path / "extract"
    MASKER._extract_collection(archive, extract_dir)

    suid_file = extract_dir / "opdb__suid__tag.csv"
    ro_file = extract_dir / "opdb__ro__tag.log"
    assert suid_file.read_bytes() == b"a\n"
    assert ro_file.read_bytes() == b"b\n"
    if os.name == "posix":
        assert (suid_file.stat().st_mode & (stat.S_ISUID | stat.S_ISGID | stat.S_ISVTX)) == 0
        assert (suid_file.stat().st_mode & 0o111) == 0
        assert (ro_file.stat().st_mode & stat.S_IRUSR) != 0
        assert (ro_file.stat().st_mode & stat.S_IWUSR) != 0


# ---------------------------------------------------------------------------
# ZIP safety tests
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "unsafe_name",
    [
        "../../../../victim/PWNED",
        "../escape.csv",
        "./../escape.csv",
        "/etc/passwd",
        "/victim/escape.csv",
        "subdir/opdb__table__tag.csv",
        r"..\..\escape.csv",
        "C:opdb__table__tag.csv",
        "C:/opdb__table__tag.csv",
        "//server/share/opdb__table__tag.csv",
        "opdb__a:stream.csv",
        ".bashrc",
        ".hidden.csv",
        "opdb__a\n.csv",
        "opdb__a\x7f.csv",
        "payload.sh",
        "evil.zip",
        "../mpack_evil.zip",
        "NUL.csv",
        "opdb__trailing.csv.",
        "opdb__trailing.csv ",
    ],
)
def test_extract_zip_rejects_unsafe_or_disallowed_member_names(tmp_path: Path, unsafe_name: str) -> None:
    archive = _write_zip(
        tmp_path / "opdb_mssql_test__1_4.3.48_h_d_i_20260101000000.zip",
        [
            ("opdb__valid__tag.csv", b"ok\n", None),
            (unsafe_name, b"evil\n", None),
        ],
    )
    extract_dir = tmp_path / "extract"

    with pytest.raises(ApplicationError):
        MASKER._extract_collection(archive, extract_dir)

    assert not list(extract_dir.iterdir())


def test_extract_zip_rejects_raw_nul_truncated_member_name(tmp_path: Path) -> None:
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as zf:
        zf.writestr("opdb__aX.csv", b"evil\n")
    archive = tmp_path / "raw_nul.zip"
    archive.write_bytes(buf.getvalue().replace(b"opdb__aX.csv", b"opdb__a\x00.csv"))
    extract_dir = tmp_path / "extract"

    with pytest.raises(ApplicationError):
        MASKER._extract_collection(archive, extract_dir)

    assert not list(extract_dir.iterdir())


@pytest.mark.parametrize(
    ("name", "mode"),
    [
        ("opdb__sym__tag.csv", (stat.S_IFLNK | 0o777) << 16),
        ("./", (stat.S_IFLNK | 0o777) << 16),
        ("mpack_DMA-OEE-PROD.zip", (stat.S_IFLNK | 0o777) << 16),
        ("opdb__fifo__tag.csv", (stat.S_IFIFO | 0o600) << 16),
        ("opdb__chr__tag.csv", (stat.S_IFCHR | 0o600) << 16),
        ("opdb__blk__tag.csv", (stat.S_IFBLK | 0o600) << 16),
        ("opdb__spoofdir__tag.csv", (stat.S_IFDIR | 0o755) << 16),
    ],
)
def test_extract_zip_rejects_symlink_and_special_external_attr(tmp_path: Path, name: str, mode: int) -> None:
    archive = _write_zip(
        tmp_path / "bad_attr.zip",
        [(name, b"/etc/passwd", mode)],
    )
    extract_dir = tmp_path / "extract"

    with pytest.raises(ApplicationError):
        MASKER._extract_collection(archive, extract_dir)

    assert not list(extract_dir.iterdir())


def test_extract_zip_rejects_non_root_directory_entry(tmp_path: Path) -> None:
    archive = _write_zip(
        tmp_path / "nested_dir.zip",
        [("subdir/", b"", (stat.S_IFDIR | 0o755) << 16)],
    )
    with pytest.raises(ApplicationError, match="directory"):
        MASKER._extract_collection(archive, tmp_path / "extract")


def test_extract_zip_rejects_duplicate_and_case_colliding_entries(tmp_path: Path) -> None:
    archive = _write_zip(
        tmp_path / "dup.zip",
        [
            ("opdb__TableList__tag.csv", b"first\n", None),
            ("opdb__tablelist__tag.csv", b"second\n", None),
        ],
    )
    extract_dir = tmp_path / "extract"

    with pytest.raises(ApplicationError, match="Duplicate"):
        MASKER._extract_collection(archive, extract_dir)

    assert not list(extract_dir.iterdir())


def test_extract_zip_rejects_corrupt_archive(tmp_path: Path) -> None:
    bad_zip = tmp_path / "opdb_mssql_bad.zip"
    bad_zip.write_bytes(b"not a zip file")

    with pytest.raises(ApplicationError, match="Failed to extract ZIP archive"):
        MASKER._extract_collection(bad_zip, tmp_path / "extract")


def test_extract_zip_accepts_all_real_collector_naming_conventions(
    tmp_path: Path, caplog: pytest.LogCaptureFixture
) -> None:
    archive = _write_zip(
        tmp_path / "opdb_mssql_full__1_4.3.48_h_d_i_20260101000000.zip",
        [
            ("./", b"", (stat.S_IFDIR | 0o755) << 16),
            ("opdb__TableList__tag.csv", b"csv-data\n", (stat.S_IFREG | 0o644) << 16),
            ("opdb_mssql_collectorLog__tag.log", b"collector-log\n", 0),
            ("opdb_mssql_sqlErrorlog__tag.log", b"error-log\n", None),
            ("opdb__perfMonLog__tag.log", b"perf-log\n", None),
            ("HOST1_Google-DMA-SQLServerDataSet-MSSQLSERVER01012026.csv", b"perfmon\n", None),
            ("COLLECTION_SUMMARY.txt", b"summary\n", None),
            ("CRASH_REPORT.txt", b"crash\n", None),
            ("mpack_DMA-OEE-PROD.tag.zip", b"oee-bytes", (stat.S_IFREG | 0o644) << 16),
        ],
    )
    extract_dir = tmp_path / "extract"

    with caplog.at_level(logging.WARNING):
        MASKER._extract_collection(archive, extract_dir)

    assert sorted(p.name for p in extract_dir.iterdir()) == [
        "COLLECTION_SUMMARY.txt",
        "CRASH_REPORT.txt",
        "HOST1_Google-DMA-SQLServerDataSet-MSSQLSERVER01012026.csv",
        "opdb__TableList__tag.csv",
        "opdb__perfMonLog__tag.log",
        "opdb_mssql_collectorLog__tag.log",
        "opdb_mssql_sqlErrorlog__tag.log",
    ]
    assert not (extract_dir / "mpack_DMA-OEE-PROD.tag.zip").exists()
    assert "mpack_DMA-OEE-PROD.tag.zip" in caplog.text


# ---------------------------------------------------------------------------
# General extraction guards
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("filename", ["archive.bz2", "archive.tar", "archive.txt", "foozip", "foogz"])
def test_extract_collection_rejects_unsupported_extension(tmp_path: Path, filename: str) -> None:
    path = tmp_path / filename
    path.write_bytes(b"data")

    with pytest.raises(ApplicationError, match="Unsupported collection archive format"):
        MASKER._extract_collection(path, tmp_path / "extract")


def test_extract_refuses_to_overwrite_existing_file_and_cleans_up_new_files(tmp_path: Path) -> None:
    extract_dir = tmp_path / "extract"
    extract_dir.mkdir()
    preexisting = extract_dir / "opdb__existing__tag.csv"
    preexisting.write_bytes(b"KEEP-ME")

    archive = _write_zip(
        tmp_path / "collide.zip",
        [
            ("opdb__new__tag.csv", b"NEW", None),
            ("opdb__existing__tag.csv", b"OVERWRITE", None),
        ],
    )

    with pytest.raises(ApplicationError, match="already exists"):
        MASKER._extract_collection(archive, extract_dir)

    assert preexisting.read_bytes() == b"KEEP-ME"
    assert not (extract_dir / "opdb__new__tag.csv").exists()


def test_extract_refuses_to_write_through_existing_symlink_in_extract_dir(tmp_path: Path) -> None:
    extract_dir = tmp_path / "extract"
    extract_dir.mkdir()
    outside = tmp_path / "outside.txt"
    outside.write_bytes(b"ORIGINAL")
    symlink_path = extract_dir / "opdb__target__tag.csv"
    try:
        symlink_path.symlink_to(outside)
    except (OSError, NotImplementedError):
        pytest.skip("Platform does not permit creating symlinks in tests")

    archive = _write_tar_gz(
        tmp_path / "symlink_dest.tar.gz",
        [_tar_reg("opdb__target__tag.csv", b"OVERWRITTEN")],
    )

    with pytest.raises(ApplicationError, match="symlink"):
        MASKER._extract_collection(archive, extract_dir)

    assert outside.read_bytes() == b"ORIGINAL"


def test_clean_folder_unlinks_symlink_without_touching_target(tmp_path: Path) -> None:
    outside_dir = tmp_path / "outside_dir"
    outside_dir.mkdir()
    victim = outside_dir / "keep.txt"
    victim.write_text("safe", encoding="utf-8")

    work_dir = tmp_path / "work"
    work_dir.mkdir()
    link = work_dir / "dir_link"
    try:
        link.symlink_to(outside_dir, target_is_directory=True)
    except (OSError, NotImplementedError):
        pytest.skip("Platform does not permit creating symlinks in tests")

    MASKER._clean_folder(work_dir)

    assert not link.exists() and not link.is_symlink()
    assert victim.exists()
    assert victim.read_text(encoding="utf-8") == "safe"


# ---------------------------------------------------------------------------
# End-to-end public CLI regression tests (b/586644803 PoC scenario)
# ---------------------------------------------------------------------------


def test_cli_blocks_tar_slip_poc_archive(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "output"
    victim_dir = tmp_path / "victim"
    input_dir.mkdir()
    output_dir.mkdir()
    victim_dir.mkdir()

    # Exact traversal depth targeting victim_dir/PWNED outside any temp directory.
    traversal_name = "../../../../../../../../" + victim_dir.as_posix().lstrip("/") + "/PWNED"
    archive_name = "opdb_oracle_DemoDB__collection_4.3.44_evilhost_evildb_evilinst_20240101120000.tar.gz"
    _write_tar_gz(
        input_dir / archive_name,
        [_tar_reg(traversal_name, b"ARBITRARY-WRITE-BY-TAR-SLIP\n")],
    )

    proc = subprocess.run(
        [sys.executable, str(MASKER_PATH), "--collection-path", str(input_dir), "--output-path", str(output_dir)],
        capture_output=True,
        text=True,
        check=False,
    )

    assert proc.returncode != 0
    assert "ApplicationError" in proc.stderr
    assert not (victim_dir / "PWNED").exists()
    assert not list(output_dir.iterdir())


def test_cli_masks_valid_oracle_tar_gz_preserving_nested_oee_unmodified(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "output"
    input_dir.mkdir()
    output_dir.mkdir()

    tag = "123456_4.3.48_myhost_mydb_myinst_20260101120000"
    archive_path = input_dir / f"opdb_oracle_DemoDB__{tag}.tar.gz"
    oee_payload = b"PK\x03\x04original-unmodified-oee-content"
    csv_content = (
        b'"PKEY"|"VALUE"|"DMA_SOURCE_ID"|"DMA_MANUAL_ID"\n"myhost_mydb_20260101120000"|"ok"|"src-1"|"manual-1"\n'
    )
    _write_tar_gz(
        archive_path,
        [
            _tar_reg(f"opdb__eoj__{tag}.csv", csv_content),
            _tar_reg(f"opdb__defines__{tag}.csv", b"v_tag = test\n"),
            _tar_reg(f"opdb__{tag}_errors.log", b""),
            _tar_reg(f"opdb__{tag}_locale.txt", b"LANG=C.UTF-8\n"),
            _tar_reg(f"mpack_DMA-OEE-PROD.{tag}.zip", oee_payload),
        ],
    )
    input_sha256_before = hashlib.sha256(archive_path.read_bytes()).hexdigest()

    proc = subprocess.run(
        [sys.executable, str(MASKER_PATH), "--collection-path", str(input_dir), "--output-path", str(output_dir)],
        capture_output=True,
        text=True,
        check=False,
    )

    assert proc.returncode == 0, proc.stderr
    assert "Skipping nested Oracle OEE archive" in proc.stderr
    assert hashlib.sha256(archive_path.read_bytes()).hexdigest() == input_sha256_before

    masked_zips = list(output_dir.glob("*.zip"))
    assert len(masked_zips) == 1
    with zipfile.ZipFile(masked_zips[0], "r") as out_zf:
        names = out_zf.namelist()
    assert any(n.startswith("opdb__eoj__") and n.endswith(".csv") for n in names)
    assert any(n.startswith("opdb__manifest__") and n.endswith(".txt") for n in names)
    assert not any(n.startswith("mpack") for n in names)


def test_cli_masks_valid_oracle_zip_preserving_nested_oee_unmodified(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "output"
    input_dir.mkdir()
    output_dir.mkdir()

    tag = "123456_4.3.48_myhost_mydb_myinst_20260101120000"
    archive_path = input_dir / f"opdb_oracle_DemoDB__{tag}.zip"
    oee_payload = b"PK\x03\x04original-unmodified-oee-content"
    csv_content = (
        b'"PKEY"|"VALUE"|"DMA_SOURCE_ID"|"DMA_MANUAL_ID"\n"myhost_mydb_20260101120000"|"ok"|"src-1"|"manual-1"\n'
    )
    _write_zip(
        archive_path,
        [
            (f"opdb__eoj__{tag}.csv", csv_content, (stat.S_IFREG | 0o644) << 16),
            (f"opdb__defines__{tag}.csv", b"v_tag = test\n", (stat.S_IFREG | 0o644) << 16),
            (f"opdb__{tag}_errors.log", b"", (stat.S_IFREG | 0o644) << 16),
            (f"opdb__{tag}_locale.txt", b"LANG=C.UTF-8\n", (stat.S_IFREG | 0o644) << 16),
            (f"mpack_DMA-OEE-PROD.{tag}.zip", oee_payload, (stat.S_IFREG | 0o644) << 16),
        ],
    )
    input_sha256_before = hashlib.sha256(archive_path.read_bytes()).hexdigest()

    proc = subprocess.run(
        [sys.executable, str(MASKER_PATH), "--collection-path", str(input_dir), "--output-path", str(output_dir)],
        capture_output=True,
        text=True,
        check=False,
    )

    assert proc.returncode == 0, proc.stderr
    assert "Skipping nested Oracle OEE archive" in proc.stderr
    assert hashlib.sha256(archive_path.read_bytes()).hexdigest() == input_sha256_before

    masked_zips = list(output_dir.glob("*.zip"))
    assert len(masked_zips) == 1
    with zipfile.ZipFile(masked_zips[0], "r") as out_zf:
        names = out_zf.namelist()
    assert any(n.startswith("opdb__eoj__") and n.endswith(".csv") for n in names)
    assert any(n.startswith("opdb__manifest__") and n.endswith(".txt") for n in names)
    assert not any(n.startswith("mpack") for n in names)


def test_extract_streams_multi_chunk_payload_without_corruption(tmp_path: Path) -> None:
    payload = b"A" * (MASKER._EXTRACT_CHUNK_BYTES + 4096)
    expected_digest = hashlib.sha256(payload).hexdigest()

    tar_archive = _write_tar_gz(tmp_path / "large.tar.gz", [_tar_reg("opdb__big__tag.CSV", payload)])
    tar_out = tmp_path / "tar_out"
    MASKER._extract_collection(tar_archive, tar_out)
    assert hashlib.sha256((tar_out / "opdb__big__tag.CSV").read_bytes()).hexdigest() == expected_digest

    zip_archive = _write_zip(tmp_path / "large.zip", [("opdb__big__tag.TXT", payload, None)])
    zip_out = tmp_path / "zip_out"
    MASKER._extract_collection(zip_archive, zip_out)
    assert hashlib.sha256((zip_out / "opdb__big__tag.TXT").read_bytes()).hexdigest() == expected_digest


def test_extract_zip_cleans_up_partial_files_on_bad_crc(tmp_path: Path) -> None:
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", compression=zipfile.ZIP_STORED) as zf:
        zf.writestr("opdb__first__tag.csv", b"FIRST_OK")
        zf.writestr("opdb__second__tag.csv", b"SECOND_PAYLOAD_MARKER")
    corrupted = buf.getvalue().replace(b"SECOND_PAYLOAD_MARKER", b"SECOND_PAYLOAD_BROKEN")
    archive = tmp_path / "bad_crc.zip"
    archive.write_bytes(corrupted)
    extract_dir = tmp_path / "extract"

    with pytest.raises(ApplicationError, match="Failed to extract ZIP archive"):
        MASKER._extract_collection(archive, extract_dir)

    assert not list(extract_dir.iterdir())
