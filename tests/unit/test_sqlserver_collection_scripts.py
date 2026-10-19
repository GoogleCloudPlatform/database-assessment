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
"""Unit tests for packaged SQL Server collection scripts and additive deep telemetry."""

from __future__ import annotations

import re
import zipfile
from pathlib import Path
from typing import TYPE_CHECKING

import pytest

if TYPE_CHECKING:
    from tests.lib.collector_build import CollectorArtifacts


REPO_ROOT = Path(__file__).resolve().parents[2]
SQLSERVER_DIR = REPO_ROOT / "scripts" / "collector" / "sqlserver"
SQL_DIR = SQLSERVER_DIR / "sql"
INSTANCE_REVIEW_PATH = SQLSERVER_DIR / "instanceReview.ps1"

ORIGINAL_SQL_FILES: tuple[str, ...] = (
    "addCollectionUserToDatabase.sql",
    "checkValidDatabase.sql",
    "checkValidInstanceVersion.sql",
    "columnDatatypes.sql",
    "componentsInstalled.sql",
    "createCollectionUser.sql",
    "dbClusterNodes.sql",
    "dbServerConfigurationSettings.sql",
    "dbServerDmvPerfmon.sql",
    "dbServerFeatures.sql",
    "dbServerFeaturesDatabaseLevel.sql",
    "dbServerTranLogBackupCountByDayByHour.sql",
    "dbServerTranLogBackupSizeByDayByHour.sql",
    "dbServerUnsupportedFlags.sql",
    "dbSizes.sql",
    "dbccTraceFlags.sql",
    "diskVolumeInfo.sql",
    "foldername.sql",
    "getDBList.sql",
    "getDmaSourceId.sql",
    "indexList.sql",
    "linkedServersDetail.sql",
    "objectList.sql",
    "serverProperties.sql",
    "tableList.sql",
    "userConnectionInfo.sql",
)

