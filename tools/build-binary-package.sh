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
set -euxo pipefail
current_version=$(hatch version)


export HATCH_BUILD_LOCATION="dist"
export CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_DEBUG="true"
# export CARGO_BUILD_TARGET="x86_64-unknown-linux-gnu"
export RUST_BACKTRACE="full"
export PYAPP_VERSION="v0.27.0"
export PYAPP_REPO="dist/.scratch"
export PYAPP_PROJECT_PATH="$(realpath dist/dma-${current_version}-py3-none-any.whl)"
export PYAPP_PROJECT_NAME="dma"
export PYAPP_PROJECT_VERSION="${current_version}"
export PYAPP_PROJECT_DEPENDENCY_FILE="$(realpath dist/requirements.txt)"
export PYAPP_PYTHON_VERSION="3.12"
export PYAPP_PROJECT_FEATURES="postgres"
export PYAPP_DISTRIBUTION_VARIANT="v1"
export PYAPP_UV_ENABLED="true"
export PYAPP_FULL_ISOLATION="true"
export PYAPP_DISTRIBUTION_EMBED="true"
rm -Rf dist/.scratch
git clone --quiet --depth 1 --branch $PYAPP_VERSION https://github.com/ofek/pyapp dist/.scratch

hatch build
hatch dep show requirements --project-only > dist/requirements.txt
hatch dep show requirements -p  -f postgres -f server >> dist/requirements.txt
echo "$(realpath dist/dma-${current_version}-py3-none-any.whl)" >> dist/requirements.txt
cd dist/.scratch && cargo build --release  &&  cd -
