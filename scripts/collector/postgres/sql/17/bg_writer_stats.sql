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
with src as (
  select c.num_timed as checkpoints_timed,
    c.num_requested as checkpoints_requested,
    c.write_time as checkpoint_write_time,
    c.sync_time as checkpoint_sync_time,
    c.buffers_written as buffers_checkpoint,
    w.buffers_clean,
    w.maxwritten_clean as max_written_clean,
    NULL as buffers_backend,
    NULL as buffers_backend_fsync,
    w.buffers_alloc as buffers_allocated,
    w.stats_reset
  from pg_stat_bgwriter w
  join pg_stat_checkpointer c ON 1=1 -- These are both single-row views
)
select chr(34) || :PKEY || chr(34) as pkey,
  chr(34) || :DMA_SOURCE_ID || chr(34) as dma_source_id,
  chr(34) || :DMA_MANUAL_ID || chr(34) as dma_manual_id,
  src.checkpoints_timed,
  src.checkpoints_requested,
  src.checkpoint_write_time,
  src.checkpoint_sync_time,
  src.buffers_checkpoint,
  src.buffers_clean,
  src.max_written_clean,
  src.buffers_backend,
  src.buffers_backend_fsync,
  src.buffers_allocated,
  src.stats_reset
from src;
