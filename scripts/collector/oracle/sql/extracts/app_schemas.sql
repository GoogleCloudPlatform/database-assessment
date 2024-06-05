--
-- Copyright 2024 Google LLC
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
        (
        SELECT CASE WHEN table_name = 'FND_PRODUCT_GROUPS' AND column_name = 'RELEASE_NAME' AND data_type = 'VARCHAR2' THEN owner END AS ebs_owner
        FROM &v_tblprefix._tab_columns
        WHERE ( table_name = 'FND_PRODUCT_GROUPS'  -- EBS
           AND column_name = 'RELEASE_NAME'
           AND data_type = 'VARCHAR2'
           AND rownum = 1
           &cdbjoin
           )
           ) as ebs_owner,
        (
        SELECT CASE WHEN table_name = 'S_REPOSITORY'       AND column_name = 'ROW_ID'       AND data_type = 'VARCHAR2' THEN owner END AS siebel_owner
        FROM &v_tblprefix._tab_columns
        WHERE ( table_name = 'S_REPOSITORY'           -- Siebel
           AND column_name = 'ROW_ID'
           AND data_type = 'VARCHAR2'
           AND rownum = 1
           &cdbjoin
           )
           ) as siebel_owner,
          (
        SELECT CASE WHEN table_name = 'PSSTATUS'           AND column_name = 'TOOLSREL'     AND data_type = 'VARCHAR2' THEN owner END AS psft_owner
        FROM &v_tblprefix._tab_columns
        WHERE ( table_name = 'PSSTATUS'               -- PeopleSoft
           AND column_name = 'TOOLSREL'
           AND data_type = 'VARCHAR2'
           AND rownum = 1
           &cdbjoin
        )
        ) as psft_owner,
        (SELECT RPAD('Y',30)
         FROM &v_tblprefix._objects
         WHERE owner = 'RDSADMIN'
           AND object_name = 'RDAADMIN_UTIL'
           &cdbjoin
           AND ROWNUM = 1) AS rds_flag,
         (SELECT RPAD('Y',30)
          FROM &v_tblprefix._views
          WHERE view_name ='OCI_AUTONOMOUS_DATABASES'
            &cdbjoin
            AND ROWNUM = 1) AS oci_autonomous_flag,
         (SELECT RPAD('Y',30)
          FROM &v_tblprefix._objects
          WHERE object_name = 'DBMS_CLOUD'
            &cdbjoin
            AND owner = (SELECT value
                         FROM v$parameter
                         WHERE name = 'common_user_prefix'
                         &cdbjoin
                        ) || 'CLOUD$SERVICE'
            AND ROWNUM = 1) AS dbms_cloud_pkg_installed,
         (SELECT RPAD('Y',30)
          FROM &v_tblprefix._objects
          WHERE object_name = 'WWV_FLOW'
            AND object_type = 'PACKAGE'
            AND ROWNUM = 1
            &cdbjoin
            AND EXISTS (SELECT 1 FROM &v_tblprefix._users
                        WHERE username ='apex_public_user'
                        &cdbjoin
                       )) AS apex_installed ,
        (SELECT CASE WHEN table_name = 'DD02T'           AND column_name = 'DDLANGUAGE'     AND data_type = 'VARCHAR2' THEN owner END AS sap_owner
        FROM &v_tblprefix._tab_columns
        WHERE ( table_name = 'DD02T'               -- SAP
           AND column_name = 'DDLANGUAGE'
           AND data_type = 'VARCHAR2'
           AND rownum = 1
           &cdbjoin
        )
        ) as sap_owner
