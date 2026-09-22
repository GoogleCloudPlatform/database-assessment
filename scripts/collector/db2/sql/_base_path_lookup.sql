-- Copyright 2024 Google LLC
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     https://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

-- Determines base path (luw vs zos) based on DB2 platform detection
SELECT CASE 
  WHEN service_level LIKE 'DB2/z%' OR service_level LIKE 'DSN%' THEN 'zos'
  ELSE 'luw'
END AS SCRIPT_PATH
FROM TABLE(SYSPROC.ENV_GET_INST_INFO())
FETCH FIRST 1 ROWS ONLY;
