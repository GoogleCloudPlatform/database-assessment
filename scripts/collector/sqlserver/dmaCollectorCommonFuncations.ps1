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

    If user and password are supplied, that will be used to execute the script.  Otherwise default credentials hardcoded in the script will be used
.NOTES
    https://googlecloudplatform.github.io/database-assessment/
#>

function getTimeStamp {
    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
}

function WriteLog {
    param(
        [Parameter(Mandatory=$true)][string]$logLocation = "",
        [Parameter(Mandatory=$true)][string]$logMessage=""
    )
    Write-Output getTimeStamp + '   ' + $logMessage | Add-Content -Append -Encoding utf8 -Path $foldername\$logFile
}