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
.PARAMETER serverName
    Connection string usually in the form of [server name / ip address]\[instance name] (required)
.PARAMETER port
    Connection port (optional)
.PARAMETER user
    SqlServer superuser username (required)
.PARAMETER pass
    SqlServer superuser password (required)
.PARAMETER collectionUserName
    Collection username (optional)
.PARAMETER collectionUserPass
    Collection username password (optional)
.EXAMPLE
    To use a specific username / password combination:
        C:\createuserwithsqluser.ps1 -serverName [server name / ip address]\[instance name] -user [superuser] -pass [superuser password] -collectionUserName [collection username] -collectionUserPass [collection username password]
    
    or
    
    To use default credentials:
        C:\createuserwithsqluser.ps1 -serverName [server name / ip address]\[instance name] -user [superuser] -pass [superuser password]
.NOTES
    https://googlecloudplatform.github.io/database-assessment/
#>
Param(
[Parameter(Mandatory=$true)][string]$serverName="",
[Parameter(Mandatory=$true)][string]$port="",
[Parameter(Mandatory=$true)][string]$user="",
[Parameter(Mandatory=$true)][string]$pass="",
[Parameter(Mandatory=$false)][string]$collectionUserName="",
[Parameter(Mandatory=$false)][string]$collectionUserPass=""
)

if ([string]::IsNullorEmpty($serverName)) {
    Write-Output "Server parameter $serverName is empty.  Ensure that the parameter is provided"
    Exit 1
} elseif ([string]::IsNullorEmpty($port)) {
    Write-Output "Server Admin Port parameter $port is empty.  Ensure that the parameter is provided"
    Exit 1
} elseif ([string]::IsNullorEmpty($user)) {
    Write-Output "Server Admin Username parameter $user is empty.  Ensure that the parameter is provided"
    Exit 1
} elseif ([string]::IsNullorEmpty($pass)) {
    Write-Output "Server Admin Username password parameter $pass is empty.  Ensure that the parameter is provided"
    Exit 1
} elseif ([string]::IsNullorEmpty($collectionUserName)) {
    Write-Output "Collection Username parameter $collectionUserName is empty.  Ensure that the parameter is provided"
    Exit 1
} elseif ([string]::IsNullorEmpty($collectionUserPass)) {
    Write-Output "Collection Username password parameter $collectionUserPass is empty.  Ensure that the parameter is provided"
    Exit 1
}

if ([string]::IsNullorEmpty($port)) {
    Write-Output "Creating Collection User in $serverName"
    sqlcmd -S $serverName -i sql\createCollectionUser.sql -d master -U $user -P $pass -l 30 -m 1 -v collectionUser=$collectionUserName collectionPass=$collectionUserPass
} else {
    $serverName = "$serverName,$port"
    Write-Output "Creating Collection User in $serverName, using PORT $port"
    sqlcmd -S $serverName -i sql\createCollectionUser.sql -d master -U $user -P $pass -l 30 -m 1 -v collectionUser=$collectionUserName collectionPass=$collectionUserPass
}

Exit 0