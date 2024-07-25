#!/bin/bash

# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

### Setup directories needed for execution
#############################################################################

# Validate the number of arguments
if [ "$#" -lt 6 ]; then
    echo "Usage: $0 <machine_name> <user_name> <pkey> <dma_source_id> <dma_manual_id> <outputPath> [<additional_ssh_args>...]"
    exit 1
fi

# Inputs
machine_name=$1
userName=$2
pkey=$3
dmaSourceId=$4
dmaManualId=$5
outputPath=$6

# Function to echo log messages
function writeLog() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1"
}

# Output headers
headers="PKEY|DMA_SOURCE_ID|DMA_MANUAL_ID|MACHINE_NAME|PHYSICAL_CPU_COUNT|LOGICAL_CPU_COUNT|TOTAL_OS_MEMORY_MB|TOTAL_SIZE_BYTES|USED_SIZE_BYTES|PRIMARY_MAC|IP_ADDRESSES"
# Output defaults. We do some wierd postprocessing that deletes some characters, if not for the quotation marks.
defaults="\"$pkey\"|\"$dmaSourceId\"|\"$dmaManualId\"|\"$machine_name\"|\"\"|\"\"|\"\"|\"\"|\"\"|\"\"|\"\""
echo "$headers" > "$outputPath"
echo "$defaults" >> "$outputPath"

coreScript=$(cat <<'EOF'
    hostName=$(hostname)
    physicalCpuCount=$(cat /proc/cpuinfo | grep -i '\s*core id\s*:' | sort | uniq | wc -l)
    logicalCpuCount=$(cat /proc/cpuinfo | grep -c -i '\s*processor\s*:')
    memoryMB=$(free -b | awk '/^Mem/{print ($2+0) / (1024*1024)}')
    totalSizeBytes=$(df --total / | awk '/total/{printf("%.0f\n", ($2+0) * 1024)}')
    usedSizeBytes=$(df --output=used -B1 / | awk 'NR==2{printf("%.0f\n", ($1+0))}')
    ipAddresses=$(ip -4 addr show scope global | awk '/inet / {gsub(/\/.*$/, "", $2); print $2}' | tr '\n' ',')

    while read -r iface; do
        # Exclude virtual MAC addresses.
        if [[ -d "/sys/class/net/$iface/device" && ! -d "/sys/class/net/$iface/device/virtual" ]]; then
            primaryMac=$(ip link show "$iface" | grep -Po 'link/ether \K[^ ]+')
            break
        fi
    done < <(ip link show | grep -Po '^[0-9]+:\s*\K[^:]+(?=:)') # Extracts the iface names from ip link show.
EOF
)

# Main script logic
writeLog "Fetching machine HW specs from computer: $machine_name and storing it in output: $outputPath"

# Check if machineName is "localhost"
if [ "$machine_name" = "0.0.0.0" ] || grep -q "$machine_name" /etc/hosts; then
    source <(echo "$coreScript")
else
    if [[ -z "$userName" ]]; then
        echo "VM User name not set, skipping."
        exit 0
    fi
    setScript=$(cat <<'EOF'
        echo "hostName=$hostName"
        echo "physicalCpuCount=$physicalCpuCount"
        echo "logicalCpuCount=$logicalCpuCount"
        echo "memoryMB=$memoryMB"
        echo "totalSizeBytes=$totalSizeBytes"
        echo "usedSizeBytes=$usedSizeBytes"
        echo "primaryMac=$primaryMac"
        echo "ipAddresses=$ipAddresses"
EOF
)
    output=$(ssh "$userName@$machine_name" "${@:7}" "$coreScript; $setScript") || { echo "SSH to $machine_name failed"; exit 1; }
    source <(echo "$output")
fi


# Writing result to output
csvData="\"$pkey\"|\"$dmaSourceId\"|\"$dmaManualId\"|\"$hostName\"|$physicalCpuCount|$logicalCpuCount|$memoryMB|$totalSizeBytes|$usedSizeBytes|$primaryMac|$ipAddresses"
echo "$headers" > "$outputPath"
echo "$csvData" >> "$outputPath"

writeLog "Successfully fetched machine HW specs of $machine_name to output: $outputPath"
