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
set user=
set pass=
set defaultUsr=0

:loop 
if "%1" == "" goto evaluateUser
if /i "%1" == "-username" set "user=%2"
if /i "%1" == "-password" set "pass=%2"
if /i "%1" == "-useDefaultCreds" set "defaultUsr=1"

shift
goto :loop

:evaluateUser
if not [%user%]==[] goto execWithCustomUser
if "%defaultUsr%"=="0" goto defaultCredError
if "%defaultUsr%"=="1" goto execWithDefaultUser

:execWithDefaultUser
echo "Gathering Collection with Default User"
PowerShell -nologo -NoProfile -ExecutionPolicy Bypass -File ".\InstanceReview.ps1"
goto done

:execWithCustomUser
if [%user%] == [] goto error
if [%pass%] == [] goto error
echo "Gathering Collection with Custom User"
PowerShell -nologo -NoProfile -ExecutionPolicy Bypass -File .\InstanceReview.ps1 -user %user% -pass %pass%

goto done

:error
echo "Username or Password is not populated"
goto done

:defaultCredError
echo "Please specify -useDefaultCreds flag when invoking the script"
goto done

:done
echo.
echo.
echo Script Complete!