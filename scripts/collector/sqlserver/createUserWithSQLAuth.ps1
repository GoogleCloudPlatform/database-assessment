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
    [Parameter()][string]$serverName,
    [Parameter()][string]$port = "default",
    [Parameter()][string]$user,
    [Parameter()][string]$pass,
    [Parameter()][string]$collectionUserName,
    [Parameter()][string]$collectionUserPass
)

Import-Module $PSScriptRoot\dmaCollectorCommonFunctions.psm1

if ([string]::IsNullorEmpty($pass)) {
    Write-Output ""
    Write-Output "Admin Username password parameter is not provided"
    $passPrompt = Read-Host 'Please enter your Admin User password' -AsSecureString
    $pass = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($passPrompt))
    Write-Output ""
}

if ([string]::IsNullorEmpty($collectionUserPass)) {
    Write-Output ""
    Write-Output "Collection Username password parameter is not provided"
    $collectionPassPrompt = Read-Host 'Please enter your Collection User password' -AsSecureString
    $collectionUserPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($collectionPassPrompt))
    Write-Output ""
}

if ([string]::IsNullorEmpty($serverName)) {
    Write-Output "Server parameter $serverName is empty.  Ensure that the parameter is provided"
    Exit 1
}
if ([string]::IsNullorEmpty($user)) {
    Write-Output "Server Admin Username parameter $user is empty.  Ensure that the parameter is provided"
    Exit 1
}
if ([string]::IsNullorEmpty($collectionUserName)) {
    Write-Output "Collection Username parameter $collectionUserName is empty.  Ensure that the parameter is provided"
    Exit 1
}

$validSQLInstanceVersionCheckArray = @(sqlcmd -S $serverName -i sql\checkValidInstanceVersion.sql -d master -U $user -P $pass -C -l 30 -W -m 1 -u -h-1 -w 32768)
$splitValidInstanceVerisionCheckObj = $validSQLInstanceVersionCheckArray[0].Split('')
$validSQLInstanceVersionCheckValues = $splitValidInstanceVerisionCheckObj | ForEach-Object { if ($_.Trim() -ne '') { $_ } }
# $isValidSQLInstanceVersion = $validSQLInstanceVersionCheckValues[0]
$isCloudOrLinuxHost = $validSQLInstanceVersionCheckValues[1]

if (([string]::IsNullorEmpty($port)) -or ($port -eq "default")) {
    WriteLog -logMessage "Creating collection user in $serverName" -logOperation "MESSAGE"
    sqlcmd -S $serverName -i sql\createCollectionUser.sql -d master -U $user -P $pass -C -l 30 -m 1 -v collectionUser=$collectionUserName collectionPass=$collectionUserPass

    ### If Azure, need to get a list of databases from master and log in to each individually to create the user
    if ($isCloudOrLinuxHost -eq "AZURE") {
        $dbNameArray = @(sqlcmd -S $serverName -i sql\getDBList.sql -d master -U $collectionUserName -P $collectionUserPass -C -l 30 -W -m 1 -u -h-1 -w 32768 -v database="all")
        foreach ($databaseName in $dbNameArray) {
            WriteLog -logMessage "Adding collection user into the following databases:" -logOperation "MESSAGE"
            WriteLog -logMessage "            $databaseName" -logOperation "MESSAGE"
        }
        foreach ($databaseName in $dbNameArray) {
            sqlcmd -S $serverName -i sql\addCollectionUserToDatabase.sql -d $databaseName -U $user -P $pass -C -l 30 -m 1 -v collectionUser=$collectionUserName
        }
    }
}
else {
    $serverName = "$serverName,$port"
    WriteLog -logMessage "Creating collection user in $serverName, using PORT $port" -logOperation "MESSAGE"
    sqlcmd -S $serverName -i sql\createCollectionUser.sql -d master -U $user -P $pass -C -l 30 -m 1 -v collectionUser=$collectionUserName collectionPass=$collectionUserPass

    ### If Azure, need to get a list of databases from master and log in to each individually to create the user
    if ($isCloudOrLinuxHost -eq "AZURE") {
        $dbNameArray = @(sqlcmd -S $serverName -i sql\getDBList.sql -d master -U $collectionUserName -P $collectionUserPass -C -l 30 -W -m 1 -u -h-1 -w 32768 -v database="all")
        foreach ($databaseName in $dbNameArray) {
            WriteLog -logMessage "Adding collection user into the following databases:" -logOperation "MESSAGE"
            WriteLog -logMessage "            $databaseName" -logOperation "MESSAGE"
        }
        foreach ($databaseName in $dbNameArray) {
            sqlcmd -S $serverName -i sql\addCollectionUserToDatabase.sql -d $databaseName -U $user -P $pass -C -l 30 -m 1 -v collectionUser=$collectionUserName
        }
    }
}
