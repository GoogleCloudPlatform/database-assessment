:: Copyright 2023 Google LLC
::
:: Licensed under the Apache License, Version 2.0 (the "License");
:: you may not use this file except in compliance with the License.
:: You may obtain a copy of the License at
::
::     https://www.apache.org/licenses/LICENSE-2.0
::
:: Unless required by applicable law or agreed to in writing, software
:: distributed under the License is distributed on an "AS IS" BASIS,
:: WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
:: See the License for the specific language governing permissions and
:: limitations under the License.

@echo off

set validPerfmonOperations=create stop delete collect
set validInstances=default managed

set perfmonOperation=%1
set instance=%2
set managedInstanceName=%3

set isValidPerfmonOperation=false

if %perfmonOperation%==help (
    echo "Usage: ManageSqlServerPerfmonDataset.bat create/update/delete/collect managed/default [InstanceName]"
    goto done
)

rem check passed options for PerfmonOperation
(for %%a in (%validPerfmonOperations%) do (
    :: echo %%a
    if %perfmonOperation%==%%a (
       :: echo "Operation match %%a"
        set isValidPerfmonOperation=true
    )
))

if %isValidPerfmonOperation%==false (
    echo %perfmonOperation% is not a valid perfmonOperation, allowed are %validPerfmonOperations%
    goto done
)

echo %perfmonOperation%
echo %isValidPerfmonOperation%

set isValidInstance=false
rem check passed options for PerfmonOperation
(for %%a in (%validInstances%) do (
    :: echo %%a
    if %instance%==%%a (
        :: echo "Operation match %%a"
        set isValidInstance=true
    )
))

if %isValidInstance%==false (
    echo %instance% is not a valid Instance type, allowed are %validInstances%
    goto done
)

echo %instance%
echo %isValidInstance%
if %instance%==managed (
    if [%managedInstanceName%]==[]  (
        echo Please pass a valid instanceName
        goto done
    )
)

echo %managedInstanceName%

if %instance%==default (
    echo "Managing Perfmon Collection for Default Instance"
    PowerShell -nologo -NoProfile -ExecutionPolicy Bypass -File .\dma_sqlserver_perfmon_dataset.ps1 -operation %perfmonOperation%

    goto done
)

if %instance%==managed (
    echo "Managing Perfmon Collection for Default Instance"
    PowerShell -nologo -NoProfile -ExecutionPolicy Bypass -File .\dma_sqlserver_perfmon_dataset.ps1 -operation %perfmonOperation% -mssqlInstanceName %managedInstanceName%

    goto done
)

:done
echo Script Complete!