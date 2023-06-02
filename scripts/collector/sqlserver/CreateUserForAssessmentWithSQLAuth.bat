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
set defaultCreds=0

:loop 
if "%1" == "" goto evaluateUser
if /i "%1" == "-serverName" set "serverName=%2"
if /i "%1" == "-serverUserName" set "saUser=%2"
if /i "%1" == "-serverUserPass" set "saPass=%2"
if /i "%1" == "-collectionUserName" set "user=%2"
if /i "%1" == "-CollectionUserPass" set "pass=%2"
if /i "%1" == "-useDefaultCreds" set "defaultCreds=1"

set helpMessage="Usage: .\CreateUserForAssessmentWithSQLAuth.bat -serverName -serverUserName -serverUserPass -useDefaultCreds/(-collectionUserName -collectionUserPass)"

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
if "%defaultCreds%"=="0" goto defaultCredError
if "%defaultCreds%"=="1" goto execWithDefaultCreds

:execWithDefaultCreds
if [%serverName%]==[] goto raiseServerError
echo "Creating Collection User with Default Credentials"
PowerShell -nologo -NoProfile -ExecutionPolicy Bypass -File .\createuserwithsqluser.ps1 -serverName %serverName% -user %saUser% -pass %saPass%
if %errorlevel% == 1 goto exit
goto done

:execWithCustomCreds
if [%user%] == [] goto error
if [%pass%] == [] goto error
if [%serverName%]==[] goto raiseServerError
echo "Creating Collection User with Custom Credentials"
PowerShell -nologo -NoProfile -ExecutionPolicy Bypass -File .\createuserwithsqluser.ps1 -serverName %serverName% -user %saUser% -pass %saPass% -collectionUserName %user% -CollectionUserPass %pass%
if %errorlevel% == 1 goto exit
goto done

:error
echo Username or Password is not populated
echo Please specify -useDefaultCreds flag or [-username and -password] when invoking the script
goto exit

:defaultCredError
echo Please specify -useDefaultCreds flag when invoking the script
echo Please specify -useDefaultCreds flag or [-username and -password] when invoking the script
goto exit

:raiseServerError
echo Please specify -serverName flag when invoking the script
echo Format: [server name / ip address]\[instance name]
goto exit

:done
echo Script Complete.
exit /B 0

:exit
echo Exit
exit /B 1