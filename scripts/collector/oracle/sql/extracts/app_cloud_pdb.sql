define cdbjoin = "AND con_id = p.con_id"
spool &outputdir/opdb__app_cloud_pdb_&v_tag
WITH app_cloud as ( 
SELECT
@&EXTRACTSDIR/app_schemas.sql
FROM DUAL
)
SELECT 'EBS_OWNER:                ' || ebs_owner
FROM app_cloud
UNION
SELECT 'SIEBEL_OWNER:             ' || siebel_owner
FROM app_cloud
UNION
SELECT 'PSFT_OWNER:               ' || psft_owner
FROM app_cloud
UNION
SELECT 'RDS_FLAG:                 ' || rds_flag
FROM app_cloud
UNION
SELECT 'OCI_AUTONOMOUS_FLAG:      ' || oci_autonomous_flag
FROM app_cloud
UNION
SELECT 'DBMS_CLOUD_PKG_INSTALLED: ' || dbms_cloud_pkg_installed
FROM app_cloud;
spool off

