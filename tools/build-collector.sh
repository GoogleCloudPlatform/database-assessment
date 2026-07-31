#!/usr/bin/env bash
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
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-dist}"
COLLECTOR_PACKAGE="${COLLECTOR_PACKAGE:-db-migration-assessment-collection-scripts}"
VERSION="${VERSION:-}"
COMMIT_SHA="${COMMIT_SHA:-}"

if [[ -z "${COMMIT_SHA}" ]]; then
  if git -C "${ROOT_DIR}" rev-parse --short HEAD >/dev/null 2>&1; then
    COMMIT_SHA="git-$(git -C "${ROOT_DIR}" rev-parse --short HEAD)"
  else
    COMMIT_SHA="git-unknown"
  fi
fi

if [[ -z "${VERSION}" ]]; then
  if command -v uv >/dev/null 2>&1; then
    VERSION="$(uv run python -c "from dma.__about__ import __version__; print(__version__)")"
  else
    VERSION="$(PYTHONPATH="${ROOT_DIR}/src" python -c "from dma.__about__ import __version__; print(__version__)")"
  fi
fi

BUILD_ROOT="${ROOT_DIR}/${BUILD_DIR}"
COLLECTOR_ROOT="${BUILD_ROOT}/collector"

rm -rf "${COLLECTOR_ROOT}"

echo "=> Building Assessment Data Collection Scripts for Oracle version ${VERSION}..."
mkdir -p "${COLLECTOR_ROOT}/oracle/sql/extracts/awr"
mkdir -p "${COLLECTOR_ROOT}/oracle/sql/extracts/statspack"
mkdir -p "${COLLECTOR_ROOT}/oracle/sql/setup"
cp "${ROOT_DIR}/scripts/collector/oracle/sql/"*.sql "${COLLECTOR_ROOT}/oracle/sql"
cp "${ROOT_DIR}/scripts/collector/oracle/sql/extracts/"*.sql "${COLLECTOR_ROOT}/oracle/sql/extracts"
cp "${ROOT_DIR}/scripts/collector/oracle/sql/extracts/awr/"*.sql "${COLLECTOR_ROOT}/oracle/sql/extracts/awr"
cp "${ROOT_DIR}/scripts/collector/oracle/sql/extracts/statspack/"*.sql "${COLLECTOR_ROOT}/oracle/sql/extracts/statspack"
cp "${ROOT_DIR}/scripts/collector/oracle/sql/setup/"*.sql "${COLLECTOR_ROOT}/oracle/sql/setup"
cp "${ROOT_DIR}/scripts/collector/oracle/collect-data.sh" "${COLLECTOR_ROOT}/oracle/"
cp "${ROOT_DIR}/scripts/collector/oracle/README.txt" "${COLLECTOR_ROOT}/oracle/"
cp "${ROOT_DIR}/LICENSE" "${COLLECTOR_ROOT}/oracle/"
echo "Database Migration Assessment Collector version ${VERSION} (${COMMIT_SHA})" > "${COLLECTOR_ROOT}/oracle/VERSION.txt"

echo "=> Building Assessment Data Collection Scripts for Microsoft SQL Server version ${VERSION}..."
mkdir -p "${COLLECTOR_ROOT}/sqlserver/sql/"
cp "${ROOT_DIR}/scripts/collector/sqlserver/sql/"*.sql "${COLLECTOR_ROOT}/sqlserver/sql"
cp "${ROOT_DIR}/scripts/collector/sqlserver/"*.bat "${COLLECTOR_ROOT}/sqlserver/"
cp "${ROOT_DIR}/scripts/collector/sqlserver/"*.ps1 "${COLLECTOR_ROOT}/sqlserver/"
cp "${ROOT_DIR}/scripts/collector/sqlserver/"*.psm1 "${COLLECTOR_ROOT}/sqlserver/"
cp "${ROOT_DIR}/scripts/collector/sqlserver/README.txt" "${COLLECTOR_ROOT}/sqlserver/"
cp "${ROOT_DIR}/LICENSE" "${COLLECTOR_ROOT}/sqlserver/"
echo "Database Migration Assessment Collector version ${VERSION} (${COMMIT_SHA})" > "${COLLECTOR_ROOT}/sqlserver/VERSION.txt"

