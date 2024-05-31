/*
 Copyright 2024 Google LLC

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
select chr(34) || :PKEY || chr(34) as pkey,
  chr(34) || :DMA_SOURCE_ID || chr(34) as dma_source_id,
  chr(34) || :DMA_MANUAL_ID || chr(34) as dma_manual_id,
  chr(34) || application_name || chr(34) as application_name,
  count(*) as application_count
from pg_stat_activity
group by 1,
  2,
  3,
  4
