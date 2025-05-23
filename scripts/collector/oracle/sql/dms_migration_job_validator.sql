whenever sqlerror exit
whenever oserror exit failure
set feedback off termout on verify off

prompt
prompt ======================================================================================================
prompt Google Database Migration Service: Oracle to PostgreSQL Migration Job Validation
prompt ======================================================================================================
prompt

-- Configuration section...
-- ------------------------------------------------------------------------------------------
variable db_is_multitenant  VARCHAR2(3)
variable db_ols_enabled     VARCHAR2(5)
variable sql_message        VARCHAR2(1000)

DECLARE
    v_is_multitenant VARCHAR2(3) := 'NO';
    v_ols_enabled    VARCHAR2(5) := 'FALSE';
BEGIN
    $IF DBMS_DB_VERSION.VER_LE_10 $THEN
        NULL;
    $ELSIF DBMS_DB_VERSION.VER_LE_11 $THEN
        NULL;
    $ELSE
        IF SYS_CONTEXT('USERENV', 'CDB_NAME') IS NOT NULL AND SYS_CONTEXT('USERENV', 'CON_ID') != 1 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Google Database Migration Service Migration Job Validation must be run from the CDB root container and not from within a PDB. Script will now exit.');
        END IF;
        SELECT cdb INTO v_is_multitenant FROM v$database;
    $END
    :db_is_multitenant := v_is_multitenant;

    SELECT value
    INTO  v_ols_enabled
    FROM v$option
    WHERE parameter = 'Oracle Label Security';
    :db_ols_enabled := v_ols_enabled;
END;
/

undefine _schemas
undefine _schemas_csv
undefine _schemas_card
undefine _user_name
undefine _pdb_name
undefine _cdc_mode
undefine _blp_redo_dir
undefine _blp_arch_dir
undefine _report_format
undefine _report_name
undefine _input_errors

column _schemas         new_value _schemas
column _schemas_csv     new_value _schemas_csv
column _schemas_card    new_value _schemas_card
column _user_name       new_value _user_name
column _pdb_name        new_value _pdb_name
column _cdc_mode        new_value _cdc_mode
column _blp_redo_dir    new_value _blp_redo_dir
column _blp_arch_dir    new_value _blp_arch_dir
column _report_format   new_value _report_format
column _report_name     new_value _report_name
column _input_errors    new_value _input_errors

prompt Input parameters (press enter to accept the default value)
prompt

accept _schemas       prompt "Enter the names of the schema(s) to be migrated (csv) (default=ALL non-Oracle) : "
accept _user_name     prompt "Enter the username used in the source Oracle connection profile                : "
accept _pdb_name      prompt "Enter the PDB name (multitenant databases only) (default=None)                 : "
accept _report_format prompt "Enter the format for the generated report (TEXT or HTML, default=HTML)         : "

DECLARE
    v_user_name         VARCHAR2(128) := '&_user_name';
    v_user_exists       CHAR(1)       := 'N';
    v_pdb_name          VARCHAR2(128) := '&_pdb_name';
    v_report_format     VARCHAR2(4)   := '&_report_format';
    v_is_multitenant    BOOLEAN := (:db_is_multitenant = 'YES');
    invalid_input       EXCEPTION;
BEGIN
    IF v_user_name IS NULL THEN
        :sql_message := 'DMSMJV-01: User name parameter cannot be NULL';
        RAISE invalid_input;
    END IF;
    SELECT CASE WHEN COUNT(*) = 1 THEN 'Y' ELSE 'N' END
    INTO v_user_exists
    FROM dba_users
    WHERE username = UPPER(v_user_name);
    IF v_user_exists = 'N' THEN
        :sql_message := 'DMSMJV-02: User name ' || UPPER(v_user_name) || ' does not exist';
        RAISE invalid_input;
    END IF;
    IF v_is_multitenant AND v_pdb_name IS NULL THEN
        :sql_message := 'DMSMJV-03: PDB name parameter cannot be NULL when source database is multitenant';
        RAISE invalid_input;
    END IF;
    IF NOT v_is_multitenant AND v_pdb_name IS NOT NULL THEN
        :sql_message := 'DMSMJV-04: PDB name parameter must be NULL when source database is non-multitenant';
        RAISE invalid_input;
    END IF;
    IF v_report_format IS NOT NULL AND UPPER(v_report_format) NOT IN ('TEXT', 'HTML') THEN
        :sql_message := 'DMSMJV-05: Report format parameter must be TEXT or HTML';
        RAISE invalid_input;
    END IF;
EXCEPTION
    WHEN invalid_input THEN
        NULL;
    WHEN OTHERS THEN
        :sql_message := COALESCE(:sql_message, 'DMSMJV-99: Error: ' || SQLERRM);
END;
/

