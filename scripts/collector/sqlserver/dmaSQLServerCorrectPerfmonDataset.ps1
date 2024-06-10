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
<#
.SYNOPSIS
    .
.DESCRIPTION
    Creates a perfmon dataset and subsequent data files to be uploaded to Google Database Migration Assistant for MS SQL Server.
.PARAMETER namedInstanceName
    Enter the named instance name (Optional, unless using a named instance)
	If collecting from a named instance, enter the instance name or the default instance will be used.
.PARAMETER perfmonOutDir
    Final Output Directory (Required)
.PARAMETER perfmonOutFile
    Final Output File Name (Required)
.PARAMETER dmaSourceId
    DMA derived unique id (Required)
.PARAMETER dmaManualId
    Customer Manual Unique ID or dma manual unique id (Optional)
.PARAMETER perfmonDuration
	Number of Sample Intervals to execute
.PARAMETER perfmonSampleInterval
	Interval to collect samples in seconds
.EXAMPLE
    C:\dmaSQLServerPerfmonDataset.ps1 -operation create -namedInstanceName [named Instance] / $null
.NOTES
    https://googlecloudplatform.github.io/database-assessment/
#>
param (
    [Parameter(
        Mandatory = $True,
        HelpMessage = "The uncorrected perfmon full path and filename"
    )][string]$perfmonInFile,
    [Parameter(
        Mandatory = $False,
        HelpMessage = "The file name for the final perfmon combined file"
    )][string]$perfmonOutFile = $null,
    [Parameter(
        Mandatory = $True,
        HelpMessage = "The pkey value for the final perfmon combined file"
    )][string]$pkey = $null,
    [Parameter(
        Mandatory = $False,
        HelpMessage = "The dma_source_id value for the final perfmon combined file"
    )][string]$dmaSourceId,
    [Parameter(
        Mandatory = $False,
        HelpMessage = "The dma_manual_id / customer supplied tag value for the final perfmon combined file"
    )][string]$dmaManualId = "NA"
)

Import-Module $PSScriptRoot\dmaCollectorCommonFunctions.psm1

if (!$current_ts) {
    $current_ts = Get-Date -Format "MMddyyyyTHHmmss"
}

if (!$perfmonOutFile) {
    $perfmonOutFile = 'corrected_' + $current_ts + '_' + $perfmonInFile
}

