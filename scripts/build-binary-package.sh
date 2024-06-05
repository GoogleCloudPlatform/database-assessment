#!/usr/bin/env bash
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
# shellcheck disable=SC2086
current_version=$(hatch version)
hatch build
PYAPP_PYTHON_VERSION="3.12" PYAPP_DISTRIBUTION_VARIANT="v1" PYAPP_UV_ENABLED="1" PYAPP_FULL_ISOLATION="1" PYAPP_DISTRIBUTION_EMBED="1" \
    PYAPP_PROJECT_PATH="$(ls ${PWD}/dist/dma-${current_version}-py3-none-any.whl)" \
    PYAPP_PROJECT_FEATURES="oracle,postgres,mssql,mysql,server" \
    hatch build -t binary