NEW_DEEP_SQL_SPECS: dict[str, tuple[str, str]] = {
    "azureDbResourceStats.sql": (
        "AzureDbResourceStats",
        '"PKEY"|"end_time"|"avg_cpu_percent"|"avg_data_io_percent"|"avg_log_write_percent"|"max_worker_percent"|"max_session_percent"|"current_limit"|"current_storage_usage_db"|"dma_source_id"|"dma_manual_id"',
    ),
    "azureElasticPoolStats.sql": (
        "AzureElasticPoolStats",
        '"PKEY"|"end_time"|"elastic_pool_name"|"avg_cpu_percent"|"avg_data_io_percent"|"avg_log_write_percent"|"max_worker_percent"|"elastic_pool_dtu_limit"|"dma_source_id"|"dma_manual_id"',
    ),
    "azureResourceGovernance.sql": (
        "AzureResourceGovernance",
        '"PKEY"|"database_id"|"logical_cpu_count"|"process_memory_limit_mb"|"max_global_index_size_mb"|"user_data_cap_gb"|"user_data_iops_cap"|"log_write_cap_mb_sec"|"dma_source_id"|"dma_manual_id"',
    ),
    "azureResourceStats.sql": (
        "AzureResourceStats",
        '"PKEY"|"start_time"|"end_time"|"database_name"|"sku"|"avg_cpu_percent"|"avg_data_io_percent"|"avg_log_write_percent"|"max_worker_percent"|"max_session_percent"|"dtu_limit"|"dma_source_id"|"dma_manual_id"',
    ),
    "batchFootprint.sql": (
        "BatchFootprint",
        '"PKEY"|"AvgRunTimeMS"|"StatementCount"|"counter_name"|"TotalElapsedTimeMS"|"ExecutionTimePercent"|"ExecutionCountPercent"|"dma_source_id"|"dma_manual_id"',
    ),
    "cpuUsage.sql": (
        "CpuUsage",
        '"PKEY"|"timestamp"|"process_utilization"|"system_idle"|"dma_source_id"|"dma_manual_id"',
    ),
    "deprecatedFeatures.sql": (
        "DeprecatedFeatures",
        '"PKEY"|"FeatureName"|"UsageCount"|"dma_source_id"|"dma_manual_id"',
    ),
    "fileIoLatency.sql": (
        "FileIoLatency",
        '"PKEY"|"DatabaseName"|"LogicalFileName"|"FileType"|"PhysicalPath"|"TotalReads"|"DataReadMB"|"TotalReadStallMs"|"AvgReadLatencyMs"|"TotalWrites"|"DataWrittenMB"|"TotalWriteStallMs"|"AvgWriteLatencyMs"|"TotalIOStallMs"|"SizeOnDiskMB"|"dma_source_id"|"dma_manual_id"',
    ),
    "instanceErrorLog.sql": (
        "InstanceErrorLog",
        '"PKEY"|"timestamp"|"process_info"|"log_message"|"dma_source_id"|"dma_manual_id"',
    ),
    "machineSpecsTsql.sql": (
        "DbMachineSpecs",
        '"pkey"|"dma_source_id"|"dma_manual_id"|"MachineName"|"PhysicalCpuCount"|"LogicalCpuCount"|"TotalOSMemoryMB"',
    ),
    "memoryClerks.sql": (
        "MemoryClerks",
        '"PKEY"|"memory_clerk_type"|"allocated_mb"|"pct_of_total_sql_memory"|"dma_source_id"|"dma_manual_id"',
    ),
    "memorySizing.sql": (
        "MemorySizing",
        '"PKEY"|"host_ram_mb"|"available_host_ram_mb"|"max_server_memory_mb"|"min_server_memory_mb"|"sql_working_set_mb"|"memory_model"|"user_data_on_disk_mb"|"buffer_pool_user_data_mb"|"lifetime_pressure_events"|"internal_sql_pressure_events"|"external_os_pressure_events"|"dma_source_id"|"dma_manual_id"',
    ),
    "memoryUsage.sql": (
        "MemoryUsage",
        '"PKEY"|"timestamp"|"state"|"available_physical_memory_mb"|"working_set_mb"|"percent_committed_in_ws"|"system_physical_memory_high"|"system_physical_memory_low"|"process_physical_memory_low"|"process_virtual_memory_low"|"dma_source_id"|"dma_manual_id"',
    ),
    "queryOptimizerInfo.sql": (
        "QueryOptimizerInfo",
        '"PKEY"|"counter"|"value"|"occurrence"|"dma_source_id"|"dma_manual_id"',
    ),
    "sqlAgentJobs.sql": (
        "SqlAgentJobs",
        '"pkey"|"dma_source_id"|"dma_manual_id"|"job_id"|"job_name"|"job_enabled"|"category_name"|"job_description"|"step_id"|"step_name"|"subsystem"|"command"|"database_name"|"incompatibility_category"|"incompatibility_type"|"severity"',
    ),
    "tsqlPostgresDeepScanner.sql": (
        "PostgresMigrationIssues",
        '"PKEY"|"database_name"|"schema_name"|"object_name"|"object_type"|"incompatibility_type"|"severity"|"violation_count"|"dma_source_id"|"dma_manual_id"',
    ),
    "waitsStats.sql": (
        "WaitsStats",
        '"PKEY"|"WaitType"|"Wait_S"|"Resource_S"|"Signal_S"|"WaitCount"|"Percentage"|"AvgWait_S"|"AvgRes_S"|"AvgSig_S"|"dma_source_id"|"dma_manual_id"',
    ),
}

