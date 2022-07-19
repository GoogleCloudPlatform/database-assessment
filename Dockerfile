# Dockerfile
ARG PYTHON_BUILDER_IMAGE=3.9-slim
ARG PYTHON_RUN_IMAGE=gcr.io/distroless/python3
## Store the commit versiom into the image for usage later
FROM alpine/git AS git
ADD . /app
WORKDIR /app
# I use this file to provide the git commit
# in the footer without having git present
# in my production image
RUN git rev-parse HEAD | tee /version

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
    && rm -rf /var/cache/apt/*
RUN pip install --upgrade pip  \
    pip install wheel setuptools


FROM python-base AS build-stage
RUN apt-get install -y --no-install-recommends curl git build-essential \
    && apt-get autoremove -y

WORKDIR /app
COPY requirements.txt api-requirements ./
RUN python -m venv --copies /app/venv
RUN . /app/venv/bin/activate \
    &&  pip install -r requirements.txt  -r api-requirements.txt

## Beginning of runtime image
FROM python:${PYTHON_RUN_IMAGE} as run-image
COPY --from=build-stage /app/venv /app/venv/
ENV PATH /app/venv/bin:$PATH
WORKDIR /app

# These are the two folders that change the most.
COPY db_assessment ./app/
COPY --from=git /version /app/.version

# switch to a non-root user for security
RUN addgroup --system --gid 1001 "app-user"
RUN adduser --system --uid 1001 "app-user"
USER "app-user"


ENTRYPOINT [ "gunicorn","-w", "0.0.0.0:8080", ]
EXPOSE 8080