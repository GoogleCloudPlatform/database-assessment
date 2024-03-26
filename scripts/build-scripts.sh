#!/usr/bin/env bash
# shellcheck disable=SC2086
current_version=$(hatch version)

function clean() {
rm -Rf dist/collector/*
}


echo  "=> Cleaning previous build artifacts for data collector scripts..."
clean
echo "=> Building Assessment Data Collection Scripts for Oracle version ${current_version}"