ORIGINAL_OPDB_FILE_KEYS: tuple[str, ...] = (
    "CompInstalled",
    "ServerProps",
    "BlockFeatures",
    "LinkedSrvrs",
    "DbSizes",
    "DbClusterNodes",
    "ObjectList",
    "TableList",
    "IndexList",
    "ColumnDatatypes",
    "UserConnections",
    "PerfMonData",
    "DbccTrace",
    "DiskVolInfo",
    "DbServerFlags",
    "DbServerConfig",
    "DmvPerfmon",
    "manifest",
    "DbMachineSpecs",
    "TranLogBkupCountByHourByDay",
    "TranLogBkupSizeByHourByDay",
    "DatabaseLevelBlockFeatures",
)


def _read_project_version() -> str:
    content = (REPO_ROOT / "pyproject.toml").read_text(encoding="utf-8")
    match = re.search(r'^version\s*=\s*"([^"]+)"', content, re.MULTILINE)
    assert match is not None, "Could not parse version from pyproject.toml"
    return match.group(1)


def _read_sql_file(filename: str) -> str:
    return (SQL_DIR / filename).read_text(encoding="utf-8")


@pytest.fixture(scope="module")
def instance_review_content() -> str:
    return INSTANCE_REVIEW_PATH.read_text(encoding="utf-8")


def test_original_sql_files_preserved() -> None:
    for filename in ORIGINAL_SQL_FILES:
        file_path = SQL_DIR / filename
        assert file_path.is_file(), f"Original SQL script missing: {filename}"


def test_original_opdb_file_keys_preserved_in_instance_review(instance_review_content: str) -> None:
    for file_key in ORIGINAL_OPDB_FILE_KEYS:
        expected_pattern = f"'opdb' + '__' + '{file_key}' + $outputFileSuffix"
        assert expected_pattern in instance_review_content, (
            f"Original opdb file key missing or altered in instanceReview.ps1: {file_key}"
        )


@pytest.mark.parametrize(("sql_filename", "spec"), list(NEW_DEEP_SQL_SPECS.items()))
def test_new_deep_sql_files_and_instance_review_wiring(
    sql_filename: str,
    spec: tuple[str, str],
    instance_review_content: str,
) -> None:
    opdb_key, expected_header = spec
    sql_path = SQL_DIR / sql_filename
    assert sql_path.is_file(), f"Missing deep collector SQL script: {sql_filename}"

    sql_content = _read_sql_file(sql_filename)
    assert "$(pkey)" in sql_content
    assert "$(dmaSourceId)" in sql_content
    assert "$(dmaManualId)" in sql_content
    if sql_filename == "tsqlPostgresDeepScanner.sql":
        assert "DB_NAME()" in sql_content

    expected_file_def = f"'opdb' + '__' + '{opdb_key}' + $outputFileSuffix"
    assert expected_file_def in instance_review_content
    assert expected_header in instance_review_content
    assert f"sql\\{sql_filename}" in instance_review_content


def test_sqlserver_collector_zip_contains_all_sql_scripts(
    collector_artifacts: CollectorArtifacts,
) -> None:
    assert collector_artifacts.sqlserver_zip.is_file()
    assert collector_artifacts.oracle_zip.is_file()
    assert (collector_artifacts.dist_dir / "dma-collection-masker").is_file()

    with zipfile.ZipFile(collector_artifacts.sqlserver_zip) as zf:
        archive_names = set(zf.namelist())

    for filename in ORIGINAL_SQL_FILES:
        assert f"sql/{filename}" in archive_names

    for filename in NEW_DEEP_SQL_SPECS:
        assert f"sql/{filename}" in archive_names

    assert "masker/dma-collection-masker" in archive_names

    with zipfile.ZipFile(collector_artifacts.oracle_zip) as oracle_zf:
        oracle_names = set(oracle_zf.namelist())
    assert "masker/dma-collection-masker" in oracle_names


