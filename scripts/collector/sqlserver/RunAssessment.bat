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
if /i "%1" == "-serverName" set "serverName=%2"
if /i "%1" == "-collectionUserName" set "user=%2"
if /i "%1" == "-collectionUserPass" set "pass=%2"
if /i "%1" == "-useDefaultCreds" set "defaultUsr=1"

set helpMessage="Usage: RunAssessment.bat (-serverName [servername] -collectionUserName [username] -collectionUserPass [password]) or -serverName [servername] -useDefaultCreds"

if %1 == help (
    echo %helpMessage%
    goto done
)

shift
goto :loop

:evaluateUser
if [%serverName%]==[] goto raiseServerError
if not [%user%]==[] goto execWithCustomUser
if "%defaultUsr%"=="0" goto defaultCredError
if "%defaultUsr%"=="1" goto execWithDefaultUser

:execWithDefaultUser
echo Gathering Collection with Default User
PowerShell -nologo -NoProfile -ExecutionPolicy Bypass -File .\InstanceReview.ps1 -serverName %serverName%
if %errorlevel% == 1 goto exit
goto done

:execWithCustomUser
if [%serverName%]==[] goto raiseServerError
if [%user%] == [] goto error
if [%pass%] == [] goto error
echo Gathering Collection with Custom User
PowerShell -nologo -NoProfile -ExecutionPolicy Bypass -File .\InstanceReview.ps1 -serverName %serverName% -collectionUserName %user% -collectionUserPass %pass%
if %errorlevel% == 1 goto exit
goto done

:error
echo Username or Password is not populated
echo Please specify -useDefaultCreds flag or [-username and -password] when invoking the script
goto exit

:defaultCredError
echo Please specify -useDefaultCreds flag or [-username and -password] when invoking the script
goto exit

:raiseServerError
echo Please specify -serverName flag when invoking the script
echo Format: [server name or ip address]\[instance name]
goto exit

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