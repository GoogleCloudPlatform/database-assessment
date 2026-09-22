#!/usr/bin/env bash
# Copyright 2024 Google LLC
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

if [ "$#" -lt 6 ]; then
    echo "Usage: $0 <machine_name> <user_name> <pkey> <dma_source_id> <dma_manual_id> <outputPath> [<additional_ssh_args>...]"
    exit 1
fi

machine_name=$1
userName=$2
pkey=$3
dmaSourceId=$4
dmaManualId=$5
outputPath=$6

function writeLog() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1"
}

headers="PKEY|DMA_SOURCE_ID|DMA_MANUAL_ID|MACHINE_NAME|PHYSICAL_CPU_COUNT|LOGICAL_CPU_COUNT|TOTAL_OS_MEMORY_MB|TOTAL_SIZE_BYTES|USED_SIZE_BYTES|PRIMARY_MAC|IP_ADDRESSES"
defaults="\"${pkey//\"/\\\"}\"|\"${dmaSourceId//\"/\\\"}\"|\"${dmaManualId//\"/\\\"}\"|\"${machine_name//\"/\\\"}\"|0|0|0|0|0|\"\"|\"\""
echo "$headers" > "$outputPath"
echo "$defaults" >> "$outputPath"

coreScript=$(cat <<'EOF'
    hostName=$(hostname)
    os_type=$(uname)
    if [ "$os_type" = "AIX" ]; then
        physicalCpuCount=$(lsdev -Cc processor | grep Available | wc -l)
        logicalCpuCount=$(bindprocessor -q | awk '{print $NF}')
        memoryMB=$(bootinfo -r | awk '{printf("%d\n", $1 / 1024)}')
        totalSizeBytes=$(df -k / | awk 'NR>1 {sum+=$2} END {printf("%.0f\n", sum * 1024)}')
        usedSizeBytes=$(df -k / | awk 'NR>1 {sum+=$3} END {printf("%.0f\n", sum * 1024)}')
        ipAddresses=$(netstat -in | awk '$1 !~ /lo/ && $4 ~ /^[0-9]/ {print $4}' | tr '\n' ',')
        primaryMac=$(netstat -v | awk '/Hardware Address/{print $3; exit}')
    else
        physicalCpuCount=$(cat /proc/cpuinfo 2>/dev/null | grep -i '\s*core id\s*:' | sort | uniq | wc -l)
        [ "$physicalCpuCount" -eq 0 ] && physicalCpuCount=$(cat /proc/cpuinfo 2>/dev/null | grep -c -i 'processor')
        logicalCpuCount=$(cat /proc/cpuinfo 2>/dev/null | grep -c -i 'processor')
        memoryMB=$(free -b 2>/dev/null | awk '/^Mem/{printf("%d\n", ($2+0) / (1024*1024))}')
        totalSizeBytes=$(df --total / 2>/dev/null | awk '/total/{printf("%.0f\n", ($2+0) * 1024)}')
        usedSizeBytes=$(df --output=used -B1 / 2>/dev/null | awk 'NR==2{printf("%.0f\n", ($1+0))}')
        ipAddresses=$(ip -4 addr show scope global 2>/dev/null | awk '/inet / {gsub(/\/.*$/, "", $2); print $2}' | tr '\n' ',')
        primaryMac=$(ip link show 2>/dev/null | awk '/link\/ether/{print $2; exit}')
    fi
EOF
)

writeLog "Fetching machine HW specs from computer: $machine_name and storing in: $outputPath"

if [ "$machine_name" = "localhost" ] || [ "$machine_name" = "127.0.0.1" ] || [ "$machine_name" = "0.0.0.0" ] || grep -q "$machine_name" /etc/hosts 2>/dev/null; then
    source <(echo "${coreScript}")
else
    if [[ -z "$userName" ]]; then
        writeLog "VM User name not set, using default local detection."
        source <(echo "${coreScript}")
    else
        setScript=$(cat <<'EOF'
            echo
            echo "hostName=${hostName}"
            echo "physicalCpuCount=${physicalCpuCount}"
            echo "logicalCpuCount=${logicalCpuCount}"
            echo "memoryMB=${memoryMB}"
            echo "totalSizeBytes=${totalSizeBytes}"
            echo "usedSizeBytes=${usedSizeBytes}"
            echo "primaryMac=${primaryMac}"
            echo "ipAddresses=${ipAddresses}"
EOF
)
        output=$(ssh "${@:7}" "${userName}@${machine_name}" "${coreScript}; ${setScript}") || { writeLog "SSH to ${machine_name} failed"; exit 0; }
        eval ${output}
    fi
fi

esc_pkey="${pkey//\"/\\\"}"
esc_source_id="${dmaSourceId//\"/\\\"}"
esc_manual_id="${dmaManualId//\"/\\\"}"
esc_host_name="${hostName//\"/\\\"}"
esc_primary_mac="${primaryMac//\"/\\\"}"
esc_ip_addresses="${ipAddresses//\"/\\\"}"

csvData="\"${esc_pkey}\"|\"${esc_source_id}\"|\"${esc_manual_id}\"|\"${esc_host_name}\"|${physicalCpuCount:-0}|${logicalCpuCount:-0}|${memoryMB:-0}|${totalSizeBytes:-0}|${usedSizeBytes:-0}|\"${esc_primary_mac}\"|\"${esc_ip_addresses}\""
echo "$headers" > "$outputPath"
echo "$csvData" >> "$outputPath"
writeLog "Successfully fetched machine HW specs for $machine_name"
