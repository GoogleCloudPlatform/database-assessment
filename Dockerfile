# Dockerfile
ARG PYTHON_BUILDER_IMAGE=3.10-slim


## Build venv
FROM python:${PYTHON_BUILDER_IMAGE} as python-base
ENV PIP_DEFAULT_TIMEOUT=100 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONFAULTHANDLER=1 \
    PYTHONHASHSEED=random
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /root/.cache \
    && rm -rf /var/apt/lists/* \
    && rm -rf /var/cache/apt/* \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
RUN pip install --upgrade pip wheel setuptools cython virtualenv numpy

FROM docker:20.10.12 as static-docker-source

FROM python-base AS build-stage
ARG CLOUD_SDK_VERSION=402.0.0
ENV CLOUD_SDK_VERSION=$CLOUD_SDK_VERSION
ARG POETRY_INSTALL_ARGS="--only main"
ENV POETRY_HOME="/opt/poetry" \
    POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_CREATE=0 \
    POETRY_VIRTUALENVS_IN_PROJECT=1 \
    POETRY_CACHE_DIR='/var/cache/pypoetry' \
    POETRY_VERSION='1.2.2' \
    POETRY_INSTALL_ARGS="${POETRY_INSTALL_ARGS}" \
    PROTOC_VERSION="3.14.0" \
    BAZEL_VERSION="5.1.1" \
    GRPC_PYTHON_BUILD_WITH_CYTHON=1 \ 
    PATH="/workspace/venv/bin:/google-cloud-sdk/bin:$PATH"

RUN apt-get install -y --no-install-recommends curl git build-essential g++ unzip ca-certificates libaio1 libaio-dev ninja-build make gnupg cmake gcc libssl-dev wget zip maven unixodbc-dev libssl-dev libcurl4-gnutls-dev libexpat1-dev gettext checkinstall libffi-dev libz-dev \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /root/.cache \
    && rm -rf /var/apt/lists/* \
    && rm -rf /var/cache/apt/* \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

# installs specified bazel
RUN if [ `uname -m` = 'x86_64' ]; then BAZEL_ARCHITECTURE="x86_64"; else BAZEL_ARCHITECTURE="arm64"; fi \
    && curl -sS -L -o bazel --output-dir /usr/local/bin/ --create-dirs "https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-linux-${BAZEL_ARCHITECTURE}" \
    && chmod +x /usr/local/bin/bazel

# installs specified protobuf
RUN if [ `uname -m` = 'x86_64' ]; then PROTOC_ARCHITECTURE="x86_64"; else PROTOC_ARCHITECTURE="aarch_64"; fi \
    && curl -sS -L -o protoc.zip --output-dir /tmp/ --create-dirs "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-${PROTOC_ARCHITECTURE}.zip" \
    && unzip /tmp/protoc.zip -d /usr/local \
    && rm -rf /tmp/*

# installs google cli
RUN if [ `uname -m` = 'x86_64' ]; then echo -n "x86_64" > /tmp/arch; else echo -n "arm" > /tmp/arch; fi;
RUN ARCH=`cat /tmp/arch` && curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-${ARCH}.tar.gz && \
    tar xzf google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-${ARCH}.tar.gz && \
    rm google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-${ARCH}.tar.gz
RUN echo -n "app-engine-java app-engine-python alpha beta pubsub-emulator cloud-datastore-emulator app-engine-go bigtable cbt datalab app-engine-python-extras kubectl gke-gcloud-auth-plugin kustomize minikube skaffold kpt local-extract" > /tmp/additional_components
# These components are not available on ARM right now.
RUN if [ `uname -m` = 'x86_64' ]; then echo -n " appctl nomos anthos-auth" >> /tmp/additional_components; fi;
RUN /google-cloud-sdk/install.sh --bash-completion=false --path-update=true --usage-reporting=false \
	--additional-components `cat /tmp/additional_components` && rm -rf /google-cloud-sdk/.install/.backup
RUN git config --system credential.'https://source.developers.google.com'.helper gcloud.sh


RUN curl -sSL https://install.python-poetry.org | python - \
    && ln -s /opt/poetry/bin/poetry /usr/local/bin/poetry

WORKDIR /workspace/app
COPY pyproject.toml poetry.lock README.md mkdocs.yml mypy.ini .flake8 .pre-commit-config.yaml .pylintrc LICENSE Makefile ./
# COPY tests ./tests/
copy sample ./sample
COPY docs ./docs/
COPY scripts ./scripts
COPY tasks.py ./
COPY src/server ./src/server
RUN python -m venv --copies /workspace/venv
RUN . /workspace/venv/bin/activate \
    && pip install -U cython setuptools wheel numpy \
    && poetry install $POETRY_INSTALL_ARGS
VOLUME ["/root/.config", "/root/.kube"]


## Beginning of runtime image
FROM python:${PYTHON_BUILDER_IMAGE} as run-image
ENV PATH /workspace/venv/bin:$PATH
# switch to a non-root user for security
WORKDIR /workspace/app
RUN addgroup --system --gid 1001 "app-user" \
    && adduser --no-create-home --system --uid 1001 "app-user" \
    && chown -R "app-user":"app-user" /workspace
# move files that are changed more often towards the bottom or appended to the end for docker image caching
COPY --chown="app-user":"app-user" --from=build-stage /workspace/venv /workspace/venv/
COPY --chown="app-user":"app-user" scripts ./scripts/
COPY --chown="app-user":"app-user" pyproject.toml README.md mkdocs.yml mypy.ini .flake8 .pre-commit-config.yaml .pylintrc LICENSE Makefile ./
COPY --chown="app-user":"app-user" docs ./docs/
# this folder changes the most
COPY --chown="app-user":"app-user" src/server /workspace/app/src/server
USER "app-user"
ENTRYPOINT [ "gunicorn","--bind", "0.0.0.0:8080","--timeout", "0", "--workers","1", "db_assessment.api:app"]
EXPOSE 8080