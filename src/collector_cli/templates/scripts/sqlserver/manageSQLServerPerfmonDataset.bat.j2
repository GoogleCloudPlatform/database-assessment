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

set validPerfmonOperations=create start stop delete collect createemptyfile help
set validInstances=default named
set isValidPerfmonOperation=false
set isValidInstance=false


set perfmonOperation=""
set instance=""
set namedInstanceName=
set duration="1152"
set sampleInterval="600"

set helpMessage=Usage manageSQLServerPerfmonDataset.bat -operation [create/start/stop/delete/collect/createemptyfile/help] -instanceType [default/named] -namedInstanceName [instance name] -sampleDuration [number of sample intervals] -sampleInterval [seconds between samples]
set helpExample=Example: .\manageSQLServerPerfmonDataset.bat -operation create -instanceType default or .\manageSQLServerPerfmonDataset.bat -operation create -instanceType named -namedInstanceName SQL2019 -sampleDuration 1152 -sampleInterval 600

if [%1]==[] (
    goto helpOperation
)

:loop
if /i "%1" == "-operation" set "perfmonOperation=%2"
if /i "%1" == "-instanceType" set "instance=%2"
if /i "%1" == "-namedInstanceName" set "namedInstanceName=%2"
if /i "%1" == "-sampleDuration" set "duration=%2"
if /i "%1" == "-sampleInterval" set "sampleInterval=%2"
if /i "%1" == "help" goto helpOperation
if "%1" == "" goto runAssessmentOperation

shift
goto :loop

:runAssessmentOperation

echo perfmonOperation is %perfmonOperation%
echo instance is %instance%
echo namedInstanceName is %namedInstanceName%

if %perfmonOperation%==help (
    goto helpOperation
)


rem check passed options for PerfmonOperation
(for %%a in (%validPerfmonOperations%) do (
    ::echo %%a
    if %perfmonOperation%==%%a (
       :: echo "Operation match %%a"
        set isValidPerfmonOperation=true
    )
))

if %isValidPerfmonOperation%==false (
    echo %perfmonOperation% is not a valid option for parameter -operation, allowed arguments are %validPerfmonOperations%
    goto exit
)

rem check passed options for instanceType
(for %%a in (%validInstances%) do (
    ::echo %%a
    if %instance%==%%a (
        :: echo "Operation match %%a"
        set isValidInstance=true
    )
))

if %isValidInstance%==false (
    echo %instance% is not a valid option for parameter -instanceType, allowed arguments are %validInstances%
    goto exit
)

if %instance%==named (
    if [%namedInstanceName%]==[] (
        echo Please pass a valid entry for parameter -namedInstanceName
        goto exit
    )
)

if %instance%==default (
    echo Managing Perfmon Collection for Default Instance
    PowerShell -nologo -NoProfile -ExecutionPolicy Bypass -File .\dmaSQLServerPerfmonDataset.ps1 -operation %perfmonOperation% -perfmonDuration %duration% -perfmonSampleInterval %sampleInterval%

    goto done
)

if %instance%==named (
    echo Managing Perfmon Collection for named Instance %namedInstanceName%
    PowerShell -nologo -NoProfile -ExecutionPolicy Bypass -File .\dmaSQLServerPerfmonDataset.ps1 -operation %perfmonOperation% -namedInstanceName %namedInstanceName% -perfmonDuration %duration% -perfmonSampleInterval %sampleInterval%

    goto done
)

:helpOperation
echo:
echo Help:
echo %helpMessage%
echo:
echo %helpExample%
goto done

:done
echo Script Complete
exit /B 0

:exit
echo Exit
exit /B 1