$perfmonLogFile = 'correctPerfMonLog' + '__' + $pkey + '_' + $current_ts + '.log'
function CorrectDMAPerfmonDataSet {
    param(
        [string]$perfmonInFile,
        [string]$perfmonOutFile,
        [string]$pkey,
        [string]$logFile,
        [string]$dmaSourceId,
        [string]$dmaManualId
    )

    $outputDir = $PSScriptRoot
    $outputFileName = $perfmonOutFile
    $perfmonLogFile = $logFile

    WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Correcting results from the Google DMA SQL Server Perfmon Counter Data Set $perfmonInFile" -logOperation "BOTH"

    if (!(Test-Path -PathType container $outputDir)) {
        WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " " -logOperation "BOTH"
        WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Creating Output Directory $outputDir..." -logOperation "BOTH"
        $null = New-Item -ItemType Directory -Path $outputDir
    }

    if (Test-Path -Path $perfmonInFile) {
        WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " " -logOperation "BOTH"
        $fileExists = $true
        foreach ($file in Get-ChildItem -Path $perfmonInFile) {
            WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Moving perfmon datafile: $file to the $env:TEMP directory without header" -logOperation "BOTH"
            $tempFileName = Split-Path $file -leaf
            Get-Content -Path $file | Select-Object -Skip 1 | Set-Content -Encoding utf8 -Path $env:TEMP\$tempFileName
            $currentFileDate = (Get-Item $file).LastWriteTime
            if ($currentFileDate -ge $maxFileDate) {
                $maxFileDate = $currentFileDate
            }
        }
        WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Adding additional fields to perfmon files without header" -logOperation "BOTH"
        foreach ($file in Get-ChildItem -Path $env:TEMP\*$dataSet*.csv) {
            $tempFileName = 'PKEY_' + (Split-Path $file -leaf)
            Get-Content -Path $file | ForEach-Object {
                #New file split method
                $perfmonCsv = $_.ToString() -split ','
                $perfmonFormattedDate = checkTimestampFormat($perfmonCsv[0])
                # May have to modify the field mapping below based on the specific file issue
                '"' + $pkey + '"|' + $perfmonFormattedDate + '|' + $perfmonCsv[1] + '|' + $perfmonCsv[2] + '|' + $perfmonCsv[3] + '|' + $perfmonCsv[4] + '|' + $perfmonCsv[5] + '|' + $perfmonCsv[6] + '|' + $perfmonCsv[7] + '|' + $perfmonCsv[8] + '|' + $perfmonCsv[9] + '|' + $perfmonCsv[10] + '|' + $perfmonCsv[11] + '|' + $perfmonCsv[12] + '|' + $perfmonCsv[13] + '|' + $perfmonCsv[14] + '|' + $perfmonCsv[15] + '|' + $perfmonCsv[16] + '|' + $perfmonCsv[17] + '|' + $perfmonCsv[18] + '|' + $perfmonCsv[19] + '|' + $perfmonCsv[20] + '|' + $perfmonCsv[21] + '|' + $perfmonCsv[22] + '|' + $perfmonCsv[23] + '|"' + $dmaSourceId + '"|"' + $dmaManualId + '"|' + $perfmonCsv[24] + '|' + $perfmonCsv[25] + '|' + $perfmonCsv[26] + '|' + $perfmonCsv[27] + '|' + $perfmonCsv[28] + '|' + $perfmonCsv[29]
            } | Out-File -FilePath $env:TEMP\$tempFileName -Encoding utf8
        }
        WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " " -logOperation "BOTH"
        WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " Max perfmon file date available: $maxFileDate" -logOperation "BOTH"
        WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " " -logOperation "BOTH"
    }
    else {
        WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage " " -logOperation "BOTH"
        WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Perfmon File $perfmonInFile does not exist." -logOperation "FILE"
        Write-Output "$("[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date))   Perfmon File $perfmonInFile does not exist." | Yellow
        $fileExists = $false
    }

    WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Concatenating and adding header to perfmon files..." -logOperation "BOTH"
    $tempContent = '"PKEY"|"COLLECTION_TIME"|"AVAILABLE_MBYTES"|"PHYSICALDISK_AVG_DISK_BYTES_READ"|"PHYSICALDISK_AVG_DISK_BYTES_WRITE"|"PHYSICALDISK_AVG_DISK_BYTES_READ_SEC"|"PHYSICALDISK_AVG_DISK_BYTES_WRITE_SEC"|"PHYSICALDISK_DISK_READS_SEC"|"PHYSICALDISK_DISK_WRITES_SEC"|"PROCESSOR_IDLE_TIME_PCT"|"PROCESSOR_TOTAL_TIME_PCT"|"PROCESSOR_FREQUENCY"|"PROCESSOR_QUEUE_LENGTH"|"BUFFER_CACHE_HIT_RATIO"|"CHECKPOINT_PAGES_SEC"|"FREE_LIST_STALLS_SEC"|"PAGE_LIFE_EXPECTANCY"|"PAGE_LOOKUPS_SEC"|"PAGE_READS_SEC"|"PAGE_WRITES_SEC"|"USER_CONNECTION_COUNT"|"MEMORY_GRANTS_PENDING"|"TARGET_SERVER_MEMORY_KB"|"TOTAL_SERVER_MEMORY_KB"|"BATCH_REQUESTS_SEC"|"DMA_SOURCE_ID"|"DMA_MANUAL_ID"|"NUMA_TOTAL_MEMORY_MB"|"NUMA_AVAILABLE_MEMORY_MB"|"PROCESS_IO_READ_OPERATIONS_SEC"|"PROCESS_IO_WRITE_OPERATIONS_SEC"|"PROCESS_IO_READ_BYTES_SEC"|"PROCESS_IO_WRITE_BYTES_SEC"'
    if ($fileExists) {
        Set-Content -Path $outputDir\$outputFileName -Value $tempContent -Encoding utf8
		((Get-Content -Path $env:TEMP\$tempFileName -Raw ) -replace ',', '|') | Add-Content -Encoding utf8 -Path $outputDir\$outputFileName
    }

    if (Test-Path -Path $outputDir\$outputFileName) {
        WriteLog -logLocation $outputDir\$perfmonLogFile -logMessage "Clean up Temp File area..." -logOperation "BOTH"
        Remove-Item -Path $env:TEMP\*$dataSet*.csv
    }
}

CorrectDMAPerfmonDataSet -perfmonInFile $perfmonInFile -perfmonOutFile $perfmonOutFile -pkey $pkey -dmaSourceId $dmaSourceId -dmaManualId $dmaManualId -logFile $perfmonLogFile
