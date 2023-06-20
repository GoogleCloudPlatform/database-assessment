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

set helpMessage=Usage ManageSqlServerPerfmonDataset.bat -operation [create/update/delete/collect/help] -instanceType [managed/default] -managmanagedInstanceName [instance name]
set helpExample=Example: .\ManageSqlServerPerfmonDataset.bat -operation create -instanceType default or .\ManageSqlServerPerfmonDataset.bat -operation create -instanceType managed -managedInstanceName SQL2019

if [%1]==[] (
	echo:
	echo Help:
    echo %helpMessage%
	echo:
    echo %helpExample%
    goto exit
)

if %1 == help (
	echo:
	echo Help:
    echo %helpMessage%
	echo:
    echo %helpExample%
    goto done
)

:loop 
if "%1" == "" goto runAssessmentOperation
if /i "%1" == "-operation" set "perfmonOperation=%2"
if /i "%1" == "-instanceType" set "instance=%2"
if /i "%1" == "-managedInstanceName" set "managedInstanceName=%2"

set isValidPerfmonOperation=false

:runAssessmentOperation
if %perfmonOperation%==help (
	echo:
	echo Help:
    echo %helpMessage%
	echo:
    echo %helpExample%
    goto exit
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
    echo %perfmonOperation% is not a valid perfmon Operation, allowed arguments are %validPerfmonOperations%
    goto exit
)

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
    echo %instance% is not a valid Instance type, allowed arguments are %validInstances%
    goto exit
)

echo %instance%
echo %isValidInstance%
if %instance%==managed (
    if [%managedInstanceName%]==[]  (
        echo Please pass a valid instanceName
        goto exit
    )
)

echo %managedInstanceName%

if %instance%==default (
    echo Managing Perfmon Collection for Default Instance
    PowerShell -nologo -NoProfile -ExecutionPolicy Bypass -File .\dma_sqlserver_perfmon_dataset.ps1 -operation %perfmonOperation%

    goto done
)

if %instance%==managed (
    echo Managing Perfmon Collection for Default Instance
    PowerShell -nologo -NoProfile -ExecutionPolicy Bypass -File .\dma_sqlserver_perfmon_dataset.ps1 -operation %perfmonOperation% -mssqlInstanceName %managedInstanceName%

    goto done
)

:done
echo Script Complete
exit /B 0

:exit
echo Exit
exit /B 1