set termout off
SELECT REGEXP_REPLACE(UPPER('''' || REGEXP_REPLACE('&_schemas', '\s*,\s*', ''',''') || ''''),'''|"')        AS "_schemas_csv"
--,      CASE WHEN UPPER('&_report_format') = 'HTML' OR '&_report_format' IS NULL THEN 'html' ELSE 'txt' END  AS "_file_extension"
,      'google_dms_oracle_to_postgres_migration_job_validation_' || TO_CHAR(SYSDATE, 'YYYY-MM-DD-HH24-MI-SS') ||
          CASE WHEN UPPER('&_report_format') = 'HTML' OR '&_report_format' IS NULL THEN '.html' ELSE '.txt' END AS "_report_name"
,      NVL2(:sql_message, ' (with errors)', NULL) AS "_input_errors"
FROM   dual;

set termout on

-- Execution section...
-- ------------------------------------------------------------------------------------------
set termout off define on serveroutput on size unlimited format word_wrapped

prompt
prompt Starting Google Database Migration Service Migration Job Validation...
prompt

spool &_report_name

DECLARE
    sql_message         VARCHAR2(1000)         := :sql_message;
    c_cdc_mode          CONSTANT VARCHAR2(20)  := 'LOG_MINER';
    c_script_version    CONSTANT VARCHAR2(3)   := '1.1';
    c_user_name         CONSTANT VARCHAR2(128) := UPPER('&_user_name');
    c_pdb_name          CONSTANT VARCHAR2(128) := UPPER('&_pdb_name');
    c_report_format     CONSTANT VARCHAR2(4)   := NVL(UPPER('&_report_format'), 'HTML');
    v_schemas           CLOB                   := '&_schemas_csv';
    v_db_version        VARCHAR2(17);
    --
    TYPE finding_result_rt IS RECORD
    ( result_object     VARCHAR2(1024)
    , result_message    VARCHAR2(1024) := NULL
    );
    TYPE finding_result_aat IS TABLE OF finding_result_rt
        INDEX BY PLS_INTEGER;
    TYPE finding_type_rt IS RECORD
    ( type_severity         VARCHAR2(30)
    , type_description      VARCHAR2(1024)
    , type_description_html VARCHAR2(1024)
    , type_action           VARCHAR2(1024)
    , type_action_html      VARCHAR2(1024)
    , type_results          finding_result_aat
    );
    TYPE finding_type_aat IS TABLE OF finding_type_rt
        INDEX BY VARCHAR2(60);
    --
    c_finding_noissues          CONSTANT VARCHAR2(30) := 'No issues';
    c_finding_critical          CONSTANT VARCHAR2(30) := 'Action required';
    c_finding_warning           CONSTANT VARCHAR2(30) := 'Review recommended';
    c_finding_information       CONSTANT VARCHAR2(30) := 'Information only';
    --
    c_check_arch_log_mode       CONSTANT VARCHAR2(60) := 'Archive log mode';
    c_check_arch_log_count      CONSTANT VARCHAR2(60) := 'Archive log count';
    c_check_privs_perms         CONSTANT VARCHAR2(60) := 'User privileges / permissions';
    c_check_min_supp_log        CONSTANT VARCHAR2(60) := 'Supplemental logging (minimal)';
    c_check_obj_supp_log        CONSTANT VARCHAR2(60) := 'Supplemental logging (objects)';
    c_check_charset             CONSTANT VARCHAR2(60) := 'Unsupported character set';
    c_check_oci_db              CONSTANT VARCHAR2(60) := 'Oracle Autonomous Database';
    c_check_obj_names           CONSTANT VARCHAR2(60) := 'Unsupported object names';
    c_check_col_names           CONSTANT VARCHAR2(60) := 'Unsupported column names';
    c_check_internal_col_names  CONSTANT VARCHAR2(60) := 'Oracle hidden column names';
    c_check_iots                CONSTANT VARCHAR2(60) := 'Index-organized tables (IOTs)';
    c_check_no_pk               CONSTANT VARCHAR2(60) := 'Tables without primary keys';
    c_check_ols                 CONSTANT VARCHAR2(60) := 'Oracle Label Security (OLS)';
    c_check_data_types_nn       CONSTANT VARCHAR2(60) := 'Unsupported data types with NOT NULL constraints';
    c_check_data_types_no_nn    CONSTANT VARCHAR2(60) := 'Unsupported data types without NOT NULL constraints';
    c_check_table_count         CONSTANT VARCHAR2(60) := 'Count of tables to be migrated';
    c_check_gtts                CONSTANT VARCHAR2(60) := 'Global temporary tables (GTTs)';
    c_check_jobs                CONSTANT VARCHAR2(60) := 'DBMS_JOB or DBMS_SCHEDULER jobs';
    c_check_mviews              CONSTANT VARCHAR2(60) := 'Materialized views';
    c_check_sequences           CONSTANT VARCHAR2(60) := 'Sequences';
    c_check_xml_tables          CONSTANT VARCHAR2(60) := 'XMLType tables';
    c_check_object_tables       CONSTANT VARCHAR2(60) := 'Object tables';
    c_check_namespace_clash     CONSTANT VARCHAR2(60) := 'Namespace clashes';
    c_check_name_lengths        CONSTANT VARCHAR2(60) := 'LogMiner: table and column name lengths';
    --
    v_finding_types         finding_type_aat;
    v_finding_results       finding_result_aat;
    v_index_val             VARCHAR2(60);
    v_is_multitenant        BOOLEAN := (:db_is_multitenant = 'YES');
    v_ols_enabled           BOOLEAN := (:db_ols_enabled = 'TRUE');
    v_pdb_con_id            PLS_INTEGER;
    v_finding_sql           CLOB;
    v_critical_count        PLS_INTEGER := 0;
    v_warning_count         PLS_INTEGER := 0;
    v_information_count     PLS_INTEGER := 0;
    v_noissues_count        PLS_INTEGER := 0;

    PROCEDURE p ( p1 IN VARCHAR2, p2 IN VARCHAR2 DEFAULT NULL ) IS
    BEGIN
        IF p2 IS NULL THEN
            DBMS_OUTPUT.PUT_LINE(p1);
        ELSE
            DBMS_OUTPUT.PUT_LINE(RPAD(p1, 30, ' ') || ' ' || p2);
        END IF;
    END p;

    FUNCTION escape_html ( p1 IN VARCHAR2 ) RETURN VARCHAR2 IS
    BEGIN
        RETURN HTF.ESCAPE_SC(p1);
    END escape_html;

    PROCEDURE report_header IS
    BEGIN
        IF c_report_format = 'TEXT' THEN
            p('================================================================================');
            p('Google Database Migration Service: Migration Job Validation Report');
            p('Oracle to PostgreSQL');
            p('================================================================================');
        ELSE
            p('<!DOCTYPE html>');
            p('<html class="has-navbar-fixed-top">');
            p('<head>');
                p('<title>Google Database Migration Service: Migration Job Validation Report (Oracle to PostgreSQL)</title>');
                p('<meta charset="utf-8">');
                p('<meta name="viewport" content="width=device-width, initial-scale=1">');
                p('<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bulma@1.0.2/css/bulma.min.css">');
                p('<link href="http://fonts.googleapis.com/css?family=Lato:400,600,700" rel="stylesheet" type="text/css">');
                p('<link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css" rel="stylesheet" type="text/css">');
                p('<script type="text/javascript" src="https://code.jquery.com/jquery-3.7.1.slim.min.js"></script>');
                p('<script type="text/javascript">');
                  p('$(document).ready(function () {');
                    p('var expandedAll = 0;');
                    p('$(".card > header > button > span > i").click(function (e) {');
                      p('var showElementDescription = $(this).parents(".card").find(".card-content");');
                      p('if ($(showElementDescription).is(":visible")) {');
                        p('showElementDescription.hide("fast", "swing");');
                        p('$(this).attr("class", "fa fa-angle-right fa-lg");');
                      p('} else {');
                        p('showElementDescription.show("fast", "swing");');
                        p('$(this).attr("class", "fa fa-angle-down fa-lg");');
                      p('}');
                    p('});');

                    p('$("#expandCollapseAll").click(function (e) {');
                        p('$(this).find("span > i").toggleClass("fa-angle-double-right");');
                        p('$(this).find("span > i").toggleClass("fa-angle-double-down");');
                        --p('expandedCount += 1;');
                        --p('console.log(expandedCount);');
                      p('$.each($(".card-content"), function(index, value) {');
                          --p('console.log(index);');
                          p('if (expandedAll == 0) {');
                            p('$(this).show("fast", "swing");');
                            p('$(this).parents(".card").find("header > button > span > i")');
                            p('.attr("class", "fa fa-angle-down fa-lg");');
                          p('} else {');
                            p('$(this).hide("fast", "swing");');
                            p('$(this).parents(".card").find("header > button > span > i")');
                            p('.attr("class", "fa fa-angle-right fa-lg");');
                          p('}');
                      p('});');
                      p('expandedAll = !expandedAll;');
                    p('});');

                  p('});');
                p('</script>');
                p('<style>');
                    p('body { font-family: Lato; }');
                    p(':root { --bulma-danger-s: 83.3%; --bulma-danger-l: 47.06%; }');
                    p('.section { --bulma-section-padding-desktop: 2rem 2rem 0.5rem 2rem; }');
                    p('.card-header-title { --bulma-card-header-weight: var(--bulma-weight-normal); }');
                    p('p { --bulma-panel-heading-padding: 0.5em 1.25em; }');
                    p('hr { --bulma-hr-background-color: var(--bulma-grey-lighter); --bulma-hr-margin: 0.25rem 0; --bulma-hr-height: 1px; }');
                p('</style>');
            p('</head>');
            p('<body>');
                p('<nav class="navbar is-fixed-top has-background-white-bis has-shadow">');
                    p('<div class="navbar-brand">');
                        p('<a class="navbar-item" href="#">');
                            p('<img src="https://fonts.gstatic.com/s/i/productlogos/google_cloud/v8/web-24dp/logo_google_cloud_color_1x_web_24dp.png" />');
                        p('</a>');
                        p('<p class="navbar-item">');
                            p('<span>Database Migration Service: Migration Job Validation Report (Oracle to PostgreSQL)</span>');
                        p('</p>');
                    p('</div>');
                    p('<div class="navbar-end">');
                        p('<div class="navbar-item">');
                            p('<div class="field is-grouped">');
                                p('<p class="control">');
                                    p('<span class="is-family-monospace"></span>');
                                p('</p>');
                            p('</div>');
                        p('</div>');
                    p('</div>');
            p('</nav>');
            p('<div>');
        END IF;
    END report_header;

    PROCEDURE report_footer IS
    BEGIN
        IF c_report_format = 'TEXT' THEN
            p(CHR(13));
            p('================================================================================');
            p('End of Report');
            p('================================================================================');
        ELSE
            p('</div>');
            p('</main>');
            p('</body>');
            p('</html>');
        END IF;
    END report_footer;

    PROCEDURE section_header ( p1 IN VARCHAR2, p2 IN CHAR DEFAULT '-' ) IS
    BEGIN
        IF c_report_format = 'TEXT' THEN
            p(CHR(13));
            p(p1);
            p(RPAD(p2, 80, p2));
        ELSE
            IF p1 = 'Findings detail' THEN
                p('<section class="section">');
                p('<div class="is-flex">');
                p('<h1 class="subtitle flex-grow"><strong>' || p1 || '</strong></h1>');
                p('<button id="expandCollapseAll" class="card-header-icon ml-auto" aria-label="more options">');
                  p('<span class="icon">');
                    p('<i class="fa fa-angle-double-right fa-lg" aria-hidden="true"></i>');
                  p('</span>');
                p('</button>');
                p('</div>');
            ELSE
                p('<section class="section">');
                p('<h1 class="subtitle"><strong>' || p1 || '</strong></h1>');
            END IF;
        END IF;
    END section_header;

    PROCEDURE section_footer IS
    BEGIN
        IF c_report_format = 'HTML' THEN
            p('</section>');
        END IF;
    END section_footer;

    PROCEDURE report_metadata IS
    BEGIN
        IF c_report_format = 'HTML' THEN
            p('<div class="fixed-grid has-8-cols pb-4">');
            p('<div class="grid">');
            p('<div class="cell"><span class="tag is-light">Username</span></div>');
            p('<div class="cell is-col-span-7"><code>' || escape_html(UPPER(c_user_name)) || '</code></div>');
            IF v_is_multitenant THEN
                p('<div class="cell"><span class="tag is-light">CDB name</span></div>');
                p('<div class="cell is-col-span-7"><code>' || escape_html(UPPER(SYS_CONTEXT('USERENV', 'CDB_NAME'))) || '</code></div>');
                p('<div class="cell"><span class="tag is-light">PDB name</span></div>');
                p('<div class="cell is-col-span-7"><code>' || escape_html(UPPER(c_pdb_name)) || '</code></div>');
            ELSE
                p('<div class="cell"><span class="tag is-light">DB name</span></div>');
                p('<div class="cell is-col-span-7"><code>' || escape_html(UPPER(SYS_CONTEXT('USERENV', 'DB_NAME'))) || '</code></div>');
            END IF;
            p('<div class="cell"><span class="tag is-light">DB version</span></div>');
            p('<div class="cell is-col-span-7"><code>' || v_db_version || '</code></div>');
            p('<div class="cell"><span class="tag is-light">CDC mode</span></div>');
            p('<div class="cell is-col-span-7"><code>' || escape_html(UPPER(c_cdc_mode)) || '</code></div>');
            p('<div class="cell"><span class="tag is-light">Schemas</span></div>');
            p('<div class="cell is-col-span-7"><code>' || CASE WHEN v_schemas IS NOT NULL THEN escape_html(UPPER(v_schemas)) ELSE 'ALL NON-ORACLE' END || '</code></div>');
            p('<div class="cell"><span class="tag is-light">Generated at</span></div>');
            p('<div class="cell is-col-span-7"><code>' || TO_CHAR(SYSDATE,'DD-MON-YYYY HH24:MI:SS') || '</code></div>');
            p('<div class="cell"><span class="tag is-light">Script version</span></div>');
            p('<div class="cell is-col-span-7"><code>v' || c_script_version || '</code></div>');
            p('</div>');
            p('</div>');
        ELSE
            p('Username:', UPPER(c_user_name));
            IF v_is_multitenant THEN
                p('CDB name:', UPPER(SYS_CONTEXT('USERENV', 'CDB_NAME')));
                p('PDB name:', UPPER(c_pdb_name));
            ELSE
                p('DB name:', UPPER(SYS_CONTEXT('USERENV', 'DB_NAME')));
            END IF;
            p('DB version:', v_db_version);
            p('CDC mode:', UPPER(c_cdc_mode));
            p('Schemas:', CASE WHEN v_schemas IS NOT NULL THEN UPPER(v_schemas) ELSE 'ALL NON-ORACLE' END);
            p('Generated at:', TO_CHAR(SYSDATE,'DD-MON-YYYY HH24:MI:SS'));
            p('Script version:', 'v' || c_script_version);
        END IF;
    END report_metadata;

    PROCEDURE report_summary IS
    BEGIN
        IF c_report_format = 'HTML' THEN
            p('<div class="fixed-grid has-4-cols">');
            p('<div class="grid is-column-gap-8">');
            p('<div class="cell has-text-centered">');
            p('<article class="panel is-warning"><p class="panel-heading">' || c_finding_critical || '</p><p class="panel-tabs p-3 is-size-3">' || v_critical_count || '</p></article></div>');
            p('<div class="cell has-text-centered">');
            p('<article class="panel is-success"><p class="panel-heading">' || c_finding_noissues || '</p><p class="panel-tabs p-3 is-size-3">' || v_noissues_count || '</p></article></div>');
            p('<div class="cell has-text-centered">');
            p('<article class="panel is-link"><p class="panel-heading">' || c_finding_warning || '</p><p class="panel-tabs p-3 is-size-3">' || v_warning_count || '</p></article></div>');
            p('<div class="cell has-text-centered">');
            p('<article class="panel is-text"><p class="panel-heading">' || c_finding_information || '</p><p class="panel-tabs p-3 is-size-3">' || v_information_count || '</p></article></div>');
            p('</div>');
            p('</div>');
        ELSE
            p(c_finding_critical || ':', v_critical_count);
            p(c_finding_noissues || ':', v_noissues_count);
            p(c_finding_warning || ':', v_warning_count);
            p(c_finding_information || ':', v_information_count);
        END IF;
    END report_summary;

    PROCEDURE report_finding (finding IN VARCHAR2) IS
        v_line_char_1 CHAR(1) := '~';
        v_line_char_2 CHAR(1) := '-';
    BEGIN
        IF c_report_format = 'TEXT' THEN
            p(CHR(13));
            p('[' || v_finding_types(finding).type_severity || '] ' || finding || ' (' || v_finding_types(finding).type_results.COUNT || ')');
            p(RPAD(v_line_char_1, 80, v_line_char_1));
            IF v_finding_types(finding).type_description IS NOT NULL THEN
                p(CHR(13));
                p('Description');
                p(RPAD(v_line_char_2, 80, v_line_char_2));
                p(v_finding_types(finding).type_description);
            END IF;
            IF v_finding_types(finding).type_action IS NOT NULL THEN
                p(CHR(13));
                p('Action Required');
                p(RPAD(v_line_char_2, 80, v_line_char_2));
                p(v_finding_types(finding).type_action);
            END IF;
            p(CHR(13));
            p('Affected Objects');
            p(RPAD(v_line_char_2, 80, v_line_char_2));
            FOR i IN 1 .. v_finding_types(finding).type_results.COUNT LOOP
                p(i || ': ' ||
                    v_finding_types(finding).type_results(i).result_message ||
                    CASE
                        WHEN v_finding_types(finding).type_results(i).result_object IS NOT NULL
                        THEN ' [' || v_finding_types(finding).type_results(i).result_object || ']'
                        ELSE ''
                    END);
            END LOOP;
        ELSE
            p('<div class="card">');
              p('<header class="card-header">');
                p('<p class="card-header-title"><span class="tag ' ||
                CASE
                    WHEN v_finding_types(finding).type_severity = c_finding_critical THEN 'is-warning has-text-weight-semibold'
                    WHEN v_finding_types(finding).type_severity = c_finding_warning THEN 'is-link has-text-weight-semibold'
                    WHEN v_finding_types(finding).type_severity = c_finding_noissues THEN 'is-success has-text-weight-semibold'
                    WHEN v_finding_types(finding).type_severity = c_finding_information THEN 'is-text has-text-weight-semibold' END
                || '">' || v_finding_types(finding).type_severity || '</span><span class="pl-2">' || escape_html(finding) || '</span><span class="tag is-light ml-auto">' || v_finding_types(finding).type_results.COUNT || '</span></p>');
                p('<button class="card-header-icon" aria-label="more options">');
                  p('<span class="icon">');
                    p('<i class="fa fa-angle-right fa-lg" aria-hidden="true"></i>');
                  p('</span>');
                p('</button>');
              p('</header>');
              p('<div class="card-content" hidden="true">');
                p('<div class="fixed-grid has-8-cols">');
                  p('<div class="grid">');
                    p('<div class="cell is-col-span-3"><small><span class="has-text-black-ter">Description</span><hr /><p>' ||
                        CASE WHEN v_finding_types(finding).type_description_html IS NOT NULL THEN
                            v_finding_types(finding).type_description_html ELSE v_finding_types(finding).type_description END ||
                      '</p></small>');
                    IF v_finding_types(finding).type_action IS NOT NULL THEN
                        p('<div class="pt-4"><small><span class="has-text-black-ter">Action required</span><hr /><p>' ||
                            CASE WHEN v_finding_types(finding).type_action_html IS NOT NULL THEN
                                v_finding_types(finding).type_action_html ELSE v_finding_types(finding).type_action END ||
                          '</p></small></div>');
                    END IF;
                    p('</div>');

                    p('<div class="cell is-col-span-5">');
                    p('<small><table class="table is-narrow is-striped is-fullwidth">');
                      p('<tbody>');
                          p('<tr>');
                            p('<th>Message</th>');
                            p('<th>Object</th>');
                          p('</tr>');
                          IF v_finding_types(finding).type_results.COUNT > 0 THEN
                              FOR i IN 1 .. v_finding_types(finding).type_results.COUNT LOOP
                                p('<tr>');
                                  p('<td>' || escape_html(v_finding_types(finding).type_results(i).result_message) || '</td>');
                                  p('<td>' || escape_html(v_finding_types(finding).type_results(i).result_object) || '</td>');
                                p('</tr>');
                              END LOOP;
                          ELSE
                            p('<tr>');
                                p('<td colspan="2">No messages</td>');
                            p('</tr>');
                          END IF;
                      p('</tbody>');
                    p('</table></small>');

                    p('</div>');

                  p('</div>');
                p('</div>');
              p('</div>');
            p('</div>');
        END IF;
    END report_finding;

    FUNCTION valid_schema_subquery ( container_id IN INTEGER DEFAULT NULL ) RETURN VARCHAR2 IS
    BEGIN
        IF v_schemas IS NOT NULL THEN
            RETURN q'[SELECT username
                    FROM  ]' || CASE WHEN container_id IS NOT NULL THEN 'cdb' ELSE 'dba' END || q'[_users
                    WHERE  username IN (]' ||
                        UPPER('''' || REGEXP_REPLACE(v_schemas, '\s*,\s*', ''',''') || '''')
                        ||  q'[)
                     ]' || CASE WHEN container_id IS NOT NULL THEN 'AND con_id = ' || container_id END || q'[
            ]';
        ELSE
            RETURN q'[SELECT username
                    FROM  ]' || CASE WHEN container_id IS NOT NULL THEN 'cdb' ELSE 'dba' END || q'[_users
                    WHERE  NOT ( username IN ('ANONYMOUS', 'APPQOSSYS', 'AUDSYS', 'CSMIG', 'CTXSYS', 'DBSFWUSER',
                                              'DBSNMP', 'DIP', 'DMA_COLLECTOR', 'DMSYS', 'DVSYS', 'DVF', 'EXFSYS',
                                              'GSMADMIN_INTERNAL', 'GSMCATUSER', 'GSMUSER', 'LBACSYS', 'MDDATA',
                                              'MDSYS', 'MGDSYS', 'MGMT_VIEW', 'MTMSYS', 'ODM', 'ODM_MTR', 'ODMRSYS',
                                              'OJVMSYS', 'OLAPSYS', 'ORACLE_OCM', 'ORDDATA', 'ORDPLUGINS',
                                              'ORDS_METADATA', 'ORDS_PUBLIC_USER', 'ORDSYS', 'OSE$HTTP$ADMIN',
                                              'OUTLN', 'OWBSYS', 'OWBSYS_AUDIT', 'PERFSTAT', 'SI_INFORMTN_SCHEMA',
                                              'SPATIAL_CSW_ADMIN_USR', 'SPATIAL_WFS_ADMIN_USR', 'SQLTXPLAIN',
                                              'SYS$UMF', 'SYS', 'SYSBACKUP', 'SYSDG', 'SYSKM', 'SYSMAN', 'SYSTEM',
                                              'TRACESRV', 'TSMSYS', 'WEBSYS', 'WK_PROXY', 'WK_TEST', 'WKPROXY',
                                              'WKSYS', 'WMSYS', 'XDB', 'XS$NULL')
                                OR username LIKE 'APEX^_%' ESCAPE '^'
                                OR username LIKE 'AURORA$%'
                                OR username LIKE 'OPS$%'
                                OR username LIKE 'FLOWS^_%' ESCAPE '^')
                     ]' || CASE WHEN container_id IS NOT NULL THEN 'AND con_id = ' || container_id END || q'[
            ]';
        END IF;
    END;

    PROCEDURE execute_statement(statement IN VARCHAR2, container IN VARCHAR2 DEFAULT NULL) IS
        v_cursor            PLS_INTEGER := DBMS_SQL.OPEN_CURSOR(SECURITY_LEVEL=>2);
        v_return            PLS_INTEGER;
        v_count             PLS_INTEGER;
        v_index             PLS_INTEGER;
        v_result_object     VARCHAR2(1024);
        v_result_message    VARCHAR2(1024);
        --
        c_debug             CONSTANT BOOLEAN := FALSE;
    BEGIN
        IF c_debug THEN
            DBMS_OUTPUT.PUT_LINE('execute_statement: container = ' || container);
            DBMS_OUTPUT.PUT_LINE('execute_statement: statement = ' || v_finding_sql);
        END IF;

        v_finding_results.DELETE;

        $IF DBMS_DB_VERSION.VER_LE_11 $THEN
            DBMS_SQL.PARSE(
                C=>v_cursor,
                STATEMENT=>statement,
                LANGUAGE_FLAG=>DBMS_SQL.NATIVE);
        $ELSE
            DBMS_SQL.PARSE(
                C=>v_cursor,
                STATEMENT=>statement,
                CONTAINER=>container,
                LANGUAGE_FLAG=>DBMS_SQL.NATIVE);
        $END

        v_return := DBMS_SQL.EXECUTE(v_cursor);

        DBMS_SQL.DEFINE_COLUMN(v_cursor, 1, v_result_message, 1024);
        DBMS_SQL.DEFINE_COLUMN(v_cursor, 2, v_result_object, 1024);

        v_index := 1;
          LOOP
            v_count := DBMS_SQL.FETCH_ROWS(v_cursor);
            EXIT WHEN v_count = 0;

            DBMS_SQL.COLUMN_VALUE(v_cursor, 1, v_result_message);
            DBMS_SQL.COLUMN_VALUE(v_cursor, 2, v_result_object);

            v_finding_results(v_index).result_object := v_result_object;
            v_finding_results(v_index).result_message := v_result_message;

            v_index := v_index + 1;
          END LOOP;

        DBMS_SQL.CLOSE_CURSOR(v_cursor);
    END execute_statement;

BEGIN

    IF sql_message IS NULL THEN

        DBMS_APPLICATION_INFO.SET_MODULE('Google Database Migration Service: Migration Job Validation', 'Initialisation');
        DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL);

        $IF DBMS_DB_VERSION.VER_LE_11 $THEN
            NULL;
        $ELSE
            IF v_is_multitenant THEN
                SELECT con_id
                INTO   v_pdb_con_id
                FROM   v$pdbs
                WHERE  name = c_pdb_name;
            END IF;
        $END

        SELECT version
        INTO v_db_version
        FROM v$instance;

        -- Critical checks
        v_finding_types(c_check_arch_log_mode).type_severity := c_finding_critical;
        v_finding_types(c_check_arch_log_mode).type_description := 'The database must be in archive log mode for CDC to function';
        v_finding_types(c_check_arch_log_mode).type_action := 'Enable archive log mode';

        v_finding_types(c_check_arch_log_count).type_severity := c_finding_critical;
        v_finding_types(c_check_arch_log_count).type_description := 'The database must have archive logs available for CDC to function';
        v_finding_types(c_check_arch_log_count).type_action := 'Verify the availability of archive logs';

        v_finding_types(c_check_privs_perms).type_severity := c_finding_critical;
        v_finding_types(c_check_privs_perms).type_description := 'Appropriate privileges and permissions are required for the ' || c_user_name || ' user';
        v_finding_types(c_check_privs_perms).type_description_html := 'Appropriate privileges and permissions are required for the <code>' || c_user_name || '</code> user';
        v_finding_types(c_check_privs_perms).type_action := 'Review the messages to determine the missing privileges and permissions and perform the necessary grants. For further guidance see the "Configure your source Oracle database" section of the documentation';
        v_finding_types(c_check_privs_perms).type_action_html := 'Review the messages to determine the missing privileges and permissions and perform the necessary grants. For further guidance see the <a href="https://cloud.google.com/database-migration/docs/oracle-to-postgresql/configure-your-source-oracle-database" target="_new">Configure your source Oracle database</a> section of the documentation';

        v_finding_types(c_check_min_supp_log).type_severity := c_finding_critical;
        v_finding_types(c_check_min_supp_log).type_description := 'The database must have minimal supplemental logging enabled';
        v_finding_types(c_check_min_supp_log).type_action := 'Enable minimal supplemental logging at the database level. For further guidance see the "Configure your source Oracle database" section of the documentation';
        v_finding_types(c_check_min_supp_log).type_action_html := 'Enable minimal supplemental logging at the database level. For further guidance see the <a href="https://cloud.google.com/database-migration/docs/oracle-to-postgresql/configure-your-source-oracle-database" target="_new">Configure your source Oracle database</a> section of the documentation';

        v_finding_types(c_check_obj_supp_log).type_severity := c_finding_critical;
        v_finding_types(c_check_obj_supp_log).type_description := 'The database does not have ALL column supplemental logging enabled and at least 1 table does not have it set at the table level';
        v_finding_types(c_check_obj_supp_log).type_description_html := 'The database does not have <code>ALL</code> column supplemental logging enabled and at least 1 table does not have it set at the table level';
        v_finding_types(c_check_obj_supp_log).type_action := 'Either the entire database or the tables to be migrated must have supplemental logging mode set to ALL. For further guidance see the "Configure your source Oracle database" section of the documentation';
        v_finding_types(c_check_obj_supp_log).type_action_html := 'Either the entire database or the tables to be migrated must have supplemental logging mode set to <code>ALL</code>. For further guidance see the <a href="https://cloud.google.com/database-migration/docs/oracle-to-postgresql/configure-your-source-oracle-database" target="_new">Configure your source Oracle database</a> section of the documentation';

        v_finding_types(c_check_charset).type_severity := c_finding_critical;
        v_finding_types(c_check_charset).type_description := 'Database Migration Service supports the following character set encodings for Oracle: AL16UTF16, AL32UTF8, IN8ISCII, JA16SJIS, US7ASCII, UTF8, WE8ISO8859P1, WE8ISO8859P9, WE8ISO8859P15, WE8MSWIN1252, ZHT16BIG5';
        v_finding_types(c_check_charset).type_description_html := 'Database Migration Service supports the following character set encodings for Oracle: <code>AL16UTF16, AL32UTF8, IN8ISCII, JA16SJIS, US7ASCII, UTF8, WE8ISO8859P1, WE8ISO8859P9, WE8ISO8859P15, WE8MSWIN1252, ZHT16BIG5</code>';
        v_finding_types(c_check_charset).type_action := 'Change to a supported source character set before migration';

        v_finding_types(c_check_oci_db).type_severity := c_finding_critical;
        v_finding_types(c_check_oci_db).type_description := 'Oracle Autonomous Database isn''t supported';

        v_finding_types(c_check_obj_names).type_severity := c_finding_critical;
        v_finding_types(c_check_obj_names).type_description := 'Schema and table names that include other than alphanumeric characters or an underscore (_) aren''t supported';
        v_finding_types(c_check_obj_names).type_description_html := 'Schema and table names that include other than alphanumeric characters or an underscore (<code>_</code>) aren''t supported';
        v_finding_types(c_check_obj_names).type_action := 'Materialized view tables should be excluded as they do not need to be migrated. The other objects must be renamed to include only supported characters otherwise they must be excluded from the migration job for it to succeed';

        v_finding_types(c_check_col_names).type_severity := c_finding_critical;
        v_finding_types(c_check_col_names).type_description := 'Column names that include characters other than alphanumeric characters or an underscore (_) aren''t supported';
        v_finding_types(c_check_col_names).type_description_html := 'Column names that include characters other than alphanumeric characters or an underscore (<code>_</code>) aren''t supported';
        v_finding_types(c_check_col_names).type_action := 'These columns must be renamed to include only supported characters otherwise the tables must be excluded from the migration job for it to succeed';

        v_finding_types(c_check_internal_col_names).type_severity := c_finding_warning;
        v_finding_types(c_check_internal_col_names).type_description := 'Oracle hidden column names include unsupported characters. These will be reported by DMS in the test of a migration job';
        v_finding_types(c_check_internal_col_names).type_action := 'Whilst these columns can be ignored, it is important to understand that DMS will only create Function-based indexes for you in the DMS Conversion Workspace. Therefore you should read the list carefully and consider how the use of the other Oracle features represented by these columns (such as Extended statistics) can be implemented in the PostgreSQL target outside of DMS';

        v_finding_types(c_check_iots).type_severity := c_finding_warning;
        v_finding_types(c_check_iots).type_description := 'IOTs aren''t supported for LogMiner based CDC with DMS';
        v_finding_types(c_check_iots).type_action := 'Ensure that you do not include IOTs in the migration job. Doing so will lead to the migration job status remaining in the "Full dump" phase indefinitely';

        v_finding_types(c_check_no_pk).type_severity := c_finding_information;
        v_finding_types(c_check_no_pk).type_description := 'All tables in the destination should have a primary key. If a table in the source doesn''t have a primary key, then one should be created using one of the options in "Migrate tables without primary keys". The DMS Conversion Workspace will generate the necessary ROWID pseudocolumn and supporting object code for PostgreSQL automatically';
        v_finding_types(c_check_no_pk).type_description_html := 'All tables in the destination should have a primary key. If a table in the source doesn''t have a primary key, then one should be created using one of the options in <a href="https://cloud.google.com/database-migration/docs/oracle-to-postgresql/migrate-tables-without-pks" target="_new">Migrate tables without primary keys</a>. The DMS Conversion Workspace will generate the necessary <code>ROWID</code> pseudocolumn and supporting object code for PostgreSQL automatically';
        v_finding_types(c_check_no_pk).type_action := 'Following the promotion of the migration job the ROWID pseudocolumn can either be retained or dropped';
        v_finding_types(c_check_no_pk).type_action_html := 'Following the promotion of the migration job the <code>ROWID</code> pseudocolumn can either be retained or dropped';

        v_finding_types(c_check_ols).type_severity := c_finding_warning;
        v_finding_types(c_check_ols).type_description := 'Oracle Label Security (OLS) configuration isn''t replicated';
        v_finding_types(c_check_ols).type_action := 'The data in the tables with OLS enabled will be replicated according to the security policies applicable to the ' || c_user_name || ' user, but the security policies on those tables are not. Consider how this security feature could be implemented without OLS in the target application';
        v_finding_types(c_check_ols).type_action_html := 'The data in the tables with OLS enabled will be replicated according to the security policies applicable to the <code>' || c_user_name || '</code> user, but the security policies on those tables are not. Consider how this security feature could be implemented without OLS in the target application';

        v_finding_types(c_check_data_types_no_nn).type_severity := c_finding_warning;
        v_finding_types(c_check_data_types_no_nn).type_description := 'Columns of data types ANYDATA, BFILE, INTERVAL DAY TO SECOND, INTERVAL YEAR TO MONTH, LONG/LONG RAW, SDO_GEOMETRY, UROWID, XMLTYPE and User-Defined Types aren''t supported, and will be replaced with NULL values';
        v_finding_types(c_check_data_types_no_nn).type_description_html := 'Columns of data types <code>ANYDATA, BFILE, INTERVAL DAY TO SECOND, INTERVAL YEAR TO MONTH, LONG/LONG RAW, SDO_GEOMETRY, UROWID, XMLTYPE</code> and User-Defined Types aren''t supported, and will be replaced with <code>NULL</code> values';
        v_finding_types(c_check_data_types_no_nn).type_action := 'Consider the impact of having a <code>NULL</code> value in the target column(s). If the data in the column(s) is critical you will need to replicate the data in the column(s) using another method';

        v_finding_types(c_check_data_types_nn).type_severity := c_finding_critical;
        v_finding_types(c_check_data_types_nn).type_description := 'Columns of data types ANYDATA, BFILE, INTERVAL DAY TO SECOND, INTERVAL YEAR TO MONTH, LONG/LONG RAW, SDO_GEOMETRY, UROWID, XMLTYPE and User-Defined Types aren''t supported, and will be replaced with NULL values. The column(s) also have a NOT NULL constraint enabled. If this constraint is also enabled in the target database then the NULL value cannot be inserted and the migration job will fail';
        v_finding_types(c_check_data_types_nn).type_description_html := 'Columns of data types <code>ANYDATA, BFILE, INTERVAL DAY TO SECOND, INTERVAL YEAR TO MONTH, LONG/LONG RAW, SDO_GEOMETRY, UROWID, XMLTYPE</code> and User-Defined Types aren''t supported, and will be replaced with <code>NULL</code> values. The column(s) also have a <code>NOT NULL</code> constraint enabled. If this constraint is also enabled in the target database then the <code>NULL</code> value cannot be inserted and the migration job will fail';
        v_finding_types(c_check_data_types_nn).type_action := 'To allow the NULL value to be inserted disable the NOT NULL constraint on the target column(s) before starting the migration job. Additionally, consider the impact of having a NULL value in the target column(s). If the data in the column(s) is critical you will need to replicate the data in the column(s) using another method';
        v_finding_types(c_check_data_types_nn).type_action_html := 'To allow the <code>NULL</code> value to be inserted disable the <code>NOT NULL</code> constraint on the target column(s) before starting the migration job. Additionally, consider the impact of having a <code>NULL</code> value in the target column(s). If the data in the column(s) is critical you will need to replicate the data in the column(s) using another method';

        v_finding_types(c_check_table_count).type_severity := c_finding_information;
        v_finding_types(c_check_table_count).type_description := 'Migration jobs are limited to 10,000 tables and the total number of tables across all schemas exceeds this limit';
        v_finding_types(c_check_table_count).type_action := 'Use multiple migration jobs to work around this limitation';

        v_finding_types(c_check_gtts).type_severity := c_finding_warning;
        v_finding_types(c_check_gtts).type_description := 'DMS currently allows GTTs to be included in the list of tables selected for a migration job';
        v_finding_types(c_check_gtts).type_action := 'Ensure that you do not include GTTs in the migration job. Doing so will lead to the migration job status remaining in the "Full dump" phase indefinitely';

        v_finding_types(c_check_jobs).type_severity := c_finding_information;
        v_finding_types(c_check_jobs).type_description := 'Jobs that are scheduled by using DBMS_JOB or DBMS_SCHEDULER aren''t migrated';
        v_finding_types(c_check_jobs).type_description_html := 'Jobs that are scheduled by using <code>DBMS_JOB</code> or <code>DBMS_SCHEDULER</code> aren''t migrated';

        v_finding_types(c_check_mviews).type_severity := c_finding_information;
        v_finding_types(c_check_mviews).type_description := 'Materialized view definitions are migrated, but their materialized data isn''t';
        v_finding_types(c_check_mviews).type_action := 'After you finish migrating, refresh your materialized views in order to populate them with data from the migrated tables';

        v_finding_types(c_check_sequences).type_severity := c_finding_information;
        v_finding_types(c_check_sequences).type_description := 'Sequences are migrated, but their values in the source database might keep advancing before the migration is completed';
        v_finding_types(c_check_sequences).type_action := 'After you finish migrating, update the sequence values on the destination instance to match those in the source database';

        v_finding_types(c_check_xml_tables).type_severity := c_finding_critical;
        v_finding_types(c_check_xml_tables).type_description := 'XMLType tables are not supported';
        v_finding_types(c_check_xml_tables).type_action := 'If the data in the table is critical it will need to be replicated using another method';

        v_finding_types(c_check_object_tables).type_severity := c_finding_critical;
        v_finding_types(c_check_object_tables).type_description := 'Object tables are not supported';
        v_finding_types(c_check_object_tables).type_action := 'If the data in the table is critical it will need to be replicated using another method';

        v_finding_types(c_check_namespace_clash).type_severity := c_finding_critical;
        v_finding_types(c_check_namespace_clash).type_description := 'Table and constraint namespace clash';
        v_finding_types(c_check_namespace_clash).type_action := 'Oracle namespacing allows a table and constraint with the same name to exist. This is not allowed in PostgreSQL. DMS does not currently recognise this and generates names that clash. The following constraints need to be manually renamed to be unique before applying to the target';

        v_finding_types(c_check_name_lengths).type_severity := c_finding_critical;
        v_finding_types(c_check_name_lengths).type_description := 'Oracle LogMiner requires tables or column names selected for mining not to exceed 30 characters';
        v_finding_types(c_check_name_lengths).type_action := 'Rename the tables or columns to shorten the length then after CDC is finished as part of cutover restore the original names. If this is not an option use the binary log reader CDC method';
        v_finding_types(c_check_name_lengths).type_action_html := 'Rename or copy the tables or columns to shorten their length. Then, once CDC is finished, as part of cutover restore the original names on the target. If this is not a feasible option use the binary log reader CDC method. For further guidance see the <a href="https://cloud.google.com/database-migration/docs/oracle-to-postgresql/about-data-flow#cdc" target="_new">Change Data Capture (CDC)</a> section of the documentation';

        DBMS_APPLICATION_INFO.SET_ACTION('Summary Report');
        report_header;

        -- c_check_name_lengths
        DBMS_APPLICATION_INFO.SET_ACTION(c_check_name_lengths);

        v_finding_sql := q'|SELECT result_message
             , result_object
        FROM (
            SELECT owner || '.' || table_name AS result_object
             , 'Unsupported table name' AS result_message
            FROM dba_tables
            WHERE owner IN (|' || valid_schema_subquery || q'|)
            AND LENGTH(table_name) > 30
        UNION
        SELECT owner || '.' || table_name || '.' || column_name
             , 'Unsupported column name'
        FROM dba_tab_columns
        WHERE owner IN (|' || valid_schema_subquery || q'|)
        AND LENGTH(column_name) > 30
        )
        ORDER BY result_message DESC
                , result_object|';

        execute_statement(v_finding_sql, c_pdb_name);
        v_finding_types(c_check_name_lengths).type_results := v_finding_results;

        -- c_check_namespace_clash
        DBMS_APPLICATION_INFO.SET_ACTION(c_check_namespace_clash);

        v_finding_sql := q'|SELECT 'Constraint name '|| constraint_name AS result_message
             , owner || '.' || table_name AS result_object
        FROM dba_constraints
        WHERE owner IN (|' || valid_schema_subquery || q'|)
        AND constraint_name = table_name
        ORDER BY owner
       , table_name|';

        execute_statement(v_finding_sql, c_pdb_name);
        v_finding_types(c_check_namespace_clash).type_results := v_finding_results;

        -- c_check_object_tables
        DBMS_APPLICATION_INFO.SET_ACTION(c_check_object_tables);

        v_finding_sql := q'|SELECT 'Object table type ' || table_type_owner || '.' || table_type AS result_message
             , owner || '.' || table_name AS result_object
        FROM dba_object_tables
        WHERE owner IN (|' || valid_schema_subquery || q'|)
        AND table_type != 'XMLTYPE'
        ORDER BY owner
       , table_name|';

        execute_statement(v_finding_sql, c_pdb_name);
        v_finding_types(c_check_object_tables).type_results := v_finding_results;

        -- c_check_xml_tables
        DBMS_APPLICATION_INFO.SET_ACTION(c_check_xml_tables);

        v_finding_sql := q'|SELECT 'XMLType table' AS result_message
             , owner || '.' || table_name AS result_object
        FROM dba_xml_tables
        WHERE owner IN (|' || valid_schema_subquery || q'|)
        ORDER BY owner
       , table_name|';

        execute_statement(v_finding_sql, c_pdb_name);
        v_finding_types(c_check_xml_tables).type_results := v_finding_results;

        -- c_check_sequences
        DBMS_APPLICATION_INFO.SET_ACTION(c_check_sequences);

        v_finding_sql := q'|SELECT 'Count of sequences in schema '|| sequence_owner AS result_message
             , COUNT(*) AS result_object
        FROM dba_sequences
        WHERE sequence_owner IN (|' || valid_schema_subquery || q'|)
        GROUP BY sequence_owner
        ORDER BY sequence_owner|';

        execute_statement(v_finding_sql, c_pdb_name);
        v_finding_types(c_check_sequences).type_results := v_finding_results;

        -- c_check_mviews
        DBMS_APPLICATION_INFO.SET_ACTION(c_check_mviews);

        v_finding_sql := q'|SELECT 'Materialized view' AS result_message
             , owner || '.' || mview_name AS result_object
        FROM dba_mviews
        WHERE owner IN (|' || valid_schema_subquery || q'|)
        ORDER BY owner
       , mview_name|';

        execute_statement(v_finding_sql, c_pdb_name);
        v_finding_types(c_check_mviews).type_results := v_finding_results;

        -- c_check_jobs
        DBMS_APPLICATION_INFO.SET_ACTION(c_check_jobs);

        v_finding_sql := q'|select 'Jobs owned by the ' || log_user || ' user' AS result_message
        ,   count(*) AS result_object
        from dba_jobs
        WHERE log_user IN (|' || valid_schema_subquery || q'|)
        GROUP BY log_user
        UNION
        select  'Jobs where job program owned by the ' || schema_user || ' user' AS result_message
        ,   count(*) AS result_object
        from dba_jobs
        WHERE schema_user IN (|' || valid_schema_subquery || q'|)
        GROUP BY schema_user
        UNION
        select 'Scheduler jobs owned by the ' || owner || ' user' AS result_message
        ,   count(*) AS result_object
        from dba_scheduler_jobs
        WHERE owner IN (|' || valid_schema_subquery || q'|)
        GROUP BY owner
        UNION
        select  'Jobs where job program owned by the ' || program_owner || ' user' AS result_message
        ,   count(*) AS result_object
        from dba_scheduler_jobs
        WHERE program_owner IN (|' || valid_schema_subquery || q'|)
        GROUP BY program_owner
        ORDER BY result_message
       , result_object|';

        execute_statement(v_finding_sql, c_pdb_name);
        v_finding_types(c_check_jobs).type_results := v_finding_results;

        -- c_check_gtts
        DBMS_APPLICATION_INFO.SET_ACTION(c_check_gtts);

        v_finding_sql := q'|SELECT 'Global temporary table' AS result_message
             , owner || '.' || table_name AS result_object
        FROM dba_tables
        WHERE owner IN (|' || valid_schema_subquery || q'|)
        AND temporary = 'Y'
        ORDER BY owner
        , table_name|';

        execute_statement(v_finding_sql, c_pdb_name);
        v_finding_types(c_check_gtts).type_results := v_finding_results;

        -- c_check_table_count
        DBMS_APPLICATION_INFO.SET_ACTION(c_check_table_count);

        v_finding_sql := q'|SELECT 'Count of tables in schema '|| owner AS result_message
             , schema_count || ' of ' || total_count || ' total' AS result_object
        FROM (
            SELECT owner
            , COUNT(*) AS schema_count
            , SUM(COUNT(*)) OVER () AS total_count
            FROM dba_tables
            WHERE owner IN (|' || valid_schema_subquery || q'|)
            GROUP BY owner
            )
        WHERE total_count > 10000
        ORDER BY schema_count DESC|';

        execute_statement(v_finding_sql, c_pdb_name);
        v_finding_types(c_check_table_count).type_results := v_finding_results;

        -- c_check_data_types_nn
        DBMS_APPLICATION_INFO.SET_ACTION(c_check_data_types_nn);

        v_finding_sql := q'|SELECT 'Column '|| c.column_name || ' in table ' || t.owner || '.' || t.table_name AS result_message
             , c.data_type AS result_object
        FROM dba_tables t
            INNER JOIN dba_tab_columns c ON t.owner = c.owner AND t.table_name = c.table_name
            LEFT OUTER JOIN dba_types typ ON c.data_type_owner = typ.owner AND c.data_type = typ.type_name
        WHERE (c.data_type IN (
                       'ANYDATA',
                       'BFILE',
                       'LONG',
                       'LONG RAW',
                       'SDO_GEOMETRY',
                       'UROWID',
                       'XMLTYPE'
               )
               or c.data_type like 'INTERVAL%'
               or typ.type_name IS NOT NULL)
        AND t.owner IN (|' || valid_schema_subquery || q'|)
        AND c.nullable = 'N'
        ORDER BY t.OWNER
       , t.TABLE_NAME
       , c.COLUMN_ID|';

        execute_statement(v_finding_sql, c_pdb_name);
        v_finding_types(c_check_data_types_nn).type_results := v_finding_results;

        -- c_check_data_types_no_nn
        DBMS_APPLICATION_INFO.SET_ACTION(c_check_data_types_no_nn);

        v_finding_sql := q'|SELECT 'Column '|| c.column_name || ' in table ' || t.owner || '.' || t.table_name AS result_message
             , c.data_type AS result_object
        FROM dba_tables t
            INNER JOIN dba_tab_columns c ON t.owner = c.owner AND t.table_name = c.table_name
            LEFT OUTER JOIN dba_types typ ON c.data_type_owner = typ.owner AND c.data_type = typ.type_name
        WHERE (c.data_type IN (
                       'ANYDATA',
                       'BFILE',
                       'LONG',
                       'LONG RAW',
                       'SDO_GEOMETRY',
                       'UROWID',
                       'XMLTYPE'
               )
               or c.data_type like 'INTERVAL%'
               or typ.type_name IS NOT NULL)
        AND t.owner IN (|' || valid_schema_subquery || q'|)
        AND c.nullable = 'Y'
        ORDER BY t.OWNER
       , t.TABLE_NAME
       , c.COLUMN_ID|';

        execute_statement(v_finding_sql, c_pdb_name);
        v_finding_types(c_check_data_types_no_nn).type_results := v_finding_results;

        -- c_check_obj_names
        DBMS_APPLICATION_INFO.SET_ACTION(c_check_obj_names);

        v_finding_sql := q'|SELECT result_message
             , result_object
        FROM (
            SELECT username AS result_object
             , 'Unsupported schema name' AS result_message
            FROM dba_users
            WHERE username IN (|' || valid_schema_subquery || q'|)
            AND REGEXP_LIKE(username, '[^a-zA-Z0-9_]')
        UNION
        SELECT owner || '.' || table_name
             , CASE WHEN table_name LIKE 'MLOG$^_%' ESCAPE '^'
                THEN 'Materialized view table'
                ELSE 'Unsupported table name' END
        FROM dba_tables
        WHERE temporary = 'N'
        AND owner IN (|' || valid_schema_subquery || q'|)
        AND REGEXP_LIKE(table_name, '[^a-zA-Z0-9_]')
        )
        ORDER BY result_message
                , result_object|';

        execute_statement(v_finding_sql, c_pdb_name);
        v_finding_types(c_check_obj_names).type_results := v_finding_results;

        -- c_check_col_names
        DBMS_APPLICATION_INFO.SET_ACTION(c_check_col_names);

        v_finding_sql := q'|SELECT result_message
             , result_object
        FROM (
        SELECT 'Unsupported column name in table ' || t.owner || '.' || t.table_name AS result_message
             , c.column_name AS result_object
        FROM dba_tables t
            INNER JOIN dba_tab_cols c ON
                t.owner = c.owner
                AND t.table_name = c.table_name
        WHERE t.temporary = 'N'
        AND t.owner IN (|' || valid_schema_subquery || q'|)
        AND t.table_name NOT LIKE 'MLOG$^_%' ESCAPE '^'
        AND REGEXP_LIKE(c.column_name, '[^a-zA-Z0-9_]')
        AND c.hidden_column = 'NO'
        )
        ORDER BY result_message
                , result_object|';

        execute_statement(v_finding_sql, c_pdb_name);
        v_finding_types(c_check_col_names).type_results := v_finding_results;

        -- c_check_internal_col_names
        DBMS_APPLICATION_INFO.SET_ACTION(c_check_internal_col_names);

        v_finding_sql := q'|SELECT result_message
             , result_object
        FROM (
        SELECT CASE
            WHEN c.qualified_col_name != c.column_name THEN 'Type '
            WHEN ie.column_expression IS NOT NULL THEN 'Function-based index '
            WHEN l.column_name IS NOT NULL THEN 'LOB '
            WHEN c.column_name LIKE 'SYS_ST%' THEN 'Extended statistics '
            ELSE 'Unknown ' END
            || 'column name in table ' || t.owner || '.' || t.table_name AS result_message
        , c.column_name || ' (' ||
            CASE
                WHEN c.qualified_col_name != c.column_name THEN c.qualified_col_name
                WHEN l.column_name IS NOT NULL THEN l.segment_name
                WHEN ie.column_expression IS NOT NULL THEN 'Column position #' || TO_CHAR(ie.column_position + 1)
                WHEN c.column_name LIKE 'SYS_ST%' THEN 'Not queried'
                ELSE '?'
                END || ')' AS result_object
        FROM dba_tables t
            INNER JOIN dba_tab_cols c ON
                t.owner = c.owner
                AND t.table_name = c.table_name
            LEFT JOIN dba_ind_columns ic ON
                t.owner = ic.table_owner
                AND t.table_name = ic.table_name
                AND c.column_name = ic.column_name
            LEFT JOIN dba_ind_expressions ie ON
                ic.table_owner = ie.table_owner
                AND ic.table_name = ie.table_name
                AND ic.column_position = ie.column_position
            LEFT JOIN dba_lobs l ON
                c.owner = l.owner
                AND c.table_name = l.table_name
                AND c.column_name = l.column_name
        WHERE t.temporary = 'N'
        AND t.owner IN (|' || valid_schema_subquery || q'|)
        AND REGEXP_LIKE(c.column_name, '[^a-zA-Z0-9_]')
        AND c.hidden_column = 'YES'
        )
        ORDER BY result_message
                , result_object|';

        execute_statement(v_finding_sql, c_pdb_name);
        v_finding_types(c_check_internal_col_names).type_results := v_finding_results;


        -- c_check_iots
        DBMS_APPLICATION_INFO.SET_ACTION(c_check_iots);

        v_finding_sql := q'|SELECT 'Unsupported IOT' AS result_message
             , owner || '.' || table_name || NVL2(iot_name, ' [' || iot_name || ']', '') AS result_object
        FROM dba_tables
        WHERE iot_type IS NOT NULL
        AND owner IN (|' || valid_schema_subquery || q'|)
        ORDER BY owner
               , table_name|';

        execute_statement(v_finding_sql, c_pdb_name);
        v_finding_types(c_check_iots).type_results := v_finding_results;

        -- c_check_no_pk
        DBMS_APPLICATION_INFO.SET_ACTION(c_check_no_pk);

        v_finding_sql := q'[SELECT 'Table with no primary key' AS result_message
             , t.owner || '.' || t.table_name AS result_object
        FROM dba_tables t
        WHERE t.temporary = 'N'
        AND t.owner IN (]' || valid_schema_subquery || q'[)
        AND NOT EXISTS (
            SELECT 1
            FROM dba_constraints c
            WHERE c.owner = t.owner
            AND c.table_name = t.table_name
            AND c. constraint_type = 'P'
        )
        ORDER BY t.owner
               , t.table_name]';

        execute_statement(v_finding_sql, c_pdb_name);
        v_finding_types(c_check_no_pk).type_results := v_finding_results;

        -- c_check_charset
        DBMS_APPLICATION_INFO.SET_ACTION(c_check_charset);

        v_finding_sql := q'[SELECT 'Unsupported character set' AS result_message
             , value AS result_object
        FROM nls_database_parameters
        WHERE parameter = 'NLS_CHARACTERSET'
        AND value NOT IN (
            'AL16UTF16', 'AL32UTF8', 'IN8ISCII', 'JA16SJIS', 'US7ASCII', 'UTF8',
            'WE8ISO8859P1', 'WE8ISO8859P9', 'WE8ISO8859P15', 'WE8MSWIN1252', 'ZHT16BIG5')]';

        execute_statement(v_finding_sql, c_pdb_name);
        v_finding_types(c_check_charset).type_results := v_finding_results;

        -- c_check_ols
        DBMS_APPLICATION_INFO.SET_ACTION(c_check_ols);

        IF v_ols_enabled THEN
            v_finding_sql := q'[SELECT 'OLS status set to TRUE' AS result_message
                 , name AS result_object
            FROM dba_ols_status
            WHERE name IN ('OLS_CONFIGURE_STATUS', 'OLS_ENABLE_STATUS')
            AND status = 'TRUE']';
        ELSE
            v_finding_sql := q'[SELECT NULL AS result_message
                 , NULL AS result_object
            FROM dual
            WHERE 1 = 2]';
        END IF;

        execute_statement(v_finding_sql, c_pdb_name);
        v_finding_types(c_check_ols).type_results := v_finding_results;

        -- c_check_oci_db
        DBMS_APPLICATION_INFO.SET_ACTION(c_check_oci_db);

        v_finding_sql := q'[SELECT 'OCI view exists' AS result_message
             , 'OCI_AUTONOMOUS_DATABASES' AS result_object
        FROM dba_views
        WHERE view_name = 'OCI_AUTONOMOUS_DATABASES']';

        execute_statement(v_finding_sql, c_pdb_name);
        v_finding_types(c_check_oci_db).type_results := v_finding_results;

        -- c_check_arch_log_mode
        DBMS_APPLICATION_INFO.SET_ACTION(c_check_arch_log_mode);

        v_finding_sql := q'[SELECT 'Database log mode' AS result_message
             , log_mode AS result_object
        FROM v$database
        WHERE log_mode != 'ARCHIVELOG']';

        execute_statement(v_finding_sql, c_pdb_name);
        v_finding_types(c_check_arch_log_mode).type_results := v_finding_results;

        -- c_check_min_supp_log
        DBMS_APPLICATION_INFO.SET_ACTION(c_check_min_supp_log);

        IF v_is_multitenant THEN
            v_finding_sql := q'[SELECT 'Database minimal supplemental logging' AS result_message
                 , minimal AS result_object
            FROM dba_supplemental_logging
            WHERE minimal != 'YES']';
        ELSE
            v_finding_sql := q'[SELECT 'Database minimal supplemental logging' AS result_message
                 , supplemental_log_data_min AS result_object
            FROM v$database
            WHERE supplemental_log_data_min != 'YES']';
        END IF;

        execute_statement(v_finding_sql, c_pdb_name);
        v_finding_types(c_check_min_supp_log).type_results := v_finding_results;

        -- c_check_obj_supp_log
        DBMS_APPLICATION_INFO.SET_ACTION(c_check_obj_supp_log);

        IF v_is_multitenant THEN
            v_finding_sql := q'[SELECT 'Count of tables without ALL column supplemental logging enabled in schema ' || owner AS result_message
                 , cnt AS result_object
            FROM (
                SELECT t.owner
                 , COUNT(1) AS cnt
                FROM dba_tables t
                WHERE t.temporary = 'N'
                AND t.iot_type IS NULL
                AND t.owner IN (]' || valid_schema_subquery || q'[)
                AND NOT EXISTS (
                    SELECT 1
                    FROM dba_log_groups g
                    WHERE t.owner = g.owner
                    AND t.table_name = g.table_name
                    AND g.log_group_type = 'ALL COLUMN LOGGING'
                )
                AND (SELECT all_column FROM dba_supplemental_logging) != 'YES'
                GROUP BY t.owner
            )
            WHERE cnt > 0]';
        ELSE
            v_finding_sql := q'[SELECT 'Count of tables without ALL column supplemental logging enabled in schema ' || owner AS result_message
                 , cnt AS result_object
            FROM (
                SELECT t.owner
                 , COUNT(1) AS cnt
                FROM dba_tables t
                WHERE t.temporary = 'N'
                AND t.iot_type IS NULL
                AND t.owner IN (]' || valid_schema_subquery || q'[)
                AND NOT EXISTS (
                    SELECT 1
                    FROM dba_log_groups g
                    WHERE t.owner = g.owner
                    AND t.table_name = g.table_name
                    AND g.log_group_type = 'ALL COLUMN LOGGING'
                )
                AND (SELECT supplemental_log_data_all FROM v$database) != 'YES'
                GROUP BY t.owner
            )
            WHERE cnt > 0]';
        END IF;

        execute_statement(v_finding_sql, c_pdb_name);
        v_finding_types(c_check_obj_supp_log).type_results := v_finding_results;

        -- c_check_arch_log_count
        DBMS_APPLICATION_INFO.SET_ACTION(c_check_arch_log_count);

        v_finding_sql := q'[SELECT result_message
             , result_object
        FROM (
            SELECT 'Count of available archive logs' AS result_message
             , COUNT(1) AS result_object
            FROM v$archived_log
            WHERE name IS NOT NULL
            AND deleted = 'NO'
            AND creator != 'LGWR'
        )
        WHERE result_object = 0]';

        execute_statement(v_finding_sql, c_pdb_name);
        v_finding_types(c_check_arch_log_count).type_results := v_finding_results;

        -- c_check_privs_perms
        DBMS_APPLICATION_INFO.SET_ACTION(c_check_privs_perms);

        IF c_cdc_mode = 'LOG_MINER' THEN
            IF v_is_multitenant THEN
                v_finding_sql := q'[SELECT result_message
                     , result_object
                FROM (
                    WITH userprivs AS (SELECT con_id, privilege
                                       FROM cdb_sys_privs
                                       WHERE grantee = ']' || c_user_name || q'['
                                       UNION
                                       SELECT con_id, granted_role
                                       FROM cdb_role_privs
                                       WHERE grantee = ']' || c_user_name || q'['
                                       UNION
                                       SELECT con_id, role_sys_privs.privilege
                                       FROM cdb_role_privs
                                                INNER JOIN role_sys_privs ON cdb_role_privs.granted_role = role_sys_privs.role
                                       WHERE cdb_role_privs.grantee = ']' || c_user_name || q'[')
                   , userdbarole AS (SELECT con_id FROM cdb_role_privs WHERE granted_role = 'DBA' AND grantee = ']' || c_user_name || q'[')
                   , userdictperms AS (SELECT con_id, privilege || ':' || table_name AS permission
                                       FROM cdb_tab_privs
                                       WHERE owner = 'SYS'
                                       AND   grantee = ']' || c_user_name || q'[')
                   , missingusertabs AS (SELECT t.owner
                                         ,      COUNT(1) || '' AS table_count
                                         FROM cdb_tables t
                                         WHERE t.temporary = 'N'
                                           AND t.iot_type IS NULL
                                           AND t.owner IN (]' || valid_schema_subquery(v_pdb_con_id) || q'[)
                                           AND NOT EXISTS (SELECT 1
                                                           FROM cdb_tab_privs p
                                                           WHERE t.owner = p.owner
                                                             AND t.table_name = p.table_name
                                                             AND p.grantee = ']' || c_user_name || q'['
                                                             AND p.con_id = t.con_id)
                                           AND t.con_id = ]' || v_pdb_con_id || q'[
                                           AND (SELECT COUNT(*) FROM userdbarole WHERE con_id = ]' || v_pdb_con_id || q'[) = 0
                                           AND (SELECT COUNT(*) FROM userprivs WHERE privilege = 'SELECT ANY TABLE' AND con_id = ]' || v_pdb_con_id || q'[) = 0
                                         GROUP BY t.owner)
                   , version AS (SELECT TO_NUMBER(REGEXP_SUBSTR(version, '[0-9]+', 1, 1)) AS db_version
                                      , TO_NUMBER(REGEXP_SUBSTR(version, '[0-9]+', 1, 2)) AS db_release
                                 FROM v$instance)
                   , requiredprivs AS (SELECT column_value AS privilege
                                       FROM TABLE (
                                                   CASE
                                                       WHEN (SELECT COUNT(*) FROM userdbarole WHERE con_id = ]' || v_pdb_con_id || q'[) = 0 THEN
                                                           SYS.DBMS_DEBUG_VC2COLL('CREATE SESSION', 'SET CONTAINER')
                                                       ELSE
                                                           SYS.DBMS_DEBUG_VC2COLL()
                                                       END
                                           ))
                   , requiredrootprivs AS (SELECT column_value AS privilege
                                           FROM TABLE (
                                                       CASE
                                                           WHEN (SELECT COUNT(*) FROM userdbarole WHERE con_id = 1) = 0 THEN
                                                               CASE
                                                                   WHEN (SELECT db_version FROM version) > 11 THEN
                                                                       SYS.DBMS_DEBUG_VC2COLL('CREATE SESSION', 'SET CONTAINER',
                                                                                              'EXECUTE_CATALOG_ROLE', 'LOGMINING')
                                                                   ELSE
                                                                       SYS.DBMS_DEBUG_VC2COLL('CREATE SESSION', 'SET CONTAINER',
                                                                                              'EXECUTE_CATALOG_ROLE')
                                                                   END
                                                           ELSE
                                                               SYS.DBMS_DEBUG_VC2COLL()
                                                           END
                                               ))
                   , requireddictperms AS (SELECT column_value AS permission
                                           FROM TABLE (
                                                       CASE
                                                           WHEN (SELECT COUNT(*) FROM userdbarole WHERE con_id = ]' || v_pdb_con_id || q'[) = 0 AND
                                                                (SELECT COUNT(*)
                                                                 FROM userprivs
                                                                 WHERE privilege = 'SELECT ANY DICTIONARY' AND con_id = ]' || v_pdb_con_id || q'[) = 0 THEN
                                                               SYS.DBMS_DEBUG_VC2COLL('SELECT:V_$DATABASE', 'SELECT:V_$ARCHIVED_LOG',
                                                                                      'SELECT:DBA_SUPPLEMENTAL_LOGGING')
                                                           ELSE
                                                               SYS.DBMS_DEBUG_VC2COLL()
                                                           END
                                               ))
                   , requiredrootdictperms AS (SELECT column_value AS permission
                                               FROM TABLE (
                                                           CASE
                                                               WHEN (SELECT COUNT(*) FROM userdbarole WHERE CON_ID = 1) = 0 AND
                                                                    (SELECT COUNT(*)
                                                                      FROM userprivs
                                                                     WHERE privilege = 'SELECT ANY DICTIONARY' AND con_id = 1) = 0 THEN
                                                                   SYS.DBMS_DEBUG_VC2COLL('SELECT:V_$DATABASE',
                                                                                          'SELECT:V_$LOGMNR_CONTENTS',
                                                                                          'EXECUTE:DBMS_LOGMNR',
                                                                                          'EXECUTE:DBMS_LOGMNR_D')
                                                               ELSE
                                                                   SYS.DBMS_DEBUG_VC2COLL()
                                                               END
                                                   ))
                SELECT 'Missing PDB privilege' AS result_message
                     , r.privilege             AS result_object
                FROM requiredprivs r
                         LEFT JOIN userprivs u ON r.privilege = u.privilege AND u.con_id = ]' || v_pdb_con_id || q'[
                WHERE u.privilege IS NULL
                UNION
                SELECT 'Missing CDB$ROOT privilege'
                     , r.privilege
                FROM requiredrootprivs r
                         LEFT JOIN userprivs u ON r.privilege = u.privilege AND u.con_id = 1
                WHERE u.privilege IS NULL
                UNION
                SELECT 'Missing PDB permission'
                     , REPLACE(r.permission, ':', ' on ')
                FROM requireddictperms r
                         LEFT JOIN userdictperms u ON r.permission = u.permission AND u.con_id = ]' || v_pdb_con_id || q'[
                WHERE u.permission IS NULL
                UNION
                SELECT 'Missing CDB$ROOT permission'
                     , REPLACE(r.permission, ':', ' on ')
                FROM requiredrootdictperms r
                         LEFT JOIN userdictperms u ON r.permission = u.permission AND u.con_id = 1
                WHERE u.permission IS NULL
                UNION
                SELECT 'Count of tables with missing SELECT permission in schema ' || owner
                     , t.table_count
                FROM missingusertabs t
                WHERE table_count != '0'
                )
                ORDER BY result_object
                       , result_message]';

                -- this statement *must* run in the CDB$ROOT container
                execute_statement(v_finding_sql);
            ELSE
                v_finding_sql := q'[SELECT result_message
                     , result_object
                FROM (
                    WITH userprivs AS (SELECT privilege
                                       FROM dba_sys_privs
                                       WHERE grantee = ']' || c_user_name || q'['
                                       UNION
                                       SELECT granted_role
                                       FROM dba_role_privs
                                       WHERE grantee = ']' || c_user_name || q'['
                                       UNION
                                       SELECT role_sys_privs.privilege
                                       FROM dba_role_privs
                                                INNER JOIN role_sys_privs ON dba_role_privs.granted_role = role_sys_privs.role
                                       WHERE dba_role_privs.grantee = ']' || c_user_name || q'[')
                   , userdbarole AS (SELECT 1 FROM dba_role_privs WHERE granted_role = 'DBA' AND grantee = ']' || c_user_name || q'[')
                   , userdictperms AS (SELECT privilege || ':' || table_name AS permission
                                       FROM dba_tab_privs
                                       WHERE owner = 'SYS'
                                       AND   grantee = ']' || c_user_name || q'[')
                   , missingusertabs AS (SELECT t.owner
                                         ,      COUNT(1) || '' AS table_count
                                         FROM dba_tables t
                                         WHERE t.temporary = 'N'
                                           AND t.iot_type IS NULL
                                           AND t.owner IN (]' || valid_schema_subquery || q'[)
                                           AND NOT EXISTS (SELECT 1
                                                           FROM dba_tab_privs p
                                                           WHERE t.owner = p.owner
                                                             AND t.table_name = p.table_name
                                                             AND p.grantee = ']' || c_user_name || q'['
                                                           )
                                           AND (SELECT COUNT(*) FROM userdbarole) = 0
                                           AND (SELECT COUNT(*) FROM userprivs WHERE privilege = 'SELECT ANY TABLE') = 0
                                         GROUP BY t.owner)
                   , version AS (SELECT TO_NUMBER(REGEXP_SUBSTR(version, '[0-9]+', 1, 1)) AS db_version
                                      , TO_NUMBER(REGEXP_SUBSTR(version, '[0-9]+', 1, 2)) AS db_release
                                 FROM v$instance)
                   , requiredprivs AS (SELECT column_value AS privilege
                                       FROM TABLE (
                                                   CASE
                                                       WHEN (SELECT COUNT(*) FROM userdbarole) = 0 THEN
                                                           CASE
                                                               WHEN (SELECT db_version FROM version) > 11 THEN
                                                                   SYS.DBMS_DEBUG_VC2COLL('CREATE SESSION', 'LOGMINING')
                                                               ELSE
                                                                   SYS.DBMS_DEBUG_VC2COLL('CREATE SESSION')
                                                               END
                                                       ELSE
                                                           SYS.DBMS_DEBUG_VC2COLL()
                                                       END
                                           ))
                   , requireddictperms AS (SELECT column_value AS permission
                                           FROM TABLE (
                                                       CASE
                                                           WHEN (SELECT COUNT(*) FROM userdbarole) = 0 AND
                                                                (SELECT COUNT(*)
                                                                 FROM userprivs
                                                                 WHERE privilege = 'SELECT ANY DICTIONARY') = 0 THEN
                                                               SYS.DBMS_DEBUG_VC2COLL('SELECT:V_$DATABASE',
                                                                                      'SELECT:V_$ARCHIVED_LOG',
                                                                                      'SELECT:V_$LOGMNR_CONTENTS',
                                                                                      'EXECUTE:DBMS_LOGMNR',
                                                                                      'EXECUTE:DBMS_LOGMNR_D')
                                                           ELSE
                                                               SYS.DBMS_DEBUG_VC2COLL()
                                                           END
                                               ))
                SELECT 'Missing privilege' AS result_message
                     , r.privilege         AS result_object
                FROM requiredprivs r
                         LEFT JOIN userprivs u ON r.privilege = u.privilege
                WHERE u.privilege IS NULL
                UNION
                SELECT 'Missing permission'
                     , REPLACE(r.permission, ':', ' on ')
                FROM requireddictperms r
                         LEFT JOIN userdictperms u ON r.permission = u.permission
                WHERE u.permission IS NULL
                UNION
                SELECT 'Count of tables with missing SELECT permission in schema ' || owner
                     , t.table_count
                FROM missingusertabs t
                WHERE table_count != '0'
                )
                ORDER BY result_object
                       , result_message]';

                execute_statement(v_finding_sql);
            END IF;
        ELSE
            v_finding_sql := q'[SELECT result_message
                 , result_object
            FROM (
                WITH userprivs AS (SELECT privilege
                                   FROM dba_sys_privs
                                   WHERE grantee = ']' || c_user_name || q'['
                                   UNION
                                   SELECT granted_role
                                   FROM dba_role_privs
                                   WHERE grantee = ']' || c_user_name || q'['
                                   UNION
                                   SELECT role_sys_privs.privilege
                                   FROM dba_role_privs
                                            INNER JOIN role_sys_privs ON dba_role_privs.granted_role = role_sys_privs.role
                                   WHERE dba_role_privs.grantee = ']' || c_user_name || q'[')
               , userdbarole AS (SELECT 1 FROM dba_role_privs WHERE granted_role = 'DBA' AND grantee = ']' || c_user_name || q'[')
               , userdictperms AS (SELECT privilege || ':' || table_name AS permission
                                   FROM dba_tab_privs
                                   WHERE owner = 'SYS'
                                   AND   grantee = ']' || c_user_name || q'[')
               , missingusertabs AS (SELECT t.owner
                                     ,      COUNT(1) || '' AS table_count
                                     FROM dba_tables t
                                     WHERE t.temporary = 'N'
                                       AND t.iot_type IS NULL
                                       AND t.owner IN (]' || valid_schema_subquery || q'[)
                                       AND NOT EXISTS (SELECT 1
                                                       FROM dba_tab_privs p
                                                       WHERE t.owner = p.owner
                                                         AND t.table_name = p.table_name
                                                         AND p.grantee = ']' || c_user_name || q'['
                                                       )
                                       AND (SELECT COUNT(*) FROM userdbarole) = 0
                                       AND (SELECT COUNT(*) FROM userprivs WHERE privilege = 'SELECT ANY TABLE') = 0
                                     GROUP BY t.owner)
               , version AS (SELECT TO_NUMBER(REGEXP_SUBSTR(version, '[0-9]+', 1, 1)) AS db_version
                                  , TO_NUMBER(REGEXP_SUBSTR(version, '[0-9]+', 1, 2)) AS db_release
                             FROM v$instance)
               , requiredprivs AS (SELECT column_value AS privilege
                                   FROM TABLE (
                                               CASE
                                                   WHEN (SELECT COUNT(*) FROM userdbarole) = 0 THEN
                                                        SYS.DBMS_DEBUG_VC2COLL('CREATE SESSION'
                                                        ]' || CASE WHEN v_is_multitenant THEN q'[, 'SET CONTAINER']' END
                                                        || q'[)
                                                   ELSE
                                                        SYS.DBMS_DEBUG_VC2COLL()
                                                   END
                                       ))
               , requireddictperms AS (SELECT column_value AS permission
                                       FROM TABLE (
                                                   CASE
                                                       WHEN (SELECT COUNT(*) FROM userdbarole) = 0 AND
                                                            (SELECT COUNT(*)
                                                             FROM userprivs
                                                             WHERE privilege = 'SELECT ANY DICTIONARY') = 0 THEN
                                                           SYS.DBMS_DEBUG_VC2COLL(
                                                           'SELECT:V_$DATABASE',
                                                           'SELECT:V_$ARCHIVED_LOG',
                                                           'SELECT:GV_$ARCHIVED_LOG',
                                                           'SELECT:GV_$LOG',
                                                           'SELECT:COL$',
                                                           'SELECT:GV_$LOGFILE',
                                                           'SELECT:GV_$INSTANCE',
                                                           'SELECT:V_$TRANSPORTABLE_PLATFORM',
                                                           'SELECT:GV_$STANDBY_LOG',
                                                           'SELECT:V_$PDBS',
                                                           'SELECT:DBA_OBJECTS',
                                                           'SELECT:DBA_TABLESPACES',
                                                           'SELECT:DBA_ENCRYPTED_COLUMNS'
                                                           ]' || CASE WHEN v_is_multitenant THEN q'[, 'SELECT:DBA_SUPPLEMENTAL_LOGGING']' END
                                                           || q'[)
                                                       ELSE
                                                           SYS.DBMS_DEBUG_VC2COLL()
                                                       END
                                           ))
            SELECT 'Missing privilege' AS result_message
                 , r.privilege         AS result_object
            FROM requiredprivs r
                     LEFT JOIN userprivs u ON r.privilege = u.privilege
            WHERE u.privilege IS NULL
            UNION
            SELECT 'Missing permission'
                 , REPLACE(r.permission, ':', ' on ')
            FROM requireddictperms r
                     LEFT JOIN userdictperms u ON r.permission = u.permission
            WHERE u.permission IS NULL
            UNION
            SELECT 'Count of tables with missing SELECT permission in schema ' || owner
                 , t.table_count
            FROM missingusertabs t
            WHERE table_count != '0'
            )
            ORDER BY result_object
                   , result_message]';

            IF v_is_multitenant THEN
                execute_statement(v_finding_sql, c_pdb_name);
            ELSE
                execute_statement(v_finding_sql);
            END IF;
        END IF;

        v_finding_types(c_check_privs_perms).type_results := v_finding_results;

        -- Loop through all findings and get a count by severity
        v_index_val := v_finding_types.FIRST;
        WHILE v_index_val IS NOT NULL LOOP
            IF v_finding_types(v_index_val).type_severity = c_finding_critical
            AND v_finding_types(v_index_val).type_results.COUNT > 0
            THEN
                v_critical_count := v_critical_count + 1;
            ELSIF v_finding_types(v_index_val).type_severity = c_finding_warning
            AND v_finding_types(v_index_val).type_results.COUNT > 0
            THEN
                v_warning_count := v_warning_count + 1;
            ELSIF v_finding_types(v_index_val).type_severity = c_finding_information
            AND v_finding_types(v_index_val).type_results.COUNT > 0
            THEN
                v_information_count := v_information_count + 1;
            ELSE
                v_finding_types(v_index_val).type_severity := c_finding_noissues;
                v_noissues_count := v_noissues_count + 1;
            END IF;
            v_index_val := v_finding_types.NEXT(v_index_val);
        END LOOP;

        -- Print severity count
        section_header('Findings summary', '=');
        report_summary;
        section_footer;

        -- print the findings
        section_header('Findings detail', '=');
        -- critical
        v_index_val := v_finding_types.FIRST;
        WHILE v_index_val IS NOT NULL LOOP
            IF v_finding_types(v_index_val).type_severity = c_finding_critical
            AND v_finding_types(v_index_val).type_results.COUNT > 0
            THEN
                report_finding(v_index_val);
            END IF;
            v_index_val := v_finding_types.NEXT(v_index_val);
        END LOOP;
        -- warning
        v_index_val := v_finding_types.FIRST;
        WHILE v_index_val IS NOT NULL LOOP
            IF v_finding_types(v_index_val).type_severity = c_finding_warning
            AND v_finding_types(v_index_val).type_results.COUNT > 0
            THEN
                report_finding(v_index_val);
            END IF;
            v_index_val := v_finding_types.NEXT(v_index_val);
        END LOOP;
        -- information
        v_index_val := v_finding_types.FIRST;
        WHILE v_index_val IS NOT NULL LOOP
            IF v_finding_types(v_index_val).type_severity = c_finding_information
            AND v_finding_types(v_index_val).type_results.COUNT > 0
            THEN
                report_finding(v_index_val);
            END IF;
            v_index_val := v_finding_types.NEXT(v_index_val);
        END LOOP;
        -- no issues
        v_index_val := v_finding_types.FIRST;
        WHILE v_index_val IS NOT NULL LOOP
            IF v_finding_types(v_index_val).type_severity = c_finding_noissues
            --AND v_finding_types(v_index_val).type_results.COUNT > 0
            THEN
                report_finding(v_index_val);
            END IF;
            v_index_val := v_finding_types.NEXT(v_index_val);
        END LOOP;
        section_footer;

        -- Print report metadata
        section_header('Report metadata', '=');
        report_metadata;
        section_footer;

        report_footer;

        DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL);
        DBMS_APPLICATION_INFO.SET_ACTION('Completed');
    ELSE
        p('');
        p(sql_message);
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_APPLICATION_INFO.SET_MODULE(NULL, NULL);
        DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL);
        RAISE;
END;
/

spool off

set termout on

prompt
prompt Google Database Migration Service Migration Job Validation completed&_input_errors..
prompt

set termout on
exit
