#!/usr/bin/env bash
# shellcheck disable=SC2086
current_version=$(hatch version)
hatch build
PYAPP_PYTHON_VERSION="3.12" PYAPP_DISTRIBUTION_VARIANT="v1" PYAPP_UV_ENABLED="1" PYAPP_FULL_ISOLATION="1" PYAPP_DISTRIBUTION_EMBED="1" \
    PYAPP_PROJECT_PATH="$(ls ${PWD}/dist/dma-${current_version}-py3-none-any.whl)" \
    PYAPP_PROJECT_FEATURES="oracle,postgres,mssql,mysql,server,remote" \
    hatch build -t app
