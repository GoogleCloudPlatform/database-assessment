#!/usr/bin/env bash
# shellcheck disable=SC2086
current_version=$(hatch version)
hatch build
PYAPP_UV_ENABLED="1" PYAPP_PROJECT_PATH="$(ls ${PWD}/dist/dma-${current_version}-py3-none-any.whl)" PYAPP_PROJECT_FEATURES="oracle,postgres,mssql,mysql,server,remote" PYAPP_DISTRIBUTION_EMBED="1" hatch build -t app