def test_sql_safety_and_sanitization_guards(instance_review_content: str) -> None:
    error_log_sql = _read_sql_file("instanceErrorLog.sql")
    assert "BEGIN TRY" in error_log_sql
    assert "BEGIN CATCH" in error_log_sql
    assert "Login failed" in error_log_sql
    assert "password" in error_log_sql
    assert "SSPI handshake failed" in error_log_sql

    memory_sizing_sql = _read_sql_file("memorySizing.sql")
    assert "SET QUOTED_IDENTIFIER ON" in memory_sizing_sql
    assert "CAST(r.record AS XML)" in memory_sizing_sql
    assert "locked_page_allocations_kb" in memory_sizing_sql
    assert "process_memory_model_desc" not in memory_sizing_sql

    for filename in ("waitsStats.sql", "batchFootprint.sql", "memoryClerks.sql"):
        content = _read_sql_file(filename)
        assert "NULLIF(" in content

    agent_jobs_sql = _read_sql_file("sqlAgentJobs.sql")
    assert "$(ESCAPE_" not in agent_jobs_sql
    assert "$(JOBNAME)" not in agent_jobs_sql
    assert "'%$' + '(%'" in agent_jobs_sql

    assert "if (-not $useEntraIDAuthentication)" in instance_review_content
    assert "$entraIDUserName" in instance_review_content
    assert "$entraUpn" not in instance_review_content


def test_copyright_headers_and_no_individual_author_lines(instance_review_content: str) -> None:
    assert "Author: Tim Chapman" not in instance_review_content
    assert "Copyright 2024 Google LLC" in instance_review_content

    for filename in NEW_DEEP_SQL_SPECS:
        content = _read_sql_file(filename)
        assert "Author: Tim Chapman" not in content, f"Individual author header found in {filename}"
        assert "Google LLC" in content, f"Missing copyright header in {filename}"


def test_instance_review_csv_headers_match_downstream_column_counts(instance_review_content: str) -> None:
    expected_var_col_counts = {
        "compFileName": 8,
        "srvFileName": 5,
        "dbServerFlags": 7,
        "blockingFeatures": 6,
        "linkedServers": 10,
        "dbClusterNodes": 6,
        "dbccTraceFlg": 7,
        "cpuUsageFileName": 6,
        "memoryUsageFileName": 12,
        "memorySizingFileName": 14,
        "memoryClerksFileName": 6,
        "batchFootprintFileName": 9,
        "waitsStats": 12,
        "queryOptimizerInfo": 6,
        "fileIoLatency": 17,
        "instanceErrorLog": 6,
        "deprecatedFeatures": 5,
        "diskVolumeInfo": 10,
        "dbServerConfig": 10,
        "tranLogBkupCountByDayByHour": 31,
        "tranLogBkupSizeByDayByHour": 31,
        "sqlAgentJobs": 16,
        "userConnectionList": 24,
        "dbsizes": 7,
        "dbServerDmvPerfmon": 27,
        "objectList": 11,
        "tableList": 21,
        "indexList": 22,
        "columnDatatypes": 17,
        "databaseLevelBlockingFeatures": 7,
        "deepScanner": 10,
        "azureDbRes": 11,
        "azureRes": 13,
        "azureGov": 10,
        "azurePool": 10,
        "computerSpecsFile": 7,
    }
    pattern = re.compile(r"Set-Content\s+-Path\s+\$foldername\\\$(\w+)\s+-Encoding\s+utf8\s+-Value\s+'([^']+)'")
    found_headers = dict(pattern.findall(instance_review_content))
    for var_name, expected_cols in expected_var_col_counts.items():
        assert var_name in found_headers, f"Missing Set-Content header for ${var_name}"
        actual_cols = len(found_headers[var_name].split("|"))
        assert actual_cols == expected_cols, (
            f"Column count mismatch for ${var_name}: expected {expected_cols}, got {actual_cols}"
        )


