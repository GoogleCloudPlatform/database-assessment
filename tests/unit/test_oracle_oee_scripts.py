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
"""Unit tests for Oracle OEE credential handling and dual v5.1 / v6.1.1 support."""

from __future__ import annotations

import operator
import os
import shlex
import shutil
import signal
import stat
import subprocess
import sys
import time
import zipfile
from pathlib import Path

import pytest

pytestmark = [
    pytest.mark.unit,
    pytest.mark.skipif(sys.platform == "win32", reason="Oracle bash collector tests require a POSIX shell"),
]

REPO_ROOT = Path(__file__).resolve().parents[2]
ORACLE_DIR = REPO_ROOT / "scripts" / "collector" / "oracle"
DMA_OEE_SH = ORACLE_DIR / "dma_oee.sh"
COLLECT_DATA_SH = ORACLE_DIR / "collect-data.sh"
DMA_PRINT_SH = ORACLE_DIR / "dma_print_pass_fail.sh"
DMA_BATCH_RUN_SH = ORACLE_DIR / "dma_batch_run.sh"
DMA_PRECHECK_SH = ORACLE_DIR / "dma_precheck.sh"
SHIPPED_OEE_DIR = ORACLE_DIR / "oee"
SHIPPED_EXTRACT_SH = SHIPPED_OEE_DIR / "oee_group_extract-SA.sh"


def _discover_bash_binaries() -> list[tuple[str, int]]:
    """Return distinct usable bash binaries paired with their major version."""
    candidates: list[str] = []
    for path_candidate in ("/opt/homebrew/bin/bash", "/usr/local/bin/bash", "/bin/bash", shutil.which("bash") or ""):
        if path_candidate and Path(path_candidate).is_file() and os.access(path_candidate, os.X_OK):
            resolved = str(Path(path_candidate).resolve())
            if resolved not in candidates:
                candidates.append(resolved)

    discovered: list[tuple[str, int]] = []
    for bash_bin in candidates:
        res = subprocess.run(
            [bash_bin, "-c", 'printf "%s" "${BASH_VERSINFO[0]}"'],
            capture_output=True,
            text=True,
            check=False,
        )
        if res.returncode == 0 and res.stdout.strip().isdigit():
            discovered.append((bash_bin, int(res.stdout.strip())))
    return discovered


BASH_BINARIES = _discover_bash_binaries()
PRIMARY_BASH = max(BASH_BINARIES, key=operator.itemgetter(1))[0] if BASH_BINARIES else "/bin/bash"
PRIMARY_BASH_MAJOR = max((pair[1] for pair in BASH_BINARIES), default=0)
BASH_4_PLUS = next((b for b, v in BASH_BINARIES if v >= 4), None)
BASH_3 = next((b for b, v in BASH_BINARIES if v == 3), None)
MD5_BIN = shutil.which("md5sum") or "/sbin/md5sum"


def _run_bash(
    script: str,
    *,
    bash_bin: str = PRIMARY_BASH,
    cwd: Path | None = None,
    env: dict[str, str] | None = None,
    timeout: int = 60,
) -> subprocess.CompletedProcess[str]:
    """Execute a bash snippet using ``bash_bin`` and return the completed process."""
    run_env = os.environ.copy()
    if env:
        run_env.update(env)
    return subprocess.run(
        [bash_bin, "-c", script],
        cwd=cwd,
        env=run_env,
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )


def _create_empty_zip(dest: Path, member_name: str = "extract.txt", data: str = "ok\n") -> None:
    """Create a valid minimal ZIP archive at ``dest``."""
    with zipfile.ZipFile(dest, "w") as zf:
        zf.writestr(member_name, data)


def _write_executable(path: Path, content: str) -> Path:
    """Write a script file and mark it executable by the owner."""
    path.write_text(content, encoding="utf-8")
    path.chmod(0o700)
    return path


def _make_oee_env(tmp_path: Path) -> tuple[Path, Path, Path]:
    """Create isolated ``oee_dir``, ``output_dir``, and ``log_dir`` under ``tmp_path``."""
    oee_dir = tmp_path / "oee"
    output_dir = tmp_path / "output"
    log_dir = tmp_path / "log"
    oee_dir.mkdir(mode=0o755)
    output_dir.mkdir(mode=0o755)
    log_dir.mkdir(mode=0o755)
    return oee_dir, output_dir, log_dir


def _assert_no_secret_anywhere(root: Path, secret: str) -> None:
    """Assert ``secret`` does not appear in any file inside ``root``."""
    for file_path in root.rglob("*"):
        if file_path.is_file() and not file_path.is_symlink():
            raw = file_path.read_bytes()
            assert secret.encode("utf-8") not in raw, f"Secret leaked in {file_path}"


def _make_mock_v5_extractor(oee_dir: Path, extra_body: str = "") -> Path:
    """Install an executable mock v5.1 ``oee_group_extract-SA.sh`` inside ``oee_dir``."""
    body = f"""#!{PRIMARY_BASH}
read -r choice
if [[ "${{choice}}" != "2" ]]; then
  echo "Unexpected extract choice: ${{choice}}" >&2
  exit 2
fi
driver="$1"
group_label=$(echo "${{driver}}" | awk '{{split($0,a,"_"); print a[2]}}' | awk '{{split($0,b,"."); print b[1]}}')
{extra_body}
printf 'mock log for %s\\n' "${{driver}}" > "${{driver}}_261124_000000.log"
python3 -c 'import sys, zipfile; z=zipfile.ZipFile(sys.argv[1],"w"); z.writestr("payload.txt", sys.argv[2]); z.close()' "${{group_label}}.zip" "${{driver}}"
"""
    (oee_dir / "oee_group_dbextract-SA.sql").write_text("-- mock v5 dbextract\n", encoding="utf-8")
    (oee_dir / "oee_group_metrics-SA.sql").write_text("-- mock v5 metrics\n", encoding="utf-8")
    return _write_executable(oee_dir / "oee_group_extract-SA.sh", body)


def _make_mock_v6_extractor(oee_dir: Path, *, chunks: int = 1, extra_body: str = "") -> Path:
    """Install an executable mock v6.1.1 ``oee_group_extract-SA.sh`` inside ``oee_dir``."""
    chunk_loop = "\n".join(
        f'python3 -c \'import sys, zipfile; z=zipfile.ZipFile(sys.argv[1],"w"); z.writestr("chunk_{i}.txt", sys.argv[2]); z.close()\' "${{group_label}}_${{label}}_{i:03d}.zip" "${{driver}}"'
        for i in range(1, chunks + 1)
    )
    body = f"""#!{PRIMARY_BASH}
# v6.1.1 detection markers:
# OEE_GROUP_PARALLELISM="${{OEE_GROUP_PARALLELISM:-4}}"
archive_prefix="default"
read -r choice
if [[ "${{choice}}" != "2" ]]; then
  echo "Unexpected extract choice: ${{choice}}" >&2
  exit 2
fi
if [[ "${{OEE_GROUP_RESUME:-}}" != "N" ]]; then
  echo "Expected OEE_GROUP_RESUME=N, got: ${{OEE_GROUP_RESUME:-unset}}" >&2
  exit 3
fi
driver="$1"
mode="${{2:-}}"
label="default"
case "${{mode}}" in
  -all) label="all" ;;
  -security) label="security" ;;
esac
rest="${{driver#*_}}"
group_label="${{rest%%.*}}"
mkdir -p "${{driver}}_${{label}}_output/logs"
{extra_body}
cp -- "${{driver}}" "${{driver}}_261124_000000.summary"
printf 'mock v6 log for %s\\n' "${{driver}}" > "${{driver}}_${{label}}_output/logs/run.log"
{chunk_loop}
"""
    (oee_dir / "oee_group_dbextract-SA.sql").write_text("-- mock v6 dbextract\n", encoding="utf-8")
    (oee_dir / "oee_group_metrics-SA.sql").write_text("-- mock v6 metrics\n", encoding="utf-8")
    (oee_dir / "oee_group_dbsecurity-SA.sql").write_text("-- mock v6 dbsecurity\n", encoding="utf-8")
    return _write_executable(oee_dir / "oee_group_extract-SA.sh", body)


