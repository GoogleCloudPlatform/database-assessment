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
set perfmonOperation=
set mssqlInstanceName=

:loop 
if "%1" == "" goto evaluateOperation
if /i "%1" == "-operation" set "perfmonOperation=%2"
if /i "%1" == "-mssqlInstanceName" set "perfmonInstance=%2"

shift
goto :loop

:evaluateOperation
if [%perfmonOperation%]==[] goto error
if not [%perfmonOperation%]==[] goto execPerfmonOperation

:execPerfmonOperation
if [%perfmonInstance%] == [] goto execPerfmonDefaultInstance
if not [%perfmonInstance%] == [] goto execPerfmonNamedInstance

:execPerfmonDefaultInstance
echo "Managing Perfmon Collection for Default Instance"
PowerShell -nologo -NoProfile -ExecutionPolicy Bypass -File .\dma_sqlserver_perfmon_dataset.ps1 -operation %perfmonOperation%

goto done

:execPerfmonNamedInstance
if [%perfmonInstance%] == [] goto defaultNamedInstanceError
echo "Managing Perfmon Collection for Named Instance %perfmonInstance%"
PowerShell -nologo -NoProfile -ExecutionPolicy Bypass -File .\dma_sqlserver_perfmon_dataset.ps1 -operation %perfmonOperation% -mssqlInstanceName %perfmonInstance%

goto done

:error
echo "Operation parameter is not populated"
goto done

:defaultNamedInstanceError
echo "Named Instance not properly specified"
goto done

:done
echo Script Complete!