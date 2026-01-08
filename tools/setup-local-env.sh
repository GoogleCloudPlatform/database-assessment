#!/usr/bin/env bash
set -e

# Detect if running on Google internal Linux (Rodete)
if grep -q "rodete" /etc/os-release; then
    echo "Detected Google internal environment (Rodete)."
    
    if [ ! -f "uv.toml" ]; then
        echo "Creating uv.toml for internal package index..."
        cat <<EOF > uv.toml
[[index]]
name = "google-internal"
url = "https://us-python.pkg.dev/artifact-foundry-prod/ah-3p-staging-python/simple/"
default = true
EOF
        echo "uv.toml created."
    else
        echo "uv.toml already exists. Skipping creation."
    fi
else
    echo "Not running on Rodete. Skipping uv.toml creation."
fi
