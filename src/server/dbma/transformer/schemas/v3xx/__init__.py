from pathlib import Path
from typing import Optional

from dbma import log
from dbma.__version__ import __version__
from dbma.transformer.schemas.base import AdvisorExtractFiles

logger = log.get_logger()


class CollectionSchema(AdvisorExtractFiles):
    """Files that are expected to be in the v1 collection schema



    This filename mapper dictionary maps the attributes in `CollectionSchema` with a match string
     to use when mapping extracted files to the correct attribute.

    For instance, `top_sql`:`topsql`, sets the search string for the
     "Top SQL` attribute to "topsql".
     The matcher will find the closest match to this string when returning a filename
    """

    awr_hist_cmd_types: Path
    awr_hist_os_stat: Path
    awr_hist_sys_metric_hist: Path
    awr_hist_sys_metric_summary: Path
    awr_snap_details: Path
    db_compression_by_type: Path
    db_cpu_core_usage: Path
    db_dataguard: Path
    db_data_types: Path
    dba_hist_sys_stat: Path
    dba_hist_sys_time_model: Path
    db_features: Path
    db_high_water_stats: Path
    db_instances: Path
    db_links: Path
    db_objects: Path
    db_parameters: Path
    db_summary: Path
    db_external_tables: Path
    index_per_table: Path
    index_types: Path
    io_events: Path
    io_function: Path
    pdbs_info: Path
    pdbs_in_open_mode: Path
    db_source_code: Path
    db_source_connections: Path
    db_sql_stats: Path
    db_constraint_summary: Path
    db_used_space_details: Path
    db_user_tablespace_segments: Path
    # key_log: Optional[Path]
    _delimiter = "|"
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
        # "key_log": "opdb__opkeylog__",
        "pdbs_info": "opdb__pdbsinfo__",
        "pdbs_in_open_mode": "opdb__pdbsopenmode__",
        "db_source_code": "opdb__sourcecode__",
        "db_source_connections": "opdb__sourceconn__",
        "db_sql_stats": "opdb__sqlstats__",
        "db_constraint_summary": "opdb__tablesnopk__",
        "db_used_space_details": "opdb__usedspacedetails__",
        "db_user_tablespace_segments": "opdb__usrsegatt__",
    }
    """
    This dictionary maps the filenames to their respective columns.

    This allows us to decouple the file naming conventions from our Python code.
    The key of the dict is a attribute in your collection, and the value is a search string to use for identifying files
    """
