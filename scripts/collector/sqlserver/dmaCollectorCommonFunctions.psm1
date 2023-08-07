# Copyright 2023 Google LLC
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
<#
.SYNOPSIS
    .
.DESCRIPTION
    Creates a user within the SQL Server Database using "Windows Authentication" with the necessary permissions 
    needed to execute subsequent scripts to collect data from SQL Server and Perfmon to be uploaded to Google Database Migration Assistant for review.

.NOTES
    https://googlecloudplatform.github.io/database-assessment/
#>

function writeLog {
    param(
        [Parameter(Mandatory=$false)][string]$logLocation,
        [Parameter(Mandatory=$true)][string]$logMessage,
        [Parameter(Mandatory=$false)][string]$logOperation='BOTH'
    )
	$currentTimestamp = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
    if (([string]$logOperation.toUpper() -eq 'BOTH') -and ($logLocation -ne '')) {
        Write-Output "$currentTimestamp   $logMessage" | Add-Content -Encoding utf8 -Path $logLocation
        Write-Output "$currentTimestamp   $logMessage"
    } elseif (([string]$logOperation.toUpper() -eq 'FILE') -and ($logLocation -ne '')) {
        Write-Output "$currentTimestamp   $logMessage" | Add-Content -Encoding utf8 -Path $logLocation
    } elseif ([string]$logOperation.toUpper() -eq 'MESSAGE') {
        Write-Output "$currentTimestamp   $logMessage"
    } else {
        Write-Output "$currentTimestamp   $logMessage"
    }
}

function createManifestFile {
    param(
        [Parameter(Mandatory=$true)][string]$manifestFileLocation,
        [Parameter(Mandatory=$true)][string]$manifestOutputFileName,
        [Parameter(Mandatory=$true)][string]$manifestedFileName
    )
    $fileMD5Hash = (Get-FileHash -Algorithm MD5 -Path $manifestFileLocation\$manifestedFileName).Hash
    Add-Content -Path $manifestFileLocation\$manifestOutputFileName -Value "mssql|$fileMD5Hash|$manifestedFileName"
}

function getCurrentTimestamp {
    $currentTimestamp = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
    return $currentTimestamp 
}