def test_no_unescaped_sqlcmd_variables_in_sql_scripts() -> None:
    allowed_vars = {
        "$(pkey)",
        "$(dmaSourceId)",
        "$(dmaManualId)",
        "$(database)",
        "$(hasdbaccess)",
        "$(cloudtype)",
        "$(collectionUser)",
        "$(collectionPass)",
    }
    for sql_path in sorted(SQL_DIR.glob("*.sql")):
        content = sql_path.read_text(encoding="utf-8")
        for idx, line in enumerate(content.splitlines(), 1):
            for match in re.finditer(r"\$\([^)]*\)|\$\([^\s']*'", line):
                token = match.group(0)
                assert token in allowed_vars, f"Unescaped sqlcmd variable pattern {token} in {sql_path.name}:{idx}"


def test_db_server_features_cloud_sql_blockers_and_false_positive_guards() -> None:
    content = _read_sql_file("dbServerFeatures.sql")
    for feature_name in (
        "Performance Data Collector",
        "ContainedAGCount",
        "IntegratedAccelerationEnabled",
        "AzureSQLMILinkActive",
        "AzureDevOpsServerHost",
        "ExternalLanguagesRegistered",
        "BackupsToAzureBlobStorage",
        "BackupsToObjectStorage",
        "IsTDS80Used",
        "in-memory-oltp",
        "IsDACEnabled",
        "IsDTCInUse",
        "IsPMEMEnabled",
        "IsHybridBufferPoolDirectWriteEnabled",
        "IsMultiWriteReplicationUsed",
        "UserCertificatesUsed",
        "RESTORE",
        "ADMINISTER DATABASE BULK OPERATIONS",
    ):
        assert feature_name in content, f"Missing feature check {feature_name} in dbServerFeatures.sql"
    assert "WHERE ISNULL(mode, 0) > 0 OR ISNULL(config_in_use, 0) > 0" in content
    assert "WHERE el.principal_id <> 4 OR elf.content IS NOT NULL" in content
    assert "INNER JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id" in content
    assert "transaction_type = 4 OR ISNULL(dtc_state, 0) > 0" in content
    assert "OBJECT_ID('sys.server_memory_optimized_hybrid_buffer_pool_configuration') IS NOT NULL" in content

    db_content = _read_sql_file("dbServerFeaturesDatabaseLevel.sql")
    for db_feature in (
        "RealTimeOperationalAnalyticsUsed",
        "UserCertificatesUsed",
        "RESTORE",
        "ADMINISTER DATABASE BULK OPERATIONS",
    ):
        assert db_feature in db_content, f"Missing DB feature check {db_feature} in dbServerFeaturesDatabaseLevel.sql"
    assert "INNER JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id" in db_content


def test_collector_logging_and_telemetry_coverage(instance_review_content: str) -> None:
    expected_version = _read_project_version()
    assert f'$op_version = "{expected_version}"' in instance_review_content
    assert "Update-DmaManifest" not in instance_review_content
    assert "dma_manifest.json" not in instance_review_content
    assert len(re.findall(r"^\s*function\s+sqlcmd\b", instance_review_content, flags=re.MULTILINE)) == 1
    assert "-Exclude $logFile, $sqlErrorLogFile" in instance_review_content
    assert "COLLECTION_SUMMARY.txt" in instance_review_content
    assert "CRASH_REPORT.txt" in instance_review_content
    assert "$trappedError.InvocationInfo -and $trappedError.InvocationInfo.Line" in instance_review_content
    assert '"database=tempdb"' in instance_review_content
    assert "$outputFileArray += @($azureDbRes, $azureRes, $azureGov, $azurePool)" in instance_review_content

    for token in (
        "dma_collector_bootstrap.log",
        "function Write-DmaBootstrapLog",
        "function Invoke-DmaSqlStep",
        "function Invoke-DmaPermissionAudit",
        "function Resolve-DmaSqlOdbcDriverName",
        "[STEP-START]",
        "[STEP-DONE]",
        "[STEP-ERROR]",
        "[PERM-AUDIT]",
        "[PERM-WARN]",
        "STEP EXECUTION TELEMETRY",
        "CSV OUTPUT MANIFEST",
    ):
        assert token in instance_review_content, f"Missing telemetry/logging token {token} in instanceReview.ps1"

    perfmon_content = (SQLSERVER_DIR / "dmaSQLServerPerfmonDataset.ps1").read_text(encoding="utf-8")
    assert "$foldername\\$logFile" not in perfmon_content
    assert "$outputDir\\$perfmonLogFile" in perfmon_content

    hw_content = (SQLSERVER_DIR / "dmaSQLServerHWSpecs.ps1").read_text(encoding="utf-8")
    assert "PhysicalCPUs=$($csvData.PhysicalCpuCount)" in hw_content
    assert "$_.Exception.GetType().FullName" in hw_content


