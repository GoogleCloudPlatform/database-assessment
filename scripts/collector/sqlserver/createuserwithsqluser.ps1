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
.PARAMETER user
    SqlServer superuser username (mandatory)
.PARAMETER pass
    SqlServer superuser password (mandatory)
.PARAMETER collectionUserName
    Collection username (optional)
.PARAMETER collectionUserPass
    Collection username password (optional)
.EXAMPLE
    To use a specific username / password combination:
        C:\createuserwithsqluser.ps1 -user [superuser] -pass [superuser password] -collectionUserName [collection username] -collectionUserPass [collection username password]
    
    or
    
    To use default credentials:
        C:\createuserwithsqluser.ps1 -user [superuser] -pass [superuser password]
.NOTES
    https://googlecloudplatform.github.io/database-assessment/
#>
Param(
[Parameter(Mandatory=$true)][string]$user,
[Parameter(Mandatory=$true)][string]$pass,
[Parameter(Mandatory=$false)][string]$collectionUserName="userfordma",
[Parameter(Mandatory=$false)][string]$collectionUserPass="P@ssword135"
)

$objs = Import-Csv -Delimiter "," sqlsrv.csv
foreach($item in $objs) {
    $sqlsrv = $item.InstanceName
	Write-Output "Creating Collection User in $sqlsrv"
	if ($sqlsrv -like "*MSSQLSERVER*") {
		sqlcmd -H $sqlsrv -i sql\prereq_createsa.sql -U $user -P $pass -m 1 -v collectionUser=$collectionUserName collectionPass=$collectionUserPass
	} else {
		sqlcmd -S $sqlsrv -i sql\prereq_createsa.sql -U $user -P $pass -m 1 -v collectionUser=$collectionUserName collectionPass=$collectionUserPass
	}
}