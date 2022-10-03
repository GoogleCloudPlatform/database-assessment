from typing import Optional

from dbma import log
from dbma.__version__ import __version__
from dbma.transformer.schemas.base import BaseCollection

logger = log.get_logger()


class CollectionSchema(BaseCollection):
    """Files that are expected to be in the v1 collection schema



    This filename mapper dictionary maps the attributes in `CollectionSchema` with a match string
     to use when mapping extracted files to the correct attribute.

    For instance, `top_sql`:`topsql`, sets the search string for the
     "Top SQL` attribute to "topsql".
     The matcher will find the closest match to this string when returning a filename
    """

    awr_hist_cmd_types: str
    awr_hist_os_stat: str
    awr_hist_sys_metric_hist: str
    awr_hist_sys_metric_summary: str
    awr_snap_details: str
    db_compression_by_type: str
    db_cpu_core_usage: str
    db_dataguard: str
    db_data_types: str
    dba_hist_sys_stat: str
    dba_hist_sys_time_model: str
    db_features: str
    db_high_water_stats: str
    db_instances: str
    db_links: str
    db_objects: str
    db_parameters: str
    db_summary: str
    db_external_tables: str
    index_per_table: str
    index_types: str
    io_events: str
    io_function: str
    pdbs_info: str
    pdbs_in_open_mode: str
    db_source_code: str
    db_source_connections: str
    db_sql_stats: str
    db_constraint_summary: str
    db_used_space_details: str
    db_user_tablespace_segments: str
    key_log: Optional[str]

    _file_mapper = {
        "awr_hist_cmd_types": "opdb__awrhistcmdtypes__",
        "awr_hist_os_stat": "opdb__awrhistosstat__",
        "awr_hist_sys_metric_hist": "opdb__awrhistsysmetrichist__",
        "awr_hist_sys_metric_summary": "opdb__awrhistsysmetricsumm__",
        "awr_snap_details": "opdb__awrsnapdetails__",
        "db_compression_by_type": "opdb__compressbytype__",
        "db_cpu_core_usage": "opdb__cpucoresusage__",
        "db_dataguard": "opdb__dataguard__",
        "db_data_types": "opdb__datatypes__",
        "dba_hist_sys_stat": "opdb__dbahistsysstat__",
        "dba_hist_sys_time_model": "opdb__dbahistsystimemodel__",
        "db_features": "opdb__dbfeatures__",
        "db_high_water_stats": "opdb__dbhwmarkstatistics__",
        "db_instances": "opdb__dbinstances__",
        "db_links": "opdb__dblinks__",
        "db_objects": "opdb__dbobjects__",
        "db_parameters": "opdb__dbparameters__",
        "db_summary": "opdb__dbsummary__",
        "db_external_tables": "opdb__exttab__",
        "index_per_table": "opdb__idxpertable__",
        "index_types": "opdb__indexestypes__",
        "io_events": "opdb__ioevents__",
        "io_function": "opdb__iofunction__",
        "key_log": "opdb__opkeylog__",
        "pdbs_info": "opdb__pdbsinfo__",
        "pdbs_in_open_mode": "opdb__pdbsopenmode__",
        "db_source_code": "opdb__sourcecode__",
        "db_source_connections": "opdb__sourceconn__",
        "db_sql_stats": "opdb__sqlstats__",
        "db_constraint_summary": "opdb__tablesnopk__",
        "db_used_space_details": "opdb__usedspacedetails__",
        "db_user_tablespace_segments": "opdb__usrsegatt__",
    }
