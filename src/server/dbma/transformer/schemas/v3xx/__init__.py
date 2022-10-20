# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
from pathlib import Path
from typing import Optional

from pydantic import Field

from dbma import log
from dbma.__version__ import __version__
from dbma.transformer.schemas.base import CollectionFiles as _CollectionFiles

logger = log.get_logger()


class CollectionFiles(_CollectionFiles):
    """Files that are expected to be in the v1 collection schema



    This filename mapper dictionary maps the attributes in `CollectionFiles` with a match string
     to use when mapping extracted files to the correct attribute.

    For instance, `top_sql`:`topsql`, sets the search string for the
     "Top SQL` attribute to "topsql".
     The matcher will find the closest match to this string when returning a filename
    """

    awr_hist_cmd_types: Path = Field(..., alias="awrhistcmdtypes")
    awr_hist_os_stat: Path = Field(..., alias="awrhistosstat")
    awr_hist_sys_metric_hist: Path = Field(..., alias="awrhistsysmetrichist")
    awr_hist_sys_metric_summary: Path = Field(..., alias="awrhistsysmetricsumm")
    awr_snap_details: Path = Field(..., alias="awrsnapdetails")
    db_compression_by_type: Path = Field(..., alias="compressbytype")
    db_cpu_core_usage: Path = Field(..., alias="cpucoresusage")
    db_dataguard: Path = Field(..., alias="dataguard")
    db_data_types: Path = Field(..., alias="datatypes")
    dba_hist_sys_stat: Path = Field(..., alias="dbahistsysstat")
    dba_hist_sys_time_model: Path = Field(..., alias="dbahistsystimemodel")
    db_features: Path = Field(..., alias="dbfeatures")
    db_high_water_stats: Path = Field(..., alias="dbhwmarkstatistics")
    db_instances: Path = Field(..., alias="dbinstances")
    db_links: Path = Field(..., alias="dblinks")
    db_objects: Path = Field(..., alias="dbobjects")
    db_parameters: Path = Field(..., alias="dbparameters")
    db_summary: Path = Field(..., alias="dbsummary")
    db_external_tables: Path = Field(..., alias="exttab")
    index_per_table: Path = Field(..., alias="idxpertable")
    index_types: Path = Field(..., alias="indexestypes")
    io_events: Path = Field(..., alias="ioevents")
    io_function: Path = Field(..., alias="iofunction")
    pdbs_info: Optional[Path] = Field(..., alias="pdbsinfo")
    pdbs_in_open_mode: Optional[Path] = Field(..., alias="pdbsopenmode")
    db_source_code: Path = Field(..., alias="sourcecode")
    db_source_connections: Path = Field(..., alias="sourceconn")
    db_sql_stats: Path = Field(..., alias="sqlstats")
    db_constraint_summary: Path = Field(..., alias="tablesnopk")
    db_used_space_details: Path = Field(..., alias="usedspacedetails")
    db_user_tablespace_segments: Path = Field(..., alias="usrsegatt")
    # key_log: Optional[Path] = Field(..., alias="opkeylog")
    _delimiter = "|"