echo "=> Building Assessment Data Collection Scripts for MySQL version ${VERSION}..."
mkdir -p "${COLLECTOR_ROOT}/mysql/sql/5.7"
mkdir -p "${COLLECTOR_ROOT}/mysql/sql/base"
mkdir -p "${COLLECTOR_ROOT}/mysql/sql/headers"
cp "${ROOT_DIR}/scripts/collector/mysql/sql/"*.sql "${COLLECTOR_ROOT}/mysql/sql"
cp "${ROOT_DIR}/scripts/collector/mysql/sql/5.7/"*.sql "${COLLECTOR_ROOT}/mysql/sql/5.7"
cp "${ROOT_DIR}/scripts/collector/mysql/sql/base/"*.sql "${COLLECTOR_ROOT}/mysql/sql/base"
cp "${ROOT_DIR}/scripts/collector/mysql/sql/headers/"*.header "${COLLECTOR_ROOT}/mysql/sql/headers"
cp "${ROOT_DIR}/scripts/collector/mysql/collect-data.sh" "${COLLECTOR_ROOT}/mysql/"
cp -L "${ROOT_DIR}/scripts/collector/mysql/db-machine-specs.sh" "${COLLECTOR_ROOT}/mysql/"
cp "${ROOT_DIR}/scripts/collector/mysql/README.txt" "${COLLECTOR_ROOT}/mysql/"
cp "${ROOT_DIR}/LICENSE" "${COLLECTOR_ROOT}/mysql/"
echo "Database Migration Assessment Collector version ${VERSION} (${COMMIT_SHA})" > "${COLLECTOR_ROOT}/mysql/VERSION.txt"

echo "=> Building Assessment Data Collection Scripts for Postgresql version ${VERSION}..."
mkdir -p "${COLLECTOR_ROOT}/postgres/sql/12"
mkdir -p "${COLLECTOR_ROOT}/postgres/sql/13"
mkdir -p "${COLLECTOR_ROOT}/postgres/sql/base"
mkdir -p "${COLLECTOR_ROOT}/postgres/sql/17"
cp "${ROOT_DIR}/scripts/collector/postgres/sql/"*.sql "${COLLECTOR_ROOT}/postgres/sql"
cp "${ROOT_DIR}/scripts/collector/postgres/sql/12/"*.sql "${COLLECTOR_ROOT}/postgres/sql/12"
cp "${ROOT_DIR}/scripts/collector/postgres/sql/13/"*.sql "${COLLECTOR_ROOT}/postgres/sql/13"
cp "${ROOT_DIR}/scripts/collector/postgres/sql/base/"*.sql "${COLLECTOR_ROOT}/postgres/sql/base"
cp "${ROOT_DIR}/scripts/collector/postgres/sql/17/"*.sql "${COLLECTOR_ROOT}/postgres/sql/17"
cp "${ROOT_DIR}/scripts/collector/postgres/collect-data.sh" "${COLLECTOR_ROOT}/postgres/"
cp "${ROOT_DIR}/scripts/collector/postgres/db-machine-specs.sh" "${COLLECTOR_ROOT}/postgres/"
cp "${ROOT_DIR}/scripts/collector/postgres/README.txt" "${COLLECTOR_ROOT}/postgres/"
cp "${ROOT_DIR}/LICENSE" "${COLLECTOR_ROOT}/postgres/"
echo "Database Migration Assessment Collector version ${VERSION} (${COMMIT_SHA})" > "${COLLECTOR_ROOT}/postgres/VERSION.txt"

if ! command -v zip >/dev/null 2>&1; then
  echo "zip is required to package collector scripts."
  exit 1
fi

rm -f "${BUILD_ROOT}/${COLLECTOR_PACKAGE}"*.bz2
rm -f "${BUILD_ROOT}/${COLLECTOR_PACKAGE}"*.zip

echo "=> Packaging Database Migration Assessment Collector for Oracle..."
(
  cd "${COLLECTOR_ROOT}/oracle"
  zip -r "${BUILD_ROOT}/${COLLECTOR_PACKAGE}-oracle.zip" .
)

echo "=> Packaging Database Migration Assessment Collector for Microsoft SQL Server..."
(
  cd "${COLLECTOR_ROOT}/sqlserver"
  zip -r "${BUILD_ROOT}/${COLLECTOR_PACKAGE}-sqlserver.zip" .
)

echo "=> Packaging Database Migration Assessment Collector for MySQL..."
(
  cd "${COLLECTOR_ROOT}/mysql"
  zip -r "${BUILD_ROOT}/${COLLECTOR_PACKAGE}-mysql.zip" .
)

echo "=> Packaging Database Migration Assessment Collector for Postgres..."
(
  cd "${COLLECTOR_ROOT}/postgres"
  zip -r "${BUILD_ROOT}/${COLLECTOR_PACKAGE}-postgres.zip" .
)
