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

:loop 
if "%1" == "" goto evaluateUser
if /i "%1" == "-serverName" set "serverName=%2"
if /i "%1" == "-serverUserName" set "saUser=%2"
if /i "%1" == "-serverUserPass" set "saPass=%2"
if /i "%1" == "-collectionUserName" set "user=%2"
if /i "%1" == "-collectionUserPass" set "pass=%2"

set helpMessage=Usage: .\CreateUserForAssessmentWithSQLAuth.bat -serverName [servername] -serverUserName [existing admin username] -serverUserPass [existing admin password] -collectionUserName [username] -collectionUserPass [password]

if %1 == help (
    echo %helpMessage%
    goto done
)

shift
goto :loop

:evaluateUser
if [%serverName%]==[] goto raiseServerError
if [%saUser%]==[] goto error
if [%saPass%]==[] goto error
if not [%user%]==[] goto execWithCustomCreds

:execWithCustomCreds
if [%user%] == [] goto error
if [%pass%] == [] goto error
if [%serverName%]==[] goto raiseServerError
echo "Creating Collection User with Custom Credentials"
PowerShell -nologo -NoProfile -ExecutionPolicy Bypass -File .\createuserwithsqluser.ps1 -serverName %serverName% -user %saUser% -pass %saPass% -collectionUserName %user% -collectionUserPass %pass%
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

:done
echo Script Complete.
exit /B 0

:exit
echo Exit
exit /B 1