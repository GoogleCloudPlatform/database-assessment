::Copyright 2023 Google LLC
::
::Licensed under the Apache License, Version 2.0 (the "License");
::you may not use this file except in compliance with the License.
::You may obtain a copy of the License at
::
::    https://www.apache.org/licenses/LICENSE-2.0
::
::Unless required by applicable law or agreed to in writing, software
::distributed under the License is distributed on an "AS IS" BASIS,
::WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
::See the License for the specific language governing permissions and
::limitations under the License.

@echo off
set serverName=
set port=
set user=
set pass=
set database=all
set noPerfmon=false
set helpMessage=Usage: RunAssessment.bat -serverName [servername] -port [port number] -database [database name] -collectionUserName [username] -collectionUserPass [password]
set helpExample=Example (default port): RunAssessment.bat -serverName MS-SERVER1\SQL2019 -collectionUserName sa -collectionUserPass password123
set helpExamplePort=Example (specified port): RunAssessment.bat -serverName MS-SERVER1 -port 1436 -collectionUserName sa -collectionUserPass password123
set helpExampleDatabase=Example (default port / single database): RunAssessment.bat -serverName MS-SERVER1\SQL2019 -database AdventureWorks2019 -collectionUserName sa -collectionUserPass password123
set helpExampleDatabasePort=Example (specified port / single database): RunAssessment.bat -serverName MS-SERVER1 -port 1436 -database AdventureWorks2019 -collectionUserName sa -collectionUserPass password123

if [%1]==[] (
    goto helpOperation
)

if %1 == help (
    goto helpOperation
)

:loop 
if "%1" == "" goto evaluateUser
if /i "%1" == "-serverName" set "serverName=%2"
if /i "%1" == "-port" set "port=%2"
if /i "%1" == "-database" set "database=%2"
if /i "%1" == "-collectionUserName" set "user=%2"
if /i "%1" == "-collectionUserPass" set "pass=%2"
if /i "%1" == "-ignorePerfmon" set "noPerfmon=%2"

shift
goto :loop

:evaluateUser
if [%serverName%]==[] goto raiseServerError
if not [%user%]==[] goto execWithCustomUser

:execWithCustomUser
if [%serverName%]==[] goto raiseServerError
if [%user%] == [] goto error
if [%pass%] == [] goto error
echo Gathering Collection with Custom User

if [%port%] ==[] (
    PowerShell -nologo -NoProfile -ExecutionPolicy Bypass -File .\InstanceReview.ps1 -serverName %serverName% -database %database% -collectionUserName %user% -collectionUserPass %pass% -ignorePerfmon %noPerfmon%
) else (
    PowerShell -nologo -NoProfile -ExecutionPolicy Bypass -File .\InstanceReview.ps1 -serverName %serverName% -port %port% -database %database% -collectionUserName %user% -collectionUserPass %pass% -ignorePerfmon %noPerfmon%
)

if %errorlevel% == 1 goto exit
goto done

:error
echo Username or Password is not populated
echo Please specify [-collectionUserName and -collectionUserPass] when invoking the script
goto exit

:raiseServerError
echo Please specify -serverName flag when invoking the script
echo Format: [server name or ip address]\[instance name] - for a Named Instance
echo Format: [server name or ip address] - for a Default Instance
goto exit

:helpOperation
echo:
echo Help:
echo %helpMessage%
echo:
echo %helpExample%
echo:
echo %helpExamplePort%
echo:
echo %helpExampleDatabase%
echo:
echo %helpExampleDatabasePort%
echo:
goto done

:done
echo.
echo.
echo Script Complete.
exit /B 0

:exit
echo.
echo.
echo Exit with Error Code %ERRORLEVEL%
exit /B 1