-- Test startup script that runs every time the container starts
-- This demonstrates the on_startup functionality

-- Switch to the PDB (Pluggable Database)
ALTER SESSION SET CONTAINER = freepdb1;

-- Simple test query to verify startup script execution
SELECT 'Startup script executed successfully at ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') AS startup_message FROM DUAL;
