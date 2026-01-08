#!/usr/bin/env bash
set -e

# Detect if running on Google internal Linux (Rodete)
if grep -q "rodete" /etc/os-release; then
    echo "Detected Google internal environment (Rodete)."
    
    if [ ! -f "uv.toml" ]; then
        echo "Creating uv.toml to force public PyPI index..."
        cat <<EOF > uv.toml
[[index]]
name = "pypi"
url = "https://pypi.org/simple"
default = true
EOF
        echo "uv.toml created."
    else
        echo "uv.toml already exists. Skipping creation."
    fi
else
    echo "Not running on Rodete. Skipping uv.toml creation."
fi
