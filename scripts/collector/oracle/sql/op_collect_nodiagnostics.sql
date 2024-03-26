/*
Copyright 2022 Google LLC

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
set termout on
Prompt Skipping collection of statstics requiring the Oracle Diagnostics Pack license.
Prompt Will use STATSPACK data if available...
set termout &TERMOUTOFF

PROMPT Running script &p_sp_script for STATSPACK

@&SQLDIR/&p_sp_script
