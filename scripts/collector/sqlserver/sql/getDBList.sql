/*
 Copyright 2023 Google LLC
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 https://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 
 */
set NOCOUNT on;

set LANGUAGE us_english;

declare @ASSESSMENT_DATABSE_NAME as VARCHAR(256)
select @ASSESSMENT_DATABSE_NAME = N'$(database)';

if @ASSESSMENT_DATABSE_NAME = 'all'
select @ASSESSMENT_DATABSE_NAME = '%'
select name
from sys.databases
where name not in (
        'master',
        'model',
        'msdb',
        'distribution',
        'reportserver',
        'reportservertempdb',
        'resource',
        'rdsadmin',
        'SSISDB',
        'DWDiagnostics',
        'DWConfiguration',
        'DWQueue',
        'DQS_STAGING_DATA'
    )
    and name like @ASSESSMENT_DATABSE_NAME
    and state = 0
