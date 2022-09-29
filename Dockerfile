# Dockerfile
ARG PYTHON_IMAGE=python:3.10-slim

## Build venv
FROM ${PYTHON_IMAGE} as python-base
ENV PIP_DEFAULT_TIMEOUT=100 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_ROOT_USER_ACTION=ignore \
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
    && rm -rf /var/cache/apt/*
RUN pip install  --no-cache-dir  --upgrade pip  \
    pip install  --no-cache-dir  --upgrade wheel setuptools cython


FROM python-base AS build-stage
RUN apt-get install -y --no-install-recommends curl git build-essential \
    && apt-get autoremove -y

WORKDIR /app
COPY requirements /app/requirements
COPY requirements.txt setup.py README.md LICENSE /app/ 
COPY db_assessment /app/db_assessment
RUN python -m venv --copies /app/venv
RUN . /app/venv/bin/activate \
    && pip install  --no-cache-dir  -r requirements.txt  \
    && pip install /app/

## Beginning of runtime image
FROM ${PYTHON_IMAGE} as run-image
ENV PATH=/app/venv/bin:$PATH \
    PYTHONPATH=/app/
WORKDIR /app

# switch to a non-root user for security
RUN addgroup --system --gid 1001 "app-user" \
    && adduser --no-create-home --system --uid 1001 "app-user" \
    && chown -R "app-user":"app-user" /app
COPY --chown="app-user":"app-user" --from=build-stage /app/venv /app/venv/
COPY --chown="app-user":"app-user" requirements /app/requirements
COPY --chown="app-user":"app-user" requirements.txt setup.py tasks.py README.md  LICENSE /app/ 
COPY --chown="app-user":"app-user" sample /app/sample

# These are the two folders that change the most.
COPY --chown="app-user":"app-user" db_assessment /app/db_assessment

USER "app-user"
ENTRYPOINT [ "gunicorn","--bind", "0.0.0.0:8080","--timeout", "0", "--workers","1", "db_assessment.api:app"]
EXPOSE 8080