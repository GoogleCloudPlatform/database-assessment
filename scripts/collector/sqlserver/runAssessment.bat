::Copyright 2024 Google LLC
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
set port=default
set user=
set pass=false
set entraIDUser=
set manualUniqueId="NA"
set database=all
set noPerfmon=false
set collectVMSpecs=
set useWindowsAuthentication=false
set useEntraIDAuthentication=false
set outputDir=default

set helpMessage=Usage: runAssessment.bat -serverName [servername] -port [port number] -database [database name] -collectionUserName [username] -collectionUserPass [password] -ignorePerfmon [true/false] -manualUniqueId [unique tag to identify collection] [-collectVMSpecs] [-useWindowsAuthentication or -useEntraIDAuthentication] -outputDirectory [write zip file to different directory]
set helpExample=Example (default port): runAssessment.bat -serverName MS-SERVER1\SQL2019 -collectionUserName sa -collectionUserPass password123 -ignorePerfmon [true/false] -manualUniqueId mySQLServerDB1
set helpExamplePort=Example (specified port): runAssessment.bat -serverName MS-SERVER1 -port 1436 -collectionUserName sa -collectionUserPass password123 -ignorePerfmon [true/false] -manualUniqueId mySQLServerDB1
set helpExampleDatabase=Example (default port / single database): runAssessment.bat -serverName MS-SERVER1\SQL2019 -database AdventureWorks2019 -collectionUserName sa -collectionUserPass password123 -ignorePerfmon [true/false] -manualUniqueId mySQLServerDB1
set helpExampleDatabasePort=Example (specified port / single database): runAssessment.bat -serverName MS-SERVER1 -port 1436 -database AdventureWorks2019 -collectionUserName sa -collectionUserPass password123 -ignorePerfmon [true/false] -manualUniqueId mySQLServerDB1
set helpExampleCollectVMSpecs=Example (collect specs from host VM): runAssessment.bat -serverName MS-SERVER1\SQL2019 -collectionUserName sa -collectionUserPass password123 -ignorePerfmon [true/false] -manualUniqueId mySQLServerDB1 -collectVMSpecs
set helpUseWindowsAuth=Example (collect specs from host VM): runAssessment.bat -serverName MS-SERVER1\SQL2019 -collectionUserName sa -ignorePerfmon [true/false] -manualUniqueId mySQLServerDB1 -collectVMSpecs -useWindowsAuthentication
set helpUseEntraIDAuth=Example (Entra ID / Azure AD MFA): runAssessment.bat -serverName MI-SERVER.database.windows.net -ignorePerfmon [true/false] -manualUniqueId mySQLServerDB1 -useEntraIDAuthentication -entraIDUserName user@domain.com

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
if /i "%1" == "-entraIDUserName" set "entraIDUser=%2"
if /i "%1" == "-ignorePerfmon" set "noPerfmon=%2"
if /i "%1" == "-manualUniqueId" set "manualUniqueId=%2"
if /i "%1" == "-collectVMSpecs" set "collectVMSpecs=true"
if /i "%1" == "-useWindowsAuthentication" set "useWindowsAuthentication=true"
if /i "%1" == "-useEntraIDAuthentication" set "useEntraIDAuthentication=true"
if /i "%1" == "-useEntraIDAuth" set "useEntraIDAuthentication=true"
if /i "%1" == "/useEntraIDAuthentication" set "useEntraIDAuthentication=true"
if /i "%1" == "/useEntraIDAuth" set "useEntraIDAuthentication=true"
if /i "%1" == "-outputDirectory" set "outputDir=%2"

shift
goto :loop

:evaluateUser
if [%serverName%]==[] goto raiseServerError
if "%useEntraIDAuthentication%"=="true" goto execEntraID
if not [%manualUniqueId%]==[] (
   if not "%manualUniqueId%"=="%manualUniqueId: =%" goto raiseTagError
)
if not [%user%]==[] goto execWithCustomUser

:execWithCustomUser
if [%serverName%]==[] goto raiseServerError
if [%user%] == [] (
    if [%useWindowsAuthentication%]==[] goto error
)

if "%useWindowsAuthentication%"=="false" (
    if not [%user%]==[] (
        SET "command=PowerShell -nologo -NoProfile -ExecutionPolicy Bypass -File .\instanceReview.ps1 -serverName %serverName% -port %port% -database %database% -collectionUserName %user% -collectionUserPass %pass% -ignorePerfmon %noPerfmon% -manualUniqueId %manualUniqueId% -outputDirectory %outputDir%"
	) ELSE (
        goto error
    )
) ELSE (
    if not [%user%]==[] (
        SET "command=PowerShell -nologo -NoProfile -ExecutionPolicy Bypass -File .\instanceReview.ps1 -serverName %serverName% -port %port% -database %database% -collectionUserName %user% -collectionUserPass %pass% -ignorePerfmon %noPerfmon% -manualUniqueId %manualUniqueId% -useWindowsAuthentication -outputDirectory %outputDir%"
    ) ELSE (
        SET "command=PowerShell -nologo -NoProfile -ExecutionPolicy Bypass -File .\instanceReview.ps1 -serverName %serverName% -port %port% -database %database% -ignorePerfmon %noPerfmon% -manualUniqueId %manualUniqueId% -useWindowsAuthentication -outputDirectory %outputDir%"
    )
)

if "%collectVMSpecs%"=="" (
	CALL %command%
) ELSE (
	CALL %command% -collectVMSpecs
)

if %errorlevel% == 1 goto exit
goto done

:execEntraID
if "%useWindowsAuthentication%"=="true" goto raiseAuthConflictError
if not [%user%]==[] goto raiseEntraCredentialError
if not "%pass%"=="false" goto raiseEntraCredentialError
if [%entraIDUser%]==[] goto raiseEntraUserError
SET "command=PowerShell -nologo -NoProfile -ExecutionPolicy Bypass -File .\instanceReview.ps1 -serverName %serverName% -port %port% -database %database% -ignorePerfmon %noPerfmon% -manualUniqueId %manualUniqueId% -useEntraIDAuthentication -entraIDUserName %entraIDUser% -outputDirectory %outputDir%"
if "%collectVMSpecs%"=="" (
    CALL %command%
) ELSE (
    CALL %command% -collectVMSpecs
)
if %errorlevel% == 1 goto exit
goto done

:error
echo:
echo Please specify one authentication method: -collectionUserName, -useWindowsAuthentication, or -useEntraIDAuthentication.
goto exit

:raiseServerError
echo:
echo Please specify -serverName flag when invoking the script
echo Format: [server name or ip address]\[instance name] - for a Named Instance
echo Format: [server name or ip address] - for a Default Instance
goto exit

:raiseTagError
echo:
echo Please specify -manualUniqueId as a string with no spaces and no special characters
goto exit

:raiseEntraCredentialError
echo:
echo Do not specify -collectionUserName or -collectionUserPass with -useEntraIDAuthentication.
echo Microsoft Entra ID authentication uses sqlcmd -G -U and does not pass collection credentials.
goto exit

:raiseEntraUserError
echo:
echo Please specify -entraIDUserName with -useEntraIDAuthentication.
echo Example: -useEntraIDAuthentication -entraIDUserName user@domain.com
goto exit

:raiseAuthConflictError
echo:
echo Do not specify both -useWindowsAuthentication and -useEntraIDAuthentication.
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
echo %helpExampleCollectVMSpecs%
echo:
echo %helpUseWindowsAuth%
echo:
echo %helpUseEntraIDAuth%
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
echo Exit with Error Code 1
exit /B 1