def test_sql_hardening_and_false_positive_guards(instance_review_content: str) -> None:
    machine_specs = _read_sql_file("machineSpecsTsql.sql")
    assert "EXEC sys.sp_executesql" in machine_specs
    assert "EXEC('" not in machine_specs
    assert "cpu_count / hyperthread_ratio" in machine_specs

    for azure_file in (
        "azureDbResourceStats.sql",
        "azureElasticPoolStats.sql",
        "azureResourceGovernance.sql",
        "azureResourceStats.sql",
    ):
        azure_sql = _read_sql_file(azure_file)
        assert "EXEC sys.sp_executesql" in azure_sql, f"{azure_file} must use sp_executesql to defer binding"

    azure_db_res = _read_sql_file("azureDbResourceStats.sql")
    assert "dtu_limit" in azure_db_res
    assert "xtp_storage_percent" in azure_db_res

    azure_gov = _read_sql_file("azureResourceGovernance.sql")
    assert "logical_cpus" in azure_gov
    assert "primary_group_max_io" in azure_gov
    assert "primary_max_log_rate" in azure_gov

    elastic_pool = _read_sql_file("azureElasticPoolStats.sql")
    assert "sys.elastic_pool_resource_stats" in elastic_pool
    assert "sys.dm_elastic_pool_resource_stats" not in elastic_pool

    batch_footprint = _read_sql_file("batchFootprint.sql")
    assert "RTRIM(LTRIM(CONVERT(NVARCHAR(MAX), bcount.counter_name)))" in batch_footprint

    deep_scanner = _read_sql_file("tsqlPostgresDeepScanner.sql")
    assert "'%xp[_]%'" in deep_scanner
    assert "'%[^#]#[a-zA-Z_]%'" in deep_scanner
    assert "('%#%', 'TEMP_TABLE_LOCAL'" not in deep_scanner

    agent_jobs = _read_sql_file("sqlAgentJobs.sql")
    assert "LEFT JOIN msdb.dbo.syscategories" in agent_jobs
    assert "'%xp[_]%'" in agent_jobs
    assert "'%sp[_]OA%'" in agent_jobs

    waits_stats = _read_sql_file("waitsStats.sql")
    assert "NULLIF(MAX ([W1].[WaitCount]), 0)" in waits_stats
    assert "'\"' + @PKEY + '\"' AS PKEY" in waits_stats

    assert r"if ($lineStr -match '^[\s\-|]+$')" in instance_review_content


def test_version_consistency_across_collector_and_masker_scripts(instance_review_content: str) -> None:
    expected_version = _read_project_version()
    assert f'$op_version = "{expected_version}"' in instance_review_content

    masker_content = (REPO_ROOT / "scripts" / "masker" / "dma-collection-masker").read_text(encoding="utf-8")
    assert f'__version__ = "{expected_version}"' in masker_content

    for db_engine in ("oracle", "mysql", "postgres"):
        script_path = REPO_ROOT / "scripts" / "collector" / db_engine / "collect-data.sh"
        script_content = script_path.read_text(encoding="utf-8")
        assert f'dma_version="{expected_version}"' in script_content, f"Version mismatch in {script_path}"
