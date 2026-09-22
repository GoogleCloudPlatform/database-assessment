-- Copyright 2024 Google LLC
--
-- Licensed under the Apache License, Version 2.0 (the "License");
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

-- Creates the default assessment user and applies required grants for DB2
-- In DB2 LUW, authentication is typically handled by the OS/LDAP/PAM.
-- Create the OS user 'dma_collector' first, then run this script as an administrator.

GRANT CONNECT ON DATABASE TO USER dma_collector;

GRANT SELECT ON TABLE SYSCAT.TABLES TO USER dma_collector;
GRANT SELECT ON TABLE SYSCAT.COLUMNS TO USER dma_collector;
GRANT SELECT ON TABLE SYSCAT.INDEXES TO USER dma_collector;
GRANT SELECT ON TABLE SYSCAT.TABCONST TO USER dma_collector;
GRANT SELECT ON TABLE SYSCAT.REFERENCES TO USER dma_collector;
GRANT SELECT ON TABLE SYSCAT.ROUTINES TO USER dma_collector;
GRANT SELECT ON TABLE SYSCAT.TRIGGERS TO USER dma_collector;
GRANT SELECT ON TABLE SYSCAT.VIEWS TO USER dma_collector;
GRANT SELECT ON TABLE SYSCAT.DATAPARTITIONS TO USER dma_collector;
GRANT SELECT ON TABLE SYSCAT.CONTROLS TO USER dma_collector;

GRANT SELECT ON TABLE SYSIBMADM.DBCFG TO USER dma_collector;
GRANT SELECT ON TABLE SYSIBMADM.DBMCFG TO USER dma_collector;
GRANT SELECT ON TABLE SYSIBMADM.ENV_INST_INFO TO USER dma_collector;
GRANT SELECT ON TABLE SYSIBMADM.ENV_SYS_INFO TO USER dma_collector;
GRANT SELECT ON TABLE SYSIBMADM.ENV_PROD_INFO TO USER dma_collector;

GRANT EXECUTE ON FUNCTION SYSPROC.MON_GET_INSTANCE TO USER dma_collector;
GRANT EXECUTE ON FUNCTION SYSPROC.MON_GET_DATABASE TO USER dma_collector;
GRANT EXECUTE ON FUNCTION SYSPROC.MON_GET_TABLESPACE TO USER dma_collector;
GRANT EXECUTE ON FUNCTION SYSPROC.MON_GET_BUFFERPOOL TO USER dma_collector;
GRANT EXECUTE ON FUNCTION SYSPROC.MON_GET_TRANSACTION_LOG TO USER dma_collector;
GRANT EXECUTE ON FUNCTION SYSPROC.ENV_GET_INST_INFO TO USER dma_collector;
GRANT EXECUTE ON FUNCTION SYSPROC.ENV_GET_PROD_INFO TO USER dma_collector;
