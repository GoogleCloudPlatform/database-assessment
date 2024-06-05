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
(SELECT USERNAME
 FROM &v_tblprefix._users
 WHERE username IN ('ORDS_METADATA','ORDS_PUBLIC_USER','APEX_PUBLIC_USER', 'FLOWS_FILES', 'PERFSTAT', 'ORDSYS', 'MDSYS',
                    'TSMSYS', 'WMSYS', 'CTXSYS', 'DMSYS', 'EXFSYS', 'OLAPSYS', 'XDB'
                    ,'DBA_ADM','SYSTEM','CTXSYS','DBSNMP','EXFSYS','LBACSYS','MDSYS','MGMT_VIEW','OLAPSYS','ORDDATA','OWBSYS','ORDPLUGINS','ORDSYS','OUTLN','SI_INFORMTN_SCHEMA','SYS','SYSMAN','WK_TEST','WKSYS','WKPROXY','WMSYS','XDB','APEX_PUBLIC_USER','DIP','FLOWS_020100','FLOWS_030000','FLOWS_040100','FLOWS_010600','FLOWS_FILES','MDDATA','ORACLE_OCM','SPATIAL_CSW_ADMIN_USR','SPATIAL_WFS_ADMIN_USR','XS$NULL','PERFSTAT','SQLTXPLAIN','DMSYS','TSMSYS','WKSYS','APEX_040000','APEX_040200','DVSYS','OJVMSYS','GSMADMIN_INTERNAL','APPQOSSYS','DVSYS','DVF','AUDSYS','APEX_030200','MGMT_VIEW','ODM','ODM_MTR','TRACESRV','MTMSYS','OWBSYS_AUDIT','WEBSYS','WK_PROXY','OSE$HTTP$ADMIN','AURORA$JIS$UTILITY$','AURORA$ORB$UNAUTHENTICATED','DBMS_PRIVILEGE_CAPTURE','CSMIG','MGDSYS','SDE','DBSFWUSER')
   OR username LIKE 'WWV_FLOWS%'
   OR username LIKE 'APEX%'
   OR username LIKE '%GGADMIN'
   OR username IN ( SELECT name FROM system.logstdby$skip_support where action=0)
)
