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
set user=
set pass=
set saUser=
set saPass=
set serverName=
set port=default

:loop
if "%1" == "" goto evaluateUser
if /i "%1" == "-serverName" set "serverName=%2"
if /i "%1" == "-port" set "port=%2"
if /i "%1" == "-serverUserName" set "saUser=%2"
if /i "%1" == "-serverUserPass" set "saPass=%2"
if /i "%1" == "-collectionUserName" set "user=%2"
if /i "%1" == "-collectionUserPass" set "pass=%2"

set helpMessage=Usage: .\createUserForAssessmentWithSQLAuth.bat -serverName [servername] -port [port number] -serverUserName [existing admin username] -serverUserPass [existing admin password] -collectionUserName [username] -collectionUserPass [password]

if %1 == help (
    echo %helpMessage%
    goto done
)

shift
goto :loop

:evaluateUser
if [%serverName%]==[] goto raiseServerError
if [%saUser%]==[] goto serverUserError
if [%user%]==[] goto error
if not [%user%]==[] goto execWithCustomCreds

:execWithCustomCreds
if [%user%] == [] goto error
if [%saPass%] == [] goto execWithoutSaPass
if [%pass%] == [] goto execWithoutCollectionPass
if [%serverName%]==[] goto raiseServerError

PowerShell -nologo -NoProfile -ExecutionPolicy Bypass -File .\createUserWithSQLAuth.ps1 -serverName %serverName% -port %port% -user %saUser% -pass %saPass% -collectionUserName %user% -collectionUserPass %pass%
if %errorlevel% == 1 goto exit
goto done

:execWithoutCollectionPass
if [%saPass%]==[] (PowerShell -nologo -NoProfile -ExecutionPolicy Bypass -File .\createUserWithSQLAuth.ps1 -serverName %serverName% -port %port% -user %saUser% -collectionUserName %user%) else (PowerShell -nologo -NoProfile -ExecutionPolicy Bypass -File .\createUserWithSQLAuth.ps1 -serverName %serverName% -port %port% -user %saUser% -pass %saPass% -collectionUserName %user%)
if %errorlevel% == 1 goto exit
goto done

:execWithoutSaPass
if [%pass%]==[] (PowerShell -nologo -NoProfile -ExecutionPolicy Bypass -File .\createUserWithSQLAuth.ps1 -serverName %serverName% -port %port% -user %saUser% -collectionUserName %user%) else (PowerShell -nologo -NoProfile -ExecutionPolicy Bypass -File .\createUserWithSQLAuth.ps1 -serverName %serverName% -port %port% -user %saUser% -collectionUserName %user% -collectionUserPass %pass%)
if %errorlevel% == 1 goto exit
goto done

:serverUserError
echo serverUserName or serverUserPass is not populated
echo Please specify [-serverUserName and -serverUserPass] when invoking the script
goto exit

:error
echo Username or Password is not populated
echo Please specify [-collectionUserName and -collectionUserPass] when invoking the script
goto exit

:raiseServerError
echo Please specify -serverName flag when invoking the script
echo Format: [server name or ip address]\[instance name] - for a Named Instance
echo Format: [server name or ip address] - for a Default Instance
goto exit

:done
echo Script Complete.
exit /B 0

:exit
echo Exit
exit /B 1
