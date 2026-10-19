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
    assert collector_artifacts.sqlserver_zip is not None
    assert collector_artifacts.sqlserver_zip.is_file()

    with zipfile.ZipFile(collector_artifacts.sqlserver_zip) as zf:
        archive_names = set(zf.namelist())

    for filename in ORIGINAL_SQL_FILES:
        assert f"sql/{filename}" in archive_names

    for filename in NEW_DEEP_SQL_SPECS:
        assert f"sql/{filename}" in archive_names


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
