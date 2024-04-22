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
column default_value format a255
spool &outputdir/opdb__dbparameters__&v_tag
prompt PKEY|INST_ID|CON_ID|NAME|VALUE|DEFAULT_VALUE|ISDEFAULT|DMA_SOURCE_ID|DMA_MANUAL_ID

WITH vparam AS (
SELECT :v_pkey AS pkey,
       inst_id,
       &v_a_con_id AS con_id,
       replace(name, chr(39), chr(34))   name,
       TRANSLATE(SUBSTR(value, 1, 60), chr(124)||chr(10)||chr(13)||chr(39), ' ')         value,
       TRANSLATE(SUBSTR(&v_dbparam_dflt_col, 1, 30), chr(124)||chr(10)||chr(13)||chr(39), ' ')  default_value,
       isdefault
FROM   gv$system_parameter a
ORDER  BY 2,3 )
SELECT pkey , inst_id , con_id , name , value , default_value , isdefault,
       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM vparam;
spool off
column default_value clear
