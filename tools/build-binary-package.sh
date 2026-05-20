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
current_version=$(uv run python -c "from dma.__about__ import __version__; print(__version__)")


export HATCH_BUILD_LOCATION="dist"
export CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_DEBUG="true"
# export CARGO_BUILD_TARGET="x86_64-unknown-linux-gnu"
export RUST_BACKTRACE="full"
export PYAPP_VERSION="v0.29.0"
export PYAPP_DIR="dist/.scratch"
export PYAPP_PROJECT_PATH="$(realpath dist/dma-${current_version}-py3-none-any.whl)"
export PYAPP_PROJECT_NAME="dma"
export PYAPP_PROJECT_VERSION="${current_version}"
export PYAPP_PROJECT_DEPENDENCY_FILE="$(realpath dist/requirements.txt)"
export PYAPP_PYTHON_VERSION="3.13"
export PYAPP_PROJECT_FEATURES="server,postgres"
export PYAPP_DISTRIBUTION_VARIANT_CPU="v1"
export PYAPP_UV_ENABLED="true"
export PYAPP_FULL_ISOLATION="true"
export PYAPP_DISTRIBUTION_EMBED="true"
rm -Rf dist/.scratch
git clone --quiet --depth 1 --branch $PYAPP_VERSION https://github.com/ofek/pyapp ${PYAPP_DIR}

uv build
uv export --frozen --no-dev --no-editable --no-hashes --no-header --no-emit-project --extra postgres --extra server > dist/requirements.txt
echo "$(realpath dist/dma-${current_version}-py3-none-any.whl)" >> dist/requirements.txt

# Bundle Python dependencies and patch PyApp
uv run tools/bundle_python.py build \
  --requirements dist/requirements.txt \
  --output dist/python-dist.tar.gz \
  --pyapp-dir ${PYAPP_DIR} \
  --install-root "~/.dma"

export PYAPP_DISTRIBUTION_PATH="$(realpath dist/python-dist.tar.gz)"
export PYAPP_DISTRIBUTION_EMBED="true"
export PYAPP_SKIP_INSTALL="true"
unset PYAPP_PROJECT_DEPENDENCY_FILE

cd ${PYAPP_DIR} && cargo build --release  &&  cd -
cp ${PYAPP_DIR}/target/release/pyapp dist/dma
chmod +x dist/dma