class TestSyntaxAndUnmodifiedVendorScripts:
    """Syntax checks across available Bash versions and upstream OEE script checks."""

    @pytest.mark.parametrize(("bash_bin", "major"), BASH_BINARIES)
    @pytest.mark.parametrize(
        "script_path",
        [DMA_OEE_SH, COLLECT_DATA_SH, DMA_BATCH_RUN_SH, DMA_PRECHECK_SH, SHIPPED_EXTRACT_SH],
        ids=lambda p: p.name,
    )
    def test_bash_syntax_clean(self, bash_bin: str, major: int, script_path: Path) -> None:
        res = subprocess.run([bash_bin, "-n", str(script_path)], capture_output=True, text=True, check=False)
        assert res.returncode == 0, f"bash {major} ({bash_bin}) syntax error in {script_path}: {res.stderr}"

    def test_shipped_oee_directory_is_unmodified_v51(self) -> None:
        assert SHIPPED_EXTRACT_SH.is_file()
        assert (SHIPPED_OEE_DIR / "oee_group_dbextract-SA.sql").is_file()
        assert (SHIPPED_OEE_DIR / "oee_group_metrics-SA.sql").is_file()
        content = SHIPPED_EXTRACT_SH.read_text(encoding="utf-8", errors="replace")
        assert "OEE Group Extract Standalone v5.1" in content

        git_bin = shutil.which("git")
        if git_bin and (REPO_ROOT / ".git").exists():
            diff = subprocess.run(
                [git_bin, "diff", "--", "scripts/collector/oracle/oee/"],
                cwd=REPO_ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            assert diff.returncode == 0
            assert diff.stdout == "", f"Upstream oee/ scripts must remain unmodified:\n{diff.stdout}"

    def test_extractor_version_detection(self, tmp_path: Path) -> None:
        v6_script = tmp_path / "v6.sh"
        v6_script.write_text("# OEE_GROUP_PARALLELISM=4\narchive_prefix=foo\n", encoding="utf-8")
        res = _run_bash(
            f"""
            . {shlex.quote(str(DMA_OEE_SH))}
            printf 'shipped=%s\\n' "$(_oee_detect_extractor_version {shlex.quote(str(SHIPPED_EXTRACT_SH))})"
            printf 'v6=%s\\n' "$(_oee_detect_extractor_version {shlex.quote(str(v6_script))})"
            printf 'missing=%s\\n' "$(_oee_detect_extractor_version /nonexistent/oee.sh)"
            """
        )
        assert res.returncode == 0, res.stderr
        assert res.stdout.splitlines() == ["shipped=v5", "v6=v6", "missing=v5"]


class TestDriverFileSecurity:
    """Verify b/586645294 mitigation: mode 0600, no passwords written to persistent driver files."""

    @pytest.mark.parametrize(("bash_bin", "_major"), BASH_BINARIES)
    def test_single_tenant_driver_has_0600_and_no_password(self, tmp_path: Path, bash_bin: str, _major: int) -> None:
        oee_dir, output_dir, _ = _make_oee_env(tmp_path)
        canary = "S3cretP@ssw0rd!#&*$ "
        script = f"""
        set -euo pipefail
        umask 0022
        oee_dir={shlex.quote(str(oee_dir))}
        output_dir={shlex.quote(str(output_dir))}
        grep_cmd=grep
        md5_cmd={shlex.quote(MD5_BIN)}
        md5_col=1
        . {shlex.quote(str(DMA_OEE_SH))}
        oee_generate_config "db-guid-1" "ORCL" "dbhost.example.com" "1521" "dma_user" {shlex.quote(canary)} "TEST" "run_001" "tag1.csv"
        printf 'UMASK=%s\\n' "$(umask)"
        """
        res = _run_bash(script, bash_bin=bash_bin)
        assert res.returncode == 0, res.stderr
        assert "UMASK=0022" in res.stdout

        driver = oee_dir / "mpack_DMA-OEE-TEST.tag1.csv.driverfile.run_001"
        assert driver.is_file()
        assert stat.S_IMODE(driver.stat().st_mode) == 0o600
        line = driver.read_text(encoding="utf-8").strip()
        assert line.endswith(":ORCL://dbhost.example.com:1521/ORCL:dma_user:")
        assert canary not in line
        assert canary not in res.stdout
        assert canary not in res.stderr
        _assert_no_secret_anywhere(tmp_path, canary)

    @pytest.mark.parametrize(("bash_bin", "_major"), BASH_BINARIES)
    def test_pdb_summary_branch_has_0600_and_no_password(self, tmp_path: Path, bash_bin: str, _major: int) -> None:
        oee_dir, output_dir, _ = _make_oee_env(tmp_path)
        canary = "S3cretP@ssw0rd!"
        tag = "190000_4.3.48_host_CDB_CDB_010126.csv"
        (output_dir / f"opdb__dbparameters__{tag}").write_text(
            "PKEY|1|db_domain|db_domain|corp.local|FALSE\n", encoding="utf-8"
        )
        (output_dir / f"opdb__pdb_summary__{tag}").write_text(
            "PKEY|CON_ID|STATE|PDB_NAME|OPEN_MODE\n"
            "k|1|ok|CDB$ROOT|READ WRITE\n"
            "k|2|ok|PDB$SEED|READ ONLY\n"
            "k|3|ok|PDB1|READ WRITE\n"
            "k|4|ok|PDB2|READ ONLY\n"
            "k|5|ok|PDB_MOUNTED|MOUNTED\n",
            encoding="utf-8",
        )
        script = f"""
        set -euo pipefail
        umask 0022
        oee_dir={shlex.quote(str(oee_dir))}
        output_dir={shlex.quote(str(output_dir))}
        grep_cmd=grep
        md5_cmd={shlex.quote(MD5_BIN)}
        md5_col=1
        . {shlex.quote(str(DMA_OEE_SH))}
        oee_generate_config "cdb-guid" "CDB" "dbhost" "1521" "c##dma" {shlex.quote(canary)} "PROD" "run_pdb1" {shlex.quote(tag)}
        """
        res = _run_bash(script, bash_bin=bash_bin)
        assert res.returncode == 0, res.stderr

        driver = oee_dir / f"mpack_DMA-OEE-PROD.{tag}.driverfile.run_pdb1"
        assert stat.S_IMODE(driver.stat().st_mode) == 0o600
        lines = driver.read_text(encoding="utf-8").splitlines()
        assert len(lines) == 2
        assert lines[0].endswith(":PDB1://dbhost:1521/PDB1.corp.local:c##dma:")
        assert lines[1].endswith(":PDB2://dbhost:1521/PDB2.corp.local:c##dma:")
        assert lines[0].split(":")[0] != lines[1].split(":")[0]
        _assert_no_secret_anywhere(tmp_path, canary)

    @pytest.mark.parametrize(("bash_bin", "_major"), BASH_BINARIES)
    def test_pdbsopenmode_branch_has_0600_and_no_password(self, tmp_path: Path, bash_bin: str, _major: int) -> None:
        oee_dir, output_dir, _ = _make_oee_env(tmp_path)
        canary = "OpenM0deP@ss!"
        tag = "121000_4.3.48_host_CDB_CDB_010126.csv"
        (output_dir / f"opdb__pdbsopenmode__{tag}").write_text(
            "PKEY|CON_ID|NAME|OPEN_MODE\nk|1|CDB$ROOT|READ WRITE\nk|2|PDB$SEED|READ ONLY\nk|3|SALES_PDB|READ WRITE\n",
            encoding="utf-8",
        )
        script = f"""
        set -euo pipefail
        umask 0022
        oee_dir={shlex.quote(str(oee_dir))}
        output_dir={shlex.quote(str(output_dir))}
        grep_cmd=grep
        md5_cmd={shlex.quote(MD5_BIN)}
        md5_col=1
        . {shlex.quote(str(DMA_OEE_SH))}
        oee_generate_config "cdb-guid" "CDB" "dbhost" "1521" "c##dma" {shlex.quote(canary)} "QA" "run_pdb2" {shlex.quote(tag)}
        """
        res = _run_bash(script, bash_bin=bash_bin)
        assert res.returncode == 0, res.stderr

        driver = oee_dir / f"mpack_DMA-OEE-QA.{tag}.driverfile.run_pdb2"
        assert stat.S_IMODE(driver.stat().st_mode) == 0o600
        lines = driver.read_text(encoding="utf-8").splitlines()
        assert len(lines) == 1
        assert lines[0].endswith(":SALES_PDB://dbhost:1521/SALES_PDB:c##dma:")
        _assert_no_secret_anywhere(tmp_path, canary)

    def test_preexisting_world_readable_driver_tightened_to_0600(self, tmp_path: Path) -> None:
        oee_dir, output_dir, _ = _make_oee_env(tmp_path)
        driver = oee_dir / "mpack_DMA-OEE-TEST.tag.csv.driverfile.run_tight"
        driver.write_text("", encoding="utf-8")
        driver.chmod(0o644)
        assert stat.S_IMODE(driver.stat().st_mode) == 0o644

        res = _run_bash(
            f"""
            umask 0022
            oee_dir={shlex.quote(str(oee_dir))}
            output_dir={shlex.quote(str(output_dir))}
            md5_cmd={shlex.quote(MD5_BIN)}
            . {shlex.quote(str(DMA_OEE_SH))}
            oee_generate_config "g1" "ORCL" "host" "1521" "user" "Secr3t!" "TEST" "run_tight" "tag.csv"
            """
        )
        assert res.returncode == 0, res.stderr
        assert stat.S_IMODE(driver.stat().st_mode) == 0o600

    @pytest.mark.parametrize(("bash_bin", "_major"), BASH_BINARIES)
    def test_double_source_preserves_in_memory_credentials(self, tmp_path: Path, bash_bin: str, _major: int) -> None:
        oee_dir, output_dir, _ = _make_oee_env(tmp_path)
        capture = tmp_path / "captured.txt"
        _make_mock_v5_extractor(oee_dir, extra_body=f'cp -- "${{driver}}" {shlex.quote(str(capture))}')
        res = _run_bash(
            f"""
            oee_dir={shlex.quote(str(oee_dir))}
            output_dir={shlex.quote(str(output_dir))}
            md5_cmd={shlex.quote(MD5_BIN)}
            . {shlex.quote(str(DMA_OEE_SH))}
            oee_generate_config "g1" "DB1" "h1" "1521" "u1" "KeepMeSecret!1" "GRP" "run_ds" "tag.csv"
            # Source a second time: stored secrets must NOT be wiped.
            . {shlex.quote(str(DMA_OEE_SH))}
            cd {shlex.quote(str(oee_dir))}
            oee_run "run_ds"
            """,
            bash_bin=bash_bin,
        )
        assert res.returncode == 0, res.stderr + res.stdout
        assert capture.read_text(encoding="utf-8").strip().endswith(":u1:KeepMeSecret!1")

    @pytest.mark.parametrize("bad_runid", ["", ".", "..", "a/b", "../evil", "bad run", "run*", "run;id"])
    def test_invalid_runid_rejected_safely(self, tmp_path: Path, bad_runid: str) -> None:
        oee_dir, output_dir, _ = _make_oee_env(tmp_path)
        sentinel = tmp_path / "keep_me.txt"
        sentinel.write_text("safe", encoding="utf-8")
        res = _run_bash(
            f"""
            oee_dir={shlex.quote(str(oee_dir))}
            output_dir={shlex.quote(str(output_dir))}
            . {shlex.quote(str(DMA_OEE_SH))}
            oee_generate_config "g" "DB" "h" "1521" "u" "p" "GRP" {shlex.quote(bad_runid)} "t.csv" && exit 10
            oee_run {shlex.quote(bad_runid)} && exit 11
            oee_cleanup_run {shlex.quote(str(oee_dir))} {shlex.quote(bad_runid)} && exit 12
            exit 0
            """
        )
        assert res.returncode == 0, res.stderr
        assert sentinel.exists()
        assert oee_dir.is_dir()


def _build_scale_targets(count: int) -> tuple[dict[str, str], list[str]]:
    """Build ``count`` distinct database target entries paired with unique passwords."""
    special_tokens = ["#", "&", "*", "!", "$", "@", "/", " "]
    expected_map: dict[str, str] = {}
    gen_calls: list[str] = []
    for idx in range(count):
        svc = f"ORCL{idx:03d}"
        host = f"db{idx:03d}.corp.example.com"
        user = f"dma_u{idx:03d}"
        tok = special_tokens[idx % len(special_tokens)]
        passwd = f"Pw{idx:03d}{tok}Key{count - idx}"
        expected_map[f"{svc}://{host}:1521/{svc}:{user}"] = passwd
        gen_calls.append(
            f"oee_generate_config 'guid-{idx:03d}' {shlex.quote(svc)} {shlex.quote(host)} 1521 "
            f"{shlex.quote(user)} {shlex.quote(passwd)} 'SCALE' 'run_250' 'batch_all.csv' >/dev/null"
        )
    return expected_map, gen_calls


class TestMultiDatabaseScale:
    """Verify hundreds of distinct per-database passwords without leaking or clobbering."""

    def test_250_databases_distinct_passwords_combined_driver(self, tmp_path: Path) -> None:
        oee_dir, output_dir, _ = _make_oee_env(tmp_path)
        captured_driver = tmp_path / "captured_driver.txt"
        mode_capture = tmp_path / "captured_modes.txt"
        _make_mock_v5_extractor(
            oee_dir,
            extra_body=(
                "python3 -c 'import os, stat, sys; "
                "print(oct(stat.S_IMODE(os.stat(sys.argv[1]).st_mode))); "
                'print(oct(stat.S_IMODE(os.stat(".").st_mode)))\' '
                f'"${{driver}}" > {shlex.quote(str(mode_capture))}\n'
                f'cp -- "${{driver}}" {shlex.quote(str(captured_driver))}\n'
            ),
        )

        expected_map, gen_calls = _build_scale_targets(250)
        check_before = tmp_path / "before_driver.txt"
        res = _run_bash(
            "\n".join([
                "set -euo pipefail",
                "umask 0022",
                f"oee_dir={shlex.quote(str(oee_dir))}",
                f"output_dir={shlex.quote(str(output_dir))}",
                f"md5_cmd={shlex.quote(MD5_BIN)}",
                f". {shlex.quote(str(DMA_OEE_SH))}",
                *gen_calls,
                f'cp -- "{oee_dir}/mpack_DMA-OEE-SCALE.batch_all.csv.driverfile.run_250" {shlex.quote(str(check_before))}',
                f"cd {shlex.quote(str(oee_dir))}",
                'oee_run "run_250" >/dev/null',
            ]),
            timeout=120,
        )
        assert res.returncode == 0, res.stderr + res.stdout

        # Before oee_run: persistent driver file contained 250 lines and ZERO passwords.
        before_raw = check_before.read_text(encoding="utf-8")
        template_lines = before_raw.splitlines()
        assert len(template_lines) == 250
        assert all(line.endswith(":") for line in template_lines)
        assert all(pw not in before_raw for pw in expected_map.values())

        # During oee_run: transient hydrated driver file was 0600 inside 0700 stage dir.
        assert mode_capture.read_text(encoding="utf-8").splitlines() == ["0o600", "0o700"]

        # Every one of the 250 databases got its EXACT unique password.
        actual_map = {
            line.split(":", 1)[1].rsplit(":", 1)[0]: line.split(":", 1)[1].rsplit(":", 1)[1]
            for line in captured_driver.read_text(encoding="utf-8").splitlines()
        }
        assert actual_map == expected_map

        # After oee_run: ZIP moved to output_dir, ZERO temp files/passwords remain in oee_dir.
        assert (output_dir / "mpack_DMA-OEE-SCALE.batch_all.zip").is_file()
        assert not (oee_dir / "run_250").exists()
        assert list(oee_dir.glob("*driverfile*")) == []
        for passwd in expected_map.values():
            _assert_no_secret_anywhere(oee_dir, passwd)

    def test_multiple_driver_files_same_group_do_not_clobber_zips(self, tmp_path: Path) -> None:
        oee_dir, output_dir, _ = _make_oee_env(tmp_path)
        _make_mock_v5_extractor(oee_dir)

        num_files = 15
        calls = [
            f"oee_generate_config 'g{i}' 'DB{i}' 'host{i}' 1521 'u{i}' 'Secret#{i}!' 'SAMEGRP' 'run_multi' 'tag_{i:02d}.csv' >/dev/null"
            for i in range(num_files)
        ]
        script = "\n".join([
            "set -euo pipefail",
            f"oee_dir={shlex.quote(str(oee_dir))}",
            f"output_dir={shlex.quote(str(output_dir))}",
            f"md5_cmd={shlex.quote(MD5_BIN)}",
            f". {shlex.quote(str(DMA_OEE_SH))}",
            *calls,
            f"cd {shlex.quote(str(oee_dir))}",
            'oee_run "run_multi" >/dev/null',
        ])
        res = _run_bash(script)
        assert res.returncode == 0, res.stderr + res.stdout

        for i in range(num_files):
            zip_path = output_dir / f"mpack_DMA-OEE-SAMEGRP.tag_{i:02d}.zip"
            assert zip_path.is_file(), f"Missing output archive {zip_path.name} (clobbered!)"
            with zipfile.ZipFile(zip_path) as zf:
                assert f"tag_{i:02d}" in zf.read("payload.txt").decode("utf-8")
        assert list(oee_dir.glob("*driverfile*")) == []
        assert not (oee_dir / "run_multi").exists()

    @pytest.mark.skipif(BASH_3 is None, reason="No Bash 3.x binary available on this host")
    def test_bash32_indexed_array_fallback_multi_db(self, tmp_path: Path) -> None:
        assert BASH_3 is not None
        oee_dir, output_dir, _ = _make_oee_env(tmp_path)
        captured = tmp_path / "b3_driver.txt"
        _make_mock_v5_extractor(oee_dir, extra_body=f'cp -- "${{driver}}" {shlex.quote(str(captured))}')
        calls = [
            f"oee_generate_config 'g{i}' 'DB{i}' 'h{i}' 1521 'usr' 'Pass_{i}_&!' 'B3GRP' 'run_b3' 'all.csv' >/dev/null"
            for i in range(20)
        ]
        script = "\n".join([
            "set -euo pipefail",
            f"oee_dir={shlex.quote(str(oee_dir))}",
            f"output_dir={shlex.quote(str(output_dir))}",
            f"md5_cmd={shlex.quote(MD5_BIN)}",
            f". {shlex.quote(str(DMA_OEE_SH))}",
            '[[ "${_DMA_OEE_USE_ASSOC}" -eq 0 ]]',
            *calls,
            f"cd {shlex.quote(str(oee_dir))}",
            'oee_run "run_b3" >/dev/null',
        ])
        res = _run_bash(script, bash_bin=BASH_3)
        assert res.returncode == 0, res.stderr + res.stdout
        lines = captured.read_text(encoding="utf-8").splitlines()
        assert len(lines) == 20
        for i in range(20):
            assert any(line.endswith(f"DB{i}://h{i}:1521/DB{i}:usr:Pass_{i}_&!") for line in lines)


class TestCrossProcessCredentialsCsv:
    """Verify cross-process batch hydration via ``dma_db_list.csv`` / ``DMA_OEE_CRED_FILE``."""

    @pytest.mark.parametrize(("bash_bin", "_major"), BASH_BINARIES)
    def test_separate_process_hydrates_from_csv_and_handles_quotes(
        self, tmp_path: Path, bash_bin: str, _major: int
    ) -> None:
        oee_dir, output_dir, _ = _make_oee_env(tmp_path)
        captured = tmp_path / "hydrated.txt"
        _make_mock_v5_extractor(oee_dir, extra_body=f'cp -- "${{driver}}" {shlex.quote(str(captured))}')

        # CSV covers plain, single-quoted password with # & special chars, double-quoted with '/', and PDB fallback.
        csv_path = tmp_path / "dma_db_list.csv"
        csv_path.write_text(
            "# Header comment\n"
            "\n"
            "sys/syspass,dma/PlainPass1,@//host1.example.com:1521/ORCL1,AWR,30,id1,Y,CROSS\n"
            "sys/syspass,'wp/wp#foo&1',@//host2.example.com:1522/ORCL2,AWR,30,id2,Y,CROSS\n"
            'sys/syspass,"u3/p@ss/slash",@//host3.example.com:1521/CDB3,AWR,30,id3,Y,CROSS\n',
            encoding="utf-8",
        )
        # Process 1 creates password-less driver files and exits (in-memory maps lost).
        p1 = _run_bash(
            f"""
            set -euo pipefail
            oee_dir={shlex.quote(str(oee_dir))}
            output_dir={shlex.quote(str(output_dir))}
            md5_cmd={shlex.quote(MD5_BIN)}
            . {shlex.quote(str(DMA_OEE_SH))}
            oee_generate_config g1 ORCL1 host1.example.com 1521 dma PlainPass1 CROSS run_xp batch.csv
            oee_generate_config g2 ORCL2 host2.example.com 1522 wp 'wp#foo&1' CROSS run_xp batch.csv
            oee_generate_config g3 PDB3A host3.example.com 1521 u3 'p@ss/slash' CROSS run_xp batch.csv
            """,
            bash_bin=bash_bin,
        )
        assert p1.returncode == 0, p1.stderr
        driver = oee_dir / "mpack_DMA-OEE-CROSS.batch.csv.driverfile.run_xp"
        assert "PlainPass1" not in driver.read_text(encoding="utf-8")
        assert "wp#foo&1" not in driver.read_text(encoding="utf-8")

        # Process 2 runs oee_run in a brand new process passing the CSV path.
        p2 = _run_bash(
            f"""
            set -euo pipefail
            oee_dir={shlex.quote(str(oee_dir))}
            output_dir={shlex.quote(str(output_dir))}
            . {shlex.quote(str(DMA_OEE_SH))}
            cd {shlex.quote(str(oee_dir))}
            oee_run "run_xp" {shlex.quote(str(csv_path))}
            """,
            bash_bin=bash_bin,
        )
        assert p2.returncode == 0, p2.stderr + p2.stdout
        lines = captured.read_text(encoding="utf-8").splitlines()
        assert any(ln.endswith(":ORCL1://host1.example.com:1521/ORCL1:dma:PlainPass1") for ln in lines)
        assert any(ln.endswith(":ORCL2://host2.example.com:1522/ORCL2:wp:wp#foo&1") for ln in lines)
        assert any(ln.endswith(":PDB3A://host3.example.com:1521/PDB3A:u3:p@ss/slash") for ln in lines)
        assert (output_dir / "mpack_DMA-OEE-CROSS.batch.zip").is_file()
        assert list(oee_dir.glob("*driverfile*")) == []

    def test_ambiguous_host_port_user_fails_closed_for_unlisted_pdb(self, tmp_path: Path) -> None:
        oee_dir, output_dir, _ = _make_oee_env(tmp_path)
        _make_mock_v5_extractor(oee_dir)
        csv_path = tmp_path / "dma_db_list.csv"
        csv_path.write_text(
            "sys/s,dma/PassCDB1,@//sharedhost:1521/CDB1,AWR,30,1,Y,GRP\n"
            "sys/s,dma/PassCDB2,@//sharedhost:1521/CDB2,AWR,30,2,Y,GRP\n",
            encoding="utf-8",
        )
        # Exact service match for CDB1 and CDB2 succeeds with distinct passwords.
        captured = tmp_path / "exact.txt"
        _make_mock_v5_extractor(oee_dir, extra_body=f'cp -- "${{driver}}" {shlex.quote(str(captured))}')
        _run_bash(
            f"""
            oee_dir={shlex.quote(str(oee_dir))}
            output_dir={shlex.quote(str(output_dir))}
            md5_cmd={shlex.quote(MD5_BIN)}
            . {shlex.quote(str(DMA_OEE_SH))}
            oee_generate_config g1 CDB1 sharedhost 1521 dma PassCDB1 GRP run_ok exact.csv
            oee_generate_config g2 CDB2 sharedhost 1521 dma PassCDB2 GRP run_ok exact.csv
            """
        )
        ok_res = _run_bash(
            f"""
            oee_dir={shlex.quote(str(oee_dir))}
            output_dir={shlex.quote(str(output_dir))}
            . {shlex.quote(str(DMA_OEE_SH))}
            cd {shlex.quote(str(oee_dir))}
            DMA_OEE_CRED_FILE={shlex.quote(str(csv_path))} oee_run "run_ok"
            """
        )
        assert ok_res.returncode == 0, ok_res.stderr
        text = captured.read_text(encoding="utf-8")
        assert "CDB1:dma:PassCDB1" in text
        assert "CDB2:dma:PassCDB2" in text

        # Unlisted PDB on sharedhost:1521 with SAME username MUST fail closed (not guess PassCDB2).
        _run_bash(
            f"""
            oee_dir={shlex.quote(str(oee_dir))}
            output_dir={shlex.quote(str(output_dir))}
            md5_cmd={shlex.quote(MD5_BIN)}
            . {shlex.quote(str(DMA_OEE_SH))}
            oee_generate_config g3 PDB_MYSTERY sharedhost 1521 dma anypass GRP run_ambig ambig.csv
            """
        )
        fail_res = _run_bash(
            f"""
            oee_dir={shlex.quote(str(oee_dir))}
            output_dir={shlex.quote(str(output_dir))}
            . {shlex.quote(str(DMA_OEE_SH))}
            cd {shlex.quote(str(oee_dir))}
            oee_run "run_ambig" {shlex.quote(str(csv_path))}
            """
        )
        assert fail_res.returncode == 1
        assert "Missing in-memory credential" in fail_res.stderr
        assert "PassCDB1" not in fail_res.stderr
        assert "PassCDB2" not in fail_res.stderr

    def test_missing_credential_fails_closed_without_leaking(self, tmp_path: Path) -> None:
        oee_dir, output_dir, _ = _make_oee_env(tmp_path)
        _make_mock_v5_extractor(oee_dir)
        _run_bash(
            f"""
            oee_dir={shlex.quote(str(oee_dir))}
            output_dir={shlex.quote(str(output_dir))}
            md5_cmd={shlex.quote(MD5_BIN)}
            . {shlex.quote(str(DMA_OEE_SH))}
            oee_generate_config g1 ORCL dbhost 1521 dma_user TopSecret99 GRP run_missing t.csv
            """
        )
        res = _run_bash(
            f"""
            oee_dir={shlex.quote(str(oee_dir))}
            output_dir={shlex.quote(str(output_dir))}
            . {shlex.quote(str(DMA_OEE_SH))}
            cd {shlex.quote(str(oee_dir))}
            oee_run "run_missing"
            """
        )
        assert res.returncode == 1
        assert "Missing in-memory credential" in res.stderr
        assert "<REDACTED>" in res.stderr
        assert "TopSecret99" not in res.stderr + res.stdout
        assert list(oee_dir.glob("*driverfile*")) == []


class TestPasswordValidation:
    """Validate unsupported delimiter/newline handling without leaking secrets."""

    @pytest.mark.parametrize(
        ("bad_password", "expected_msg"),
        [
            ("bad:password:here", "cannot contain ':'"),
            ("line1\nline2", "unsupported newline character"),
            ("line1\rline2", "unsupported newline character"),
        ],
    )
    def test_rejects_delimiter_and_newline_passwords(
        self, tmp_path: Path, bad_password: str, expected_msg: str
    ) -> None:
        oee_dir, output_dir, _ = _make_oee_env(tmp_path)
        _make_mock_v5_extractor(oee_dir)
        res = _run_bash(
            f"""
            oee_dir={shlex.quote(str(oee_dir))}
            output_dir={shlex.quote(str(output_dir))}
            md5_cmd={shlex.quote(MD5_BIN)}
            . {shlex.quote(str(DMA_OEE_SH))}
            oee_generate_config g1 ORCL dbhost 1521 usr {shlex.quote(bad_password)} GRP run_bad tag.csv
            cd {shlex.quote(str(oee_dir))}
            oee_run "run_bad"
            """
        )
        assert res.returncode == 1
        assert expected_msg in res.stderr
        assert bad_password not in res.stderr
        assert bad_password not in res.stdout
        assert list(oee_dir.glob("*driverfile*")) == []


class TestDualExtractorCompatibility:
    """Verify unmodified OEE v5.1 and v6.1.1 detection, packaging, and prereqs."""

    def test_v51_group_with_underscore_packaged_correctly(self, tmp_path: Path) -> None:
        oee_dir, output_dir, _ = _make_oee_env(tmp_path)
        _make_mock_v5_extractor(oee_dir)
        res = _run_bash(
            f"""
            set -euo pipefail
            oee_dir={shlex.quote(str(oee_dir))}
            output_dir={shlex.quote(str(output_dir))}
            md5_cmd={shlex.quote(MD5_BIN)}
            . {shlex.quote(str(DMA_OEE_SH))}
            oee_generate_config g1 ORCL h1 1521 u1 'V5Secret!' MY_GRP run_v5u 190000_4.3.48_h1_ORCL.csv
            cd {shlex.quote(str(oee_dir))}
            oee_run "run_v5u"
            """
        )
        assert res.returncode == 0, res.stderr + res.stdout
        assert (output_dir / "mpack_DMA-OEE-MY_GRP.190000_4.3.48_h1_ORCL.zip").is_file()
        assert not (oee_dir / "run_v5u").exists()
        _assert_no_secret_anywhere(tmp_path, "V5Secret!")

    def test_v611_single_chunk_renamed_and_summary_removed(self, tmp_path: Path) -> None:
        oee_dir, output_dir, _ = _make_oee_env(tmp_path)
        _make_mock_v6_extractor(oee_dir, chunks=1)
        res = _run_bash(
            f"""
            set -euo pipefail
            oee_dir={shlex.quote(str(oee_dir))}
            output_dir={shlex.quote(str(output_dir))}
            md5_cmd={shlex.quote(MD5_BIN)}
            . {shlex.quote(str(DMA_OEE_SH))}
            oee_generate_config g1 ORCL h1 1521 u1 'V6Secr3t!' MY_GRP run_v6s 190000_4.3.48_h1_ORCL.csv
            cd {shlex.quote(str(oee_dir))}
            DMA_OEE_EXTRACT_MODE=-all oee_run "run_v6s"
            """
        )
        assert res.returncode == 0, res.stderr + res.stdout
        assert "(OEE extractor: v6)" in res.stdout
        out_zip = output_dir / "mpack_DMA-OEE-MY_GRP.190000_4.3.48_h1_ORCL.zip"
        assert out_zip.is_file()
        assert not (oee_dir / "run_v6s").exists()
        assert list(oee_dir.glob("*.summary")) == []
        _assert_no_secret_anywhere(tmp_path, "V6Secr3t!")

    def test_v611_multi_chunk_archives_preserved(self, tmp_path: Path) -> None:
        oee_dir, output_dir, _ = _make_oee_env(tmp_path)
        _make_mock_v6_extractor(oee_dir, chunks=3)
        res = _run_bash(
            f"""
            set -euo pipefail
            oee_dir={shlex.quote(str(oee_dir))}
            output_dir={shlex.quote(str(output_dir))}
            md5_cmd={shlex.quote(MD5_BIN)}
            . {shlex.quote(str(DMA_OEE_SH))}
            oee_generate_config g1 ORCL h1 1521 u1 'ChunkPass!9' TEST run_v6m 190000_4.3.48_h1_ORCL.csv
            cd {shlex.quote(str(oee_dir))}
            oee_run "run_v6m"
            """
        )
        assert res.returncode == 0, res.stderr + res.stdout
        for n in ("001", "002", "003"):
            assert (output_dir / f"mpack_DMA-OEE-TEST.190000_4.3.48_h1_ORCL_{n}.zip").is_file()
        assert not (oee_dir / "run_v6m").exists()
        _assert_no_secret_anywhere(tmp_path, "ChunkPass!9")

    def test_v611_warns_on_special_chars_without_echoing_password(self, tmp_path: Path) -> None:
        oee_dir, output_dir, _ = _make_oee_env(tmp_path)
        _make_mock_v6_extractor(oee_dir, chunks=1)
        pw = "p@ss/word 1"
        res = _run_bash(
            f"""
            oee_dir={shlex.quote(str(oee_dir))}
            output_dir={shlex.quote(str(output_dir))}
            md5_cmd={shlex.quote(MD5_BIN)}
            . {shlex.quote(str(DMA_OEE_SH))}
            oee_generate_config g1 ORCL h1 1521 u1 {shlex.quote(pw)} TEST run_warn tag.csv
            cd {shlex.quote(str(oee_dir))}
            oee_run "run_warn"
            """
        )
        assert res.returncode == 0, res.stderr + res.stdout
        assert "WARNING:" in res.stderr
        assert "unmodified OEE v6.1.1" in res.stderr
        assert pw not in res.stderr
        assert pw not in res.stdout

    def test_oee_check_conditions_prereqs_and_redaction(self, tmp_path: Path) -> None:
        oee_dir, _, _ = _make_oee_env(tmp_path)
        sql_dir = tmp_path / "sql"
        sql_dir.mkdir()
        fake_bin = tmp_path / "bin"
        fake_bin.mkdir()
        _write_executable(fake_bin / "zip", f"#!{PRIMARY_BASH}\nexit 0\n")
        _write_executable(fake_bin / "uname", f"#!{PRIMARY_BASH}\necho Linux\n")
        _write_executable(
            fake_bin / "sqlplus",
            f"""#!{PRIMARY_BASH}
cat >/dev/null
if grep -q . <<<""; then :; fi
echo "2103000000"
""",
        )

        # Stub oee_check_sqlplus_release / oee_check_db_version / oee_check_platform via shell override.
        v5_base = f"""
        oee_dir={shlex.quote(str(oee_dir))}
        sql_dir={shlex.quote(str(sql_dir))}
        . {shlex.quote(str(DMA_OEE_SH))}
        oee_check_platform() {{ echo PASS; }}
        oee_check_sqlplus_release() {{ echo PASS; }}
        oee_check_db_version() {{ echo PASS; }}
        """

        # v5.1 without unzip and without dbsecurity SQL -> PASS.
        (oee_dir / "oee_group_extract-SA.sh").write_text("# v5.1\n", encoding="utf-8")
        res_v5 = _run_bash(
            v5_base + 'oee_check_conditions "u/p@ss@//host:1521/svc"',
            env={"PATH": f"{fake_bin}:/usr/bin:/bin"},
        )
        assert res_v5.stdout.strip() == "PASS"

        # v6.1.1 missing oee_group_dbsecurity-SA.sql -> FAIL when Bash >= 4 and unzip present.
        (oee_dir / "oee_group_extract-SA.sh").write_text(
            "# OEE_GROUP_PARALLELISM=4\narchive_prefix=default\n", encoding="utf-8"
        )
        if BASH_4_PLUS is not None:
            # Missing unzip check using isolated fake_bin lacking unzip.
            _write_executable(fake_bin / "grep", '#!/bin/sh\nexec /usr/bin/grep "$@"\n')
            res_no_unzip = _run_bash(
                v5_base + 'oee_check_conditions "u/s3cret@//host:1521/svc"',
                bash_bin=BASH_4_PLUS,
                env={"PATH": str(fake_bin)},
            )
            assert "requires unzip" in res_no_unzip.stdout
            assert "s3cret" not in res_no_unzip.stdout

            # Add unzip, still missing dbsecurity SQL.
            _write_executable(fake_bin / "unzip", f"#!{PRIMARY_BASH}\nexit 0\n")
            res_no_sql = _run_bash(
                v5_base + 'oee_check_conditions "u/s3cret@host@//host:1521/svc"',
                bash_bin=BASH_4_PLUS,
                env={"PATH": str(fake_bin)},
            )
            assert "oee_group_dbsecurity-SA.sql" in res_no_sql.stdout
            assert "//host:1521/svc" in res_no_sql.stdout
            assert "s3cret" not in res_no_sql.stdout

            # Malformed connection string without '@' MUST print <REDACTED>, never the password!
            res_malformed = _run_bash(
                v5_base + 'oee_check_conditions "user/SuperSecretNoAt"',
                bash_bin=BASH_4_PLUS,
                env={"PATH": str(fake_bin)},
            )
            assert "<REDACTED>" in res_malformed.stdout
            assert "SuperSecretNoAt" not in res_malformed.stdout

            # Add dbsecurity SQL -> PASS.
            (oee_dir / "oee_group_dbsecurity-SA.sql").write_text("-- sec\n", encoding="utf-8")
            res_v6_ok = _run_bash(
                v5_base + 'oee_check_conditions "u/s3cret@//host:1521/svc"',
                bash_bin=BASH_4_PLUS,
                env={"PATH": str(fake_bin)},
            )
            assert res_v6_ok.stdout.strip() == "PASS"

        # v6.1.1 on Bash 3.2 -> FAIL with explicit Bash 4 message.
        if BASH_3 is not None:
            res_b3 = _run_bash(
                v5_base + 'oee_check_conditions "u/s3cret@//host:1521/svc"',
                bash_bin=BASH_3,
                env={"PATH": f"{fake_bin}:/usr/bin:/bin"},
            )
            assert "requires Bash 4.0 or higher" in res_b3.stdout
            assert "s3cret" not in res_b3.stdout

    def test_direct_oee_run_standalone_extract_and_oee_package_zips(self, tmp_path: Path) -> None:
        oee_dir, output_dir, _ = _make_oee_env(tmp_path)
        _make_mock_v5_extractor(oee_dir)
        res = _run_bash(
            f"""
            set -euo pipefail
            oee_dir={shlex.quote(str(oee_dir))}
            output_dir={shlex.quote(str(output_dir))}
            md5_cmd={shlex.quote(MD5_BIN)}
            . {shlex.quote(str(DMA_OEE_SH))}
            oee_generate_config g1 ORCL dbhost 1521 usr 'DirectSecr3t!' LEGGRP run_leg tag.csv
            cd {shlex.quote(str(oee_dir))}
            oee_run_standalone_extract "run_leg"
            oee_package_zips "run_leg"
            oee_cleanup_run {shlex.quote(str(oee_dir))} "run_leg"
            """
        )
        assert res.returncode == 0, res.stderr + res.stdout
        assert (output_dir / "mpack_DMA-OEE-LEGGRP.tag.zip").is_file()
        assert not (oee_dir / "mpack_DMA-OEE-LEGGRP.tag.csv.driverfile").exists()
        assert not (oee_dir / "mpack_DMA-OEE-LEGGRP.tag.csv.driverfile.run_leg").exists()
        _assert_no_secret_anywhere(tmp_path, "DirectSecr3t!")

    @pytest.mark.skipif(BASH_4_PLUS is None, reason="Shipped v5.1 script uses printf %(...)T requiring Bash 4+")
    def test_real_unmodified_v51_script_with_mock_sqlplus(self, tmp_path: Path) -> None:
        if shutil.which("zip") is None:
            pytest.skip("zip binary not available")
        assert BASH_4_PLUS is not None

        oee_dir, output_dir, log_dir = _make_oee_env(tmp_path)
        shutil.copy2(SHIPPED_EXTRACT_SH, oee_dir / "oee_group_extract-SA.sh")
        (oee_dir / "oee_group_extract-SA.sh").chmod(0o755)
        (oee_dir / "oee_group_dbextract-SA.sql").write_text("-- stub\n", encoding="utf-8")
        (oee_dir / "oee_group_metrics-SA.sql").write_text("-- stub\n", encoding="utf-8")

        pass_ok = "RealV5Pass#1"
        pass_fail = "RealV5Fail!2"
        seen_log = tmp_path / "sqlplus_args.txt"
        fake_bin = tmp_path / "fakebin"
        fake_bin.mkdir()
        real_wc = shutil.which("wc") or "/usr/bin/wc"
        # Upstream Linux OEE v5.1 compares $(wc -l) to unpadded "1"; BSD wc pads with spaces on stdin.
        _write_executable(
            fake_bin / "wc",
            f"""#!{BASH_4_PLUS}
out=$({shlex.quote(real_wc)} "$@")
printf '%s\\n' "${{out#"${{out%%[![:space:]]*}}"}}"
""",
        )
        _write_executable(
            fake_bin / "sqlplus",
            f"""#!{BASH_4_PLUS}
arg="${{1:-}}"
printf '%s\\n' "${{arg}}" >> {shlex.quote(str(seen_log))}
stdin_data=$(cat)
if [[ "${{arg}}" == *"//failhost:"* ]]; then
  echo "ORA-01017: invalid username/password; logon denied"
  exit 0
fi
if printf '%s' "${{stdin_data}}" | grep -q 'REACHABLE'; then
  echo "REACHABLE"
elif printf '%s' "${{stdin_data}}" | grep -q 'oee_group_dbextract-SA.sql'; then
  echo "MPACK_DATABASE|GUIDPLACEHOLDER|1"
elif printf '%s' "${{stdin_data}}" | grep -q 'oee_group_metrics-SA.sql'; then
  echo "MPACK_DBINFO|GUIDPLACEHOLDER|1"
fi
""",
        )

        # 1) All-success run against the REAL unmodified upstream v5.1 script.
        res_ok = _run_bash(
            f"""
            PATH={shlex.quote(str(fake_bin))}:"$PATH"
            oee_dir={shlex.quote(str(oee_dir))}
            output_dir={shlex.quote(str(output_dir))}
            log_dir={shlex.quote(str(log_dir))}
            md5_cmd={shlex.quote(MD5_BIN)}
            . {shlex.quote(str(DMA_OEE_SH))}
            oee_generate_config g1 ORCL1 okhost1 1521 dma_u1 {shlex.quote(pass_ok)} V5REAL run_real_ok realtag.csv
            cd {shlex.quote(str(oee_dir))}
            oee_run "run_real_ok"
            """,
            bash_bin=BASH_4_PLUS,
        )
        assert res_ok.returncode == 0, res_ok.stderr + res_ok.stdout
        out_zip = output_dir / "mpack_DMA-OEE-V5REAL.realtag.zip"
        assert out_zip.is_file()
        assert f"dma_u1/{pass_ok}@//okhost1:1521/ORCL1" in seen_log.read_text(encoding="utf-8")
        assert not (oee_dir / "run_real_ok").exists()
        assert list(oee_dir.glob("*driverfile*")) == []
        seen_log.unlink()
        _assert_no_secret_anywhere(oee_dir, pass_ok)
        _assert_no_secret_anywhere(log_dir, pass_ok)

        # 2) Partial-failure run: real v5.1 script writes raw driver line into *.failures.
        res_fail = _run_bash(
            f"""
            PATH={shlex.quote(str(fake_bin))}:"$PATH"
            oee_dir={shlex.quote(str(oee_dir))}
            output_dir={shlex.quote(str(output_dir))}
            log_dir={shlex.quote(str(log_dir))}
            md5_cmd={shlex.quote(MD5_BIN)}
            . {shlex.quote(str(DMA_OEE_SH))}
            oee_generate_config g1 ORCL1 okhost1 1521 dma_u1 {shlex.quote(pass_ok)} V5REAL run_real_fail partial.csv
            oee_generate_config g2 ORCL2 failhost 1521 dma_u2 {shlex.quote(pass_fail)} V5REAL run_real_fail partial.csv
            cd {shlex.quote(str(oee_dir))}
            oee_run "run_real_fail"
            """,
            bash_bin=BASH_4_PLUS,
        )
        assert res_fail.returncode == 1
        assert not (oee_dir / "run_real_fail").exists()
        assert list(oee_dir.glob("*driverfile*")) == []
        saved_failures = list(log_dir.glob("oee_run_real_fail_*.failures"))
        assert len(saved_failures) == 1
        assert stat.S_IMODE(saved_failures[0].stat().st_mode) == 0o600
        fail_body = saved_failures[0].read_text(encoding="utf-8")
        assert "dma_u2:<REDACTED>" in fail_body
        assert "ORA-01017" in fail_body
        assert pass_ok not in fail_body
        assert pass_fail not in fail_body
        _assert_no_secret_anywhere(log_dir, pass_ok)
        _assert_no_secret_anywhere(log_dir, pass_fail)
        _assert_no_secret_anywhere(oee_dir, pass_ok)
        _assert_no_secret_anywhere(oee_dir, pass_fail)


class TestRedactedDiagnosticsAndCleanup:
    """Verify Option A diagnostic retention (0600, redacted), isolation, and SIGTERM cleanup."""

    def test_v51_failure_saves_redacted_0600_logs_and_cleans_stage(self, tmp_path: Path) -> None:
        oee_dir, output_dir, log_dir = _make_oee_env(tmp_path)
        secret = "Sp@ce P#ss!99"
        extra = """
        raw_line=$(head -n 1 -- "${driver}")
        printf '%s  | DBExtract Error - ORA-01017: invalid username/password\\n' "${raw_line}" > "${driver}_261124_000000.failures"
        """
        _make_mock_v5_extractor(oee_dir, extra_body=extra)
        res = _run_bash(
            f"""
            oee_dir={shlex.quote(str(oee_dir))}
            output_dir={shlex.quote(str(output_dir))}
            log_dir={shlex.quote(str(log_dir))}
            md5_cmd={shlex.quote(MD5_BIN)}
            . {shlex.quote(str(DMA_OEE_SH))}
            oee_generate_config g1 ORCL dbhost 1521 dma_user {shlex.quote(secret)} GRP run_v5fail tag.csv
            cd {shlex.quote(str(oee_dir))}
            oee_run "run_v5fail"
            """
        )
        # v5.1 masks exit code with tee (0), so non-empty .failures MUST cause oee_run to return 1.
        assert res.returncode == 1
        assert not (oee_dir / "run_v5fail").exists()
        assert list(oee_dir.glob("*driverfile*")) == []

        saved = list(log_dir.glob("oee_run_v5fail_*"))
        assert len(saved) >= 2
        failure_logs = [p for p in saved if p.name.endswith(".failures")]
        assert len(failure_logs) == 1
        assert stat.S_IMODE(failure_logs[0].stat().st_mode) == 0o600
        contents = failure_logs[0].read_text(encoding="utf-8")
        assert "<REDACTED>" in contents
        assert "ORA-01017" in contents
        _assert_no_secret_anywhere(tmp_path, secret)

    def test_v611_failure_redacts_summary_failures_and_logs(self, tmp_path: Path) -> None:
        oee_dir, output_dir, log_dir = _make_oee_env(tmp_path)
        secret = "TopV6Secr3t&42"
        extra = """
        raw_line=$(head -n 1 -- "${driver}")
        pw_field="${raw_line##*:}"
        printf 'FAILED|%s|ORA-12541\\n' "${raw_line}" > "${driver}_${label}_output/run.failures"
        printf 'Running sqlplus -s dma_user/%s@//dbhost:1521/ORCL\\n' "${pw_field}" > "${driver}_extra.log"
        """
        mock_v6 = _make_mock_v6_extractor(oee_dir, chunks=1, extra_body=extra)
        # Append exit 1 at end so archive + summary + failure log are all produced before failing.
        mock_v6.write_text(mock_v6.read_text(encoding="utf-8") + "\nexit 1\n", encoding="utf-8")

        res = _run_bash(
            f"""
            oee_dir={shlex.quote(str(oee_dir))}
            output_dir={shlex.quote(str(output_dir))}
            log_dir={shlex.quote(str(log_dir))}
            md5_cmd={shlex.quote(MD5_BIN)}
            . {shlex.quote(str(DMA_OEE_SH))}
            oee_generate_config g1 ORCL dbhost 1521 dma_user {shlex.quote(secret)} GRP run_v6fail tag.csv
            cd {shlex.quote(str(oee_dir))}
            oee_run "run_v6fail"
            """
        )
        assert res.returncode == 1
        assert not (oee_dir / "run_v6fail").exists()
        assert (output_dir / "mpack_DMA-OEE-GRP.tag.zip").is_file()

        saved = list(log_dir.glob("oee_run_v6fail_*"))
        assert any(p.name.endswith(".summary") for p in saved)
        assert any(p.name.endswith(".failures") for p in saved)
        assert any(p.name.endswith(".log") for p in saved)
        for p in saved:
            assert stat.S_IMODE(p.stat().st_mode) == 0o600
        _assert_no_secret_anywhere(tmp_path, secret)

        # Ensure diagnostic context remained useful after redaction.
        summary_file = next(p for p in saved if p.name.endswith(".summary"))
        assert ":dma_user:<REDACTED>" in summary_file.read_text(encoding="utf-8")
        fail_file = next(p for p in saved if p.name.endswith(".failures"))
        fail_text = fail_file.read_text(encoding="utf-8")
        assert "ORA-12541" in fail_text
        assert "<REDACTED>" in fail_text

    def test_success_does_not_copy_logs_unless_opt_in(self, tmp_path: Path) -> None:
        oee_dir, output_dir, log_dir = _make_oee_env(tmp_path)
        _make_mock_v5_extractor(oee_dir)
        res = _run_bash(
            f"""
            oee_dir={shlex.quote(str(oee_dir))}
            output_dir={shlex.quote(str(output_dir))}
            log_dir={shlex.quote(str(log_dir))}
            md5_cmd={shlex.quote(MD5_BIN)}
            . {shlex.quote(str(DMA_OEE_SH))}
            oee_generate_config g1 ORCL dbhost 1521 u1 'NoLogLeak!' GRP run_ok tag.csv
            cd {shlex.quote(str(oee_dir))}
            oee_run "run_ok"
            """
        )
        assert res.returncode == 0, res.stderr
        assert list(log_dir.iterdir()) == []

        # With DMA_OEE_KEEP_REDACTED_LOGS=Y, redacted 0600 logs ARE saved on success too.
        res2 = _run_bash(
            f"""
            oee_dir={shlex.quote(str(oee_dir))}
            output_dir={shlex.quote(str(output_dir))}
            log_dir={shlex.quote(str(log_dir))}
            md5_cmd={shlex.quote(MD5_BIN)}
            . {shlex.quote(str(DMA_OEE_SH))}
            oee_generate_config g1 ORCL dbhost 1521 u1 'NoLogLeak!' GRP run_opt tag.csv
            cd {shlex.quote(str(oee_dir))}
            DMA_OEE_KEEP_REDACTED_LOGS=Y oee_run "run_opt"
            """
        )
        assert res2.returncode == 0, res2.stderr
        kept = list(log_dir.glob("oee_run_opt_*"))
        assert len(kept) >= 1
        assert all(stat.S_IMODE(p.stat().st_mode) == 0o600 for p in kept)

    def test_parallel_run_cleanup_isolation(self, tmp_path: Path) -> None:
        oee_dir, output_dir, _ = _make_oee_env(tmp_path)
        captured_b = tmp_path / "captured_b.txt"
        _make_mock_v5_extractor(oee_dir, extra_body=f'cp -- "${{driver}}" {shlex.quote(str(captured_b))}')
        res = _run_bash(
            f"""
            set -euo pipefail
            oee_dir={shlex.quote(str(oee_dir))}
            output_dir={shlex.quote(str(output_dir))}
            md5_cmd={shlex.quote(MD5_BIN)}
            . {shlex.quote(str(DMA_OEE_SH))}
            oee_generate_config ga DBA h1 1521 ua SecretA GRP run_A tagA.csv
            oee_generate_config gb DBB h2 1521 ub SecretB GRP run_B tagB.csv
            oee_cleanup_run {shlex.quote(str(oee_dir))} "run_A"
            [[ ! -e {shlex.quote(str(oee_dir))}/mpack_DMA-OEE-GRP.tagA.csv.driverfile.run_A ]]
            [[ -f {shlex.quote(str(oee_dir))}/mpack_DMA-OEE-GRP.tagB.csv.driverfile.run_B ]]
            cd {shlex.quote(str(oee_dir))}
            oee_run "run_B"
            """
        )
        assert res.returncode == 0, res.stderr + res.stdout
        assert captured_b.read_text(encoding="utf-8").strip().endswith(":ub:SecretB")

    def test_sigterm_interrupt_cleans_up_hydrated_driver_and_stage_dir(self, tmp_path: Path) -> None:
        oee_dir, output_dir, _ = _make_oee_env(tmp_path)
        ready_file = tmp_path / "ready.flag"
        _make_mock_v5_extractor(
            oee_dir,
            extra_body=f"""
            touch {shlex.quote(str(ready_file))}
            sleep 30
            """,
        )
        script = f"""
        oee_dir={shlex.quote(str(oee_dir))}
        output_dir={shlex.quote(str(output_dir))}
        md5_cmd={shlex.quote(MD5_BIN)}
        . {shlex.quote(str(DMA_OEE_SH))}
        oee_generate_config g1 ORCL dbhost 1521 u1 'SigTermSecret!' GRP run_sig tag.csv
        cd {shlex.quote(str(oee_dir))}
        oee_run "run_sig"
        """
        proc = subprocess.Popen(
            [PRIMARY_BASH, "-c", script],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        try:
            deadline = time.monotonic() + 10.0
            while not ready_file.exists() and time.monotonic() < deadline:
                time.sleep(0.05)
            assert ready_file.exists(), "Mock extractor did not start in time"
            # Confirm transient hydrated driver existed right before SIGTERM.
            assert (oee_dir / "run_sig").is_dir()
            proc.send_signal(signal.SIGTERM)
            proc.wait(timeout=10)
        finally:
            if proc.poll() is None:
                proc.kill()
                proc.wait(timeout=5)

        assert not (oee_dir / "run_sig").exists()
        assert list(oee_dir.glob("*driverfile*")) == []
        _assert_no_secret_anywhere(oee_dir, "SigTermSecret!")

    def test_secure_remove_fallback_without_shred(self, tmp_path: Path) -> None:
        target = tmp_path / "secret.driver"
        target.write_text("top_secret_payload_12345\n" * 20, encoding="utf-8")
        target.chmod(0o400)
        # Provide PATH without shred to force dd zero-overwrite + rm fallback.
        no_shred_bin = tmp_path / "nobin"
        no_shred_bin.mkdir()
        for tool in ("chmod", "wc", "tr", "dd", "rm"):
            found = shutil.which(tool)
            assert found is not None
            (no_shred_bin / tool).symlink_to(found)
        res = _run_bash(
            f"""
            . {shlex.quote(str(DMA_OEE_SH))}
            _oee_secure_remove {shlex.quote(str(target))}
            """,
            env={"PATH": str(no_shred_bin)},
        )
        assert res.returncode == 0, res.stderr
        assert not target.exists()


class TestCollectDataSh:
    """Verify collect-data.sh password redaction, safe parsing, and multi-chunk packaging."""

    @pytest.mark.parametrize(
        ("raw_conn", "expected", "secret"),
        [
            ("scott/tiger@//dbhost:1521/orcl", "scott/<REDACTED>@//dbhost:1521/orcl", "tiger"),
            ("'wp/wp#foo&1'@//10.0.0.1:1521/prod", "'wp/<REDACTED>'@//10.0.0.1:1521/prod", "wp#foo&1"),
            (
                "'scott/MySecr3t!@//dbhost:1521/orcl'",
                "'scott/<REDACTED>@//dbhost:1521/orcl'",
                "MySecr3t!",
            ),
            ("dma/p@ss/w*rd#1@//dbhost:1521/orcl", "dma/<REDACTED>@//dbhost:1521/orcl", "p@ss/w*rd#1"),
            ('dma/"p@ss/w*rd"@//dbhost:1521/orcl', "dma/<REDACTED>@//dbhost:1521/orcl", "p@ss/w*rd"),
            ("scott/Secr3t@tnsalias", "scott/<REDACTED>@tnsalias", "Secr3t"),
            ("scott/OnlyNoAtSecret", "scott/<REDACTED>", "OnlyNoAtSecret"),
            ("RawSecretToken", "<REDACTED>", "RawSecretToken"),
            ("", "<REDACTED>", "unused"),
        ],
    )
    def test_redact_connection_string(self, raw_conn: str, expected: str, secret: str) -> None:
        res = _run_bash(
            f"""
            . {shlex.quote(str(COLLECT_DATA_SH))}
            redact_connection_string {shlex.quote(raw_conn)}
            """
        )
        assert res.returncode == 0, res.stderr
        assert res.stdout.strip() == expected
        if secret != "unused":
            assert secret not in res.stdout

    def test_parse_parameters_odd_count_never_prints_password(self) -> None:
        secret_pass = "TOPSECRET_PASS_8899"
        res_pass = _run_bash(
            f"""
            . {shlex.quote(str(COLLECT_DATA_SH))}
            parse_parameters --collectionUserName dma --collectionUserPass {shlex.quote(secret_pass)} --statsSrc
            """
        )
        assert "Invalid number of parameters : 5" in res_pass.stdout
        assert secret_pass not in res_pass.stdout
        assert secret_pass not in res_pass.stderr

        conn_secret = "CONNSTR_SECRET_7766"
        res_conn = _run_bash(
            f"""
            . {shlex.quote(str(COLLECT_DATA_SH))}
            parse_parameters --connectionStr {shlex.quote(f"dma/{conn_secret}@//host:1521/svc")} --statsSrc
            """
        )
        assert "Invalid number of parameters : 3" in res_conn.stdout
        assert conn_secret not in res_conn.stdout
        assert conn_secret not in res_conn.stderr

    @pytest.mark.parametrize(
        ("conn_str", "exp_user", "exp_pass", "exp_host", "exp_port", "exp_svc"),
        [
            ("dma/simple@//db1.local:1521/orcl", "dma", "simple", "db1.local", "1521", "orcl"),
            ("'wp/wp#foo&1'@//192.168.1.5:1522/pdb1", "wp", "wp#foo&1", "192.168.1.5", "1522", "pdb1"),
            ("u1/p@ss/w*rd@//dbhost:1521/my.svc.local", "u1", "p@ss/w*rd", "dbhost", "1521", "my.svc.local"),
            ('u2/"q@pass/1"@//dbhost:1523/svc2', "u2", "q@pass/1", "dbhost", "1523", "svc2"),
        ],
    )
    def test_parse_parameters_connection_str_special_chars(
        self,
        tmp_path: Path,
        conn_str: str,
        exp_user: str,
        exp_pass: str,
        exp_host: str,
        exp_port: str,
        exp_svc: str,
    ) -> None:
        # Place dummy file inside cwd so unquoted '*' globbing would fail immediately if regressed.
        (tmp_path / "glob_sentinel.txt").write_text("x", encoding="utf-8")
        res = _run_bash(
            f"""
            . {shlex.quote(str(COLLECT_DATA_SH))}
            sed_cmd=sed
            parse_parameters --connectionStr {shlex.quote(conn_str)} --statsSrc NONE --collectOEE N
            printf '%s\\n%s\\n%s\\n%s\\n%s\\n' \
              "${{collection_user_name}}" "${{collection_user_pass}}" \
              "${{host_name}}" "${{port}}" "${{database_service}}"
            """,
            cwd=tmp_path,
        )
        assert res.returncode == 0, res.stderr
        tail = res.stdout.splitlines()[-5:]
        assert tail == [exp_user, exp_pass, exp_host, exp_port, exp_svc]

    def test_check_db_connection_redacts_password_on_failure(self) -> None:
        secret = "Sup3rS3cret#Fail!"
        res = _run_bash(
            f"""
            . {shlex.quote(str(COLLECT_DATA_SH))}
            grep_cmd=grep
            connection_string={shlex.quote(f"dma_user/{secret}@//dbhost.local:1521/orcl")}
            collection_user_pass={shlex.quote(secret)}
            check_version() {{
              echo "ERROR: ORA-01017: invalid username/password; logon denied ($1)"
            }}
            check_db_connection
            """
        )
        assert res.returncode == 255
        assert (
            "Unable to connect to the target database using dma_user/<REDACTED>@//dbhost.local:1521/orcl." in res.stdout
        )
        assert secret not in res.stdout
        assert secret not in res.stderr

    def test_compress_dma_files_includes_single_and_multichunk_oee_zips(self, tmp_path: Path) -> None:
        if shutil.which("zip") is None:
            pytest.skip("zip binary not available")
        output_dir = tmp_path / "output"
        log_dir = tmp_path / "log"
        output_dir.mkdir()
        log_dir.mkdir()

        tag = "190000_4.3.48_host_ORCL_ORCL_112426090000"
        (log_dir / f"opdb__{tag}_errors.log").write_text("", encoding="utf-8")
        (output_dir / f"opdb__eoj__{tag}.csv").write_text("ok\n", encoding="utf-8")
        (output_dir / f"opdb__defines__{tag}.csv").write_text("v_dma_source_id = 123\n", encoding="utf-8")
        chunk1 = f"mpack_DMA-OEE-TEST.{tag}_001.zip"
        chunk2 = f"mpack_DMA-OEE-TEST.{tag}_002.zip"
        _create_empty_zip(output_dir / chunk1, "db1.txt", "c1")
        _create_empty_zip(output_dir / chunk2, "db2.txt", "c2")

        res = _run_bash(
            f"""
            . {shlex.quote(str(COLLECT_DATA_SH))}
            output_dir={shlex.quote(str(output_dir))}
            log_dir={shlex.quote(str(log_dir))}
            zip_cmd={shlex.quote(shutil.which("zip") or "zip")}
            md5_cmd={shlex.quote(MD5_BIN)}
            md5_col=1
            diag_pack_access=UseDiagnostics
            dbmajor=19
            compress_dma_files {shlex.quote(tag)} oracle {shlex.quote(chunk1)} {shlex.quote(chunk2)}
            """,
            cwd=tmp_path,
        )
        assert res.returncode == 0, res.stderr + res.stdout
        archive = output_dir / f"opdb_oracle_UseDiagnostics__{tag}.zip"
        assert archive.is_file()
        assert not (output_dir / chunk1).exists()
        assert not (output_dir / chunk2).exists()
        with zipfile.ZipFile(archive) as zf:
            names = set(zf.namelist())
            assert chunk1 in names
            assert chunk2 in names
            manifest = zf.read(f"opdb__manifest__{tag}.txt").decode("utf-8")
            assert chunk1 in manifest
            assert chunk2 in manifest

    @pytest.mark.parametrize("mode", ["v5", "v6_multi"])
    def test_end_to_end_collect_data_with_mock_oee(self, tmp_path: Path, mode: str) -> None:
        if shutil.which("zip") is None:
            pytest.skip("zip binary not available")

        work = tmp_path / "oracle_copy"
        work.mkdir()
        shutil.copy2(COLLECT_DATA_SH, work / "collect-data.sh")
        shutil.copy2(DMA_OEE_SH, work / "dma_oee.sh")
        shutil.copy2(DMA_PRINT_SH, work / "dma_print_pass_fail.sh")
        (work / "collect-data.sh").chmod(0o755)
        (work / "sql").mkdir()
        oee_dir = work / "oee"
        oee_dir.mkdir()
        if mode == "v5":
            _make_mock_v5_extractor(oee_dir)
        else:
            _make_mock_v6_extractor(oee_dir, chunks=2)

        tagbase = "190000_4.3.48_mockhost_ORCL_ORCL_112426093000"
        secret = "E2eP@ss#99&!"
        fake_bin = tmp_path / "fakebin"
        fake_bin.mkdir()
        _write_executable(
            fake_bin / "sqlplus",
            f"""#!{PRIMARY_BASH}
input=$(cat)
if printf '%s' "${{input}}" | grep -q '_SQLPLUS_RELEASE'; then
  echo "2103000000"
elif printf '%s' "${{input}}" | grep -q 'DMAFILETAG'; then
  echo "DMAFILETAG~19.3.0.0.0|{tagbase}~"
elif printf '%s' "${{input}}" | grep -q 'CONNECTED|'; then
  echo "CONNECTED|19|3"
else
  printf 'v_dma_source_id = e2e-source-guid\\n' > "${{output_dir}}/opdb__defines__${{v_tag}}"
  printf 'eoj\\n' > "${{output_dir}}/opdb__eoj__${{v_tag}}"
fi
""",
        )

        # Invoke main() inside a subshell where oee_check_platform is stubbed to PASS (macOS-portable).
        res = _run_bash(
            f"""
            PATH={shlex.quote(str(fake_bin))}:"$PATH"
            cd {shlex.quote(str(work))}
            . ./collect-data.sh
            oee_check_platform() {{ echo "PASS"; }}
            main --connectionStr {shlex.quote(f"dma_user/{secret}@//mockhost:1521/ORCL")} \
                 --statsSrc NONE --collectOEE Y --oeeGroup E2EGRP --oeeRunId run_e2e_{mode}
            """,
            bash_bin=PRIMARY_BASH,
        )
        assert res.returncode == 0, res.stderr + res.stdout
        assert secret not in res.stdout
        assert secret not in res.stderr

        # Staging directory and driver files must all be removed after run.
        assert not (oee_dir / f"run_e2e_{mode}").exists()
        assert list(oee_dir.glob("*driverfile*")) == []
        _assert_no_secret_anywhere(work, secret)

        outer_zip = work / "output" / f"opdb_oracle_nostatspack__{tagbase}.zip"
        assert outer_zip.is_file()
        with zipfile.ZipFile(outer_zip) as zf:
            members = set(zf.namelist())
            if mode == "v5":
                assert f"mpack_DMA-OEE-E2EGRP.{tagbase}.zip" in members
            else:
                assert f"mpack_DMA-OEE-E2EGRP.{tagbase}_001.zip" in members
                assert f"mpack_DMA-OEE-E2EGRP.{tagbase}_002.zip" in members
