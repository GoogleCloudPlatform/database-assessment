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
set defaultCreds=0

:loop 
if "%1" == "" goto evaluateUser
if /i "%1" == "-collectionUserName" set "user=%2"
if /i "%1" == "-CollectionUserPass" set "pass=%2"
if /i "%1" == "-useDefaultCreds" set "defaultCreds=1"

if %1 == help (
    echo "Usage: CreateUserForAssessmentWithWindowsAuth.bat (-collectionUserName -collectionUserPass)/-useDefaultCreds"
    goto done
)

shift
goto :loop

:evaluateUser
if not [%user%]==[] goto execWithCustomCreds
if "%defaultCreds%"=="0" goto defaultCredError
if "%defaultCreds%"=="1" goto execWithDefaultCreds

:execWithDefaultCreds
echo "Creating Collection User with Default Credentials"
PowerShell -nologo -NoProfile -ExecutionPolicy Bypass -File .\createuserwithwindowsauth.ps1
goto done

:execWithCustomCreds
if [%user%] == [] goto error
if [%pass%] == [] goto error
echo "Creating Collection User with Custom Credentials"
PowerShell -nologo -NoProfile -ExecutionPolicy Bypass -File .\createuserwithwindowsauth.ps1 -collectionUserName %user% -CollectionUserPass %pass%

goto done

:error
echo "Username or Password is not populated"
goto done

:defaultCredError
echo "Please specify -useDefaultCreds flag when invoking the script"
goto done

:done
echo Script Complete!