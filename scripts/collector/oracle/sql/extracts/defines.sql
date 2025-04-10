--
-- Copyright 2025 Google LLC
--
-- Licensed under the Apache License, Version 2.0 (the "License").
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
--
spool &outputdir./opdb__allvars__&s_tag.

PROMPT "SUBSTITUTION VARIABLES"
PROMPT AWRDIR                        = &AWRDIR.
PROMPT EXTRACTSDIR                   = extracts
PROMPT SQLDIR                        = &SQLDIR.
PROMPT STATSPACKDIR                  = &STATSPACKDIR.
PROMPT TERMOUTOFF                    = &TERMOUTOFF.
PROMPT dmaVersion                    = &dmaVersion.
PROMPT p_sp_script                   = &p_sp_script.
PROMPT p_statsWindow                 = &p_statsWindow.
PROMPT s_a_con_id                    = &s_a_con_id.
PROMPT s_b_con_id                    = &s_b_con_id.
PROMPT s_c_con_id                    = &s_c_con_id.
-- PROMPT s_app_join_cond               ='&s_app_join_cond.'
-- PROMPT s_app_join_dbsum_cond         ='&s_app_join_dbsum_cond.'
PROMPT s_cdb_join_cond               = &s_cdb_join_cond.
PROMPT s_compress_col                = &s_compress_col.
PROMPT s_d_con_id                    = &s_d_con_id.
PROMPT s_db_container_col            = &s_db_container_col.
PROMPT s_db_unique_name              = &s_db_unique_name.
PROMPT s_dbid                        = &s_dbid.
--PROMPT s_dbname                      = &s_dbname.
PROMPT s_dbparam_dflt_col            = &s_dbparam_dflt_col.
--PROMPT s_dbversion                   = &s_dbversion.
PROMPT s_dg_valid_role               = &s_dg_valid_role.
PROMPT s_dg_verify                   = &s_dg_verify.
PROMPT s_editionable_col             = &s_editionable_col.
PROMPT s_h_con_id                    = &s_h_con_id.
--PROMPT s_hora                        = &s_hora.
--PROMPT s_host                        = &s_host.
PROMPT s_index_visibility            = &s_index_visibility.
PROMPT s_info_prompt                 = &s_info_prompt.
--PROMPT s_inst                        = &s_inst.
PROMPT s_is_container                = &s_is_container.
PROMPT s_lob_compression_col         = &s_lob_compression_col.
PROMPT s_lob_dedup_col               = &s_lob_dedup_col.
PROMPT s_lob_part_compression_col    = &s_lob_part_compression_col.
PROMPT s_lob_part_dedup_col          = &s_lob_part_dedup_col.
PROMPT s_lob_subpart_compression_col = &s_lob_subpart_compression_col.
PROMPT s_lob_subpart_dedup_col       = &s_lob_subpart_dedup_col.
PROMPT s_manualUniqueId              = &s_manualUniqueId.
PROMPT s_max_snapid                  = &s_max_snapid.
PROMPT s_max_snaptime                = &s_max_snaptime.
PROMPT s_min_snapid                  = &s_min_snapid.
PROMPT s_min_snaptime                = &s_min_snaptime.
PROMPT s_name                        = &s_name.
PROMPT s_p_con_id                    = &s_p_con_id.
PROMPT s_pdb_join_cond               = &s_pdb_join_cond.
PROMPT s_platform_name               = &s_platform_name.
PROMPT s_pluggablelogging            = &s_pluggablelogging.
PROMPT s_tag                         = &s_tag.
PROMPT s_tblprefix                   = &s_tblprefix.
PROMPT s_umf_test                    = &s_umf_test.
PROMPT s_useawr                      = &s_useawr.


PROMPT
PROMPT "BIND VARIABLES"
BEGIN
--dbms_output.put_line( 'compress_for                  = ' ||  :compress_for);
--dbms_output.put_line( 'editionable                   = ' ||  :editionable);
--dbms_output.put_line( 'v_maxsnap                     = ' ||  :v_maxsnap);
--dbms_output.put_line( 'v_maxsnaptime                 = ' ||  :v_maxsnaptime);
--dbms_output.put_line( 'v_minsnap                     = ' ||  :v_minsnap);
--dbms_output.put_line( 'v_minsnaptime                 = ' ||  :v_minsnaptime);
--dbms_output.put_line( 'visibility                    = ' ||  :visibility);
dbms_output.put_line( 'lv_cdb_join_cond              = ' ||  :lv_cdb_join_cond);
dbms_output.put_line( 'lv_db_container_col           = ' ||  :lv_db_container_col);
dbms_output.put_line( 'lv_do_pluggable               = ' ||  :lv_do_pluggable);
dbms_output.put_line( 'lv_editionable_col            = ' ||  :lv_editionable_col);
dbms_output.put_line( 'lv_is_container               = ' ||  :lv_is_container);
dbms_output.put_line( 'lv_pdb_join_cond              = ' ||  :lv_pdb_join_cond);
dbms_output.put_line( 'lv_tblprefix                  = ' ||  :lv_tblprefix);
dbms_output.put_line( 'v_compress_col                = ' ||  :v_compress_col);
dbms_output.put_line( 'v_dbid                        = ' ||  :v_dbid);
dbms_output.put_line( 'v_dflt_value_flag             = ' ||  :v_dflt_value_flag);
dbms_output.put_line( 'v_dma_source_id               = ' ||  :v_dma_source_id);
dbms_output.put_line( 'v_index_visibility            = ' ||  :v_index_visibility);
dbms_output.put_line( 'v_info_prompt                 = ' ||  :v_info_prompt);
dbms_output.put_line( 'v_io_function_sql             = ' ||  :v_io_function_sql);
dbms_output.put_line( 'v_lob_compression_col         = ' ||  :v_lob_compression_col);
dbms_output.put_line( 'v_lob_dedup_col               = ' ||  :v_lob_dedup_col);
dbms_output.put_line( 'v_lob_part_compression_col    = ' ||  :v_lob_part_compression_col);
dbms_output.put_line( 'v_lob_part_dedup_col          = ' ||  :v_lob_part_dedup_col);
dbms_output.put_line( 'v_lob_subpart_compression_col = ' ||  :v_lob_subpart_compression_col);
dbms_output.put_line( 'v_lob_subpart_dedup_col       = ' ||  :v_lob_subpart_dedup_col);
dbms_output.put_line( 'v_manual_unique_id            = ' ||  :v_manual_unique_id);
dbms_output.put_line( 'v_max_snapid                  = ' ||  :v_max_snapid);
dbms_output.put_line( 'v_max_snaptime                = ' ||  :v_max_snaptime);
dbms_output.put_line( 'v_min_snapid                  = ' ||  :v_min_snapid);
dbms_output.put_line( 'v_min_snaptime                = ' ||  :v_min_snaptime);
dbms_output.put_line( 'v_pdb_logging_flag            = ' ||  :v_pdb_logging_flag);
dbms_output.put_line( 'v_pkey                        = ' ||  :v_pkey);
dbms_output.put_line( 'v_stats_prompt                = ' ||  :v_stats_prompt);
dbms_output.put_line( 'v_statsWindow                 = ' ||  :v_statsWindow);
dbms_output.put_line( 'v_umfflag                     = ' ||  :v_umfflag);
dbms_output.put_line( 'v_useawr                      = ' ||  :v_useawr);
END;
/

PROMPT
PROMPT "SQLPLUS ENVIRONMENT"
show all

PROMPT
PROMPT "DUMP ALL BIND VARIABLES"
PRINT

spool off


