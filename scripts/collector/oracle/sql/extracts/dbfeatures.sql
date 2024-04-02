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
spool &outputdir/opdb__dbfeatures__&v_tag
prompt PKEY|CON_ID|NAME|CURRE|DETECTED_USAGES|TOTAL_SAMPLES|FIRST_USAGE|LAST_USAGE|AUX_COUNT|DMA_SOURCE_ID|DMA_MANUAL_ID
WITH vdbf AS(
SELECT :v_pkey AS pkey,
       &v_a_con_id AS con_id,
       REPLACE(name, ',', '/')                       name,
       currently_used,
       detected_usages,
       total_samples,
       TO_CHAR(first_usage_date, 'MM/DD/YY HH24:MI') first_usage,
       TO_CHAR(last_usage_date, 'MM/DD/YY HH24:MI')  last_usage,
       aux_count
FROM   &v_tblprefix._feature_usage_statistics a
WHERE dbid = &&v_dbid
ORDER  BY name)
SELECT pkey , con_id , name , currently_used , detected_usages ,
       total_samples , first_usage , last_usage , aux_count,
       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM vdbf;
spool off
