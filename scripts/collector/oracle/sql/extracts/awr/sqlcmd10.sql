 INNER JOIN
(
SELECT 0 AS command_type,'' AS command_name FROM dual UNION ALL
SELECT 1 AS command_type,'CREATE TABLE' AS command_name FROM dual UNION ALL
SELECT 2 AS command_type,'INSERT' AS command_name FROM dual UNION ALL
SELECT 3 AS command_type,'SELECT' AS command_name FROM dual UNION ALL
SELECT 4 AS command_type,'CREATE CLUSTER' AS command_name FROM dual UNION ALL
SELECT 5 AS command_type,'ALTER CLUSTER' AS command_name FROM dual UNION ALL
SELECT 6 AS command_type,'UPDATE' AS command_name FROM dual UNION ALL
SELECT 7 AS command_type,'DELETE' AS command_name FROM dual UNION ALL
SELECT 8 AS command_type,'DROP CLUSTER' AS command_name FROM dual UNION ALL
SELECT 9 AS command_type,'CREATE INDEX' AS command_name FROM dual UNION ALL
SELECT 10 AS command_type,'DROP INDEX' AS command_name FROM dual UNION ALL
SELECT 11 AS command_type,'ALTER INDEX' AS command_name FROM dual UNION ALL
SELECT 12 AS command_type,'DROP TABLE' AS command_name FROM dual UNION ALL
SELECT 13 AS command_type,'CREATE SEQUENCE' AS command_name FROM dual UNION ALL
SELECT 14 AS command_type,'ALTER SEQUENCE' AS command_name FROM dual UNION ALL
SELECT 15 AS command_type,'ALTER TABLE' AS command_name FROM dual UNION ALL
SELECT 16 AS command_type,'DROP SEQUENCE' AS command_name FROM dual UNION ALL
SELECT 17 AS command_type,'GRANT OBJECT' AS command_name FROM dual UNION ALL
SELECT 18 AS command_type,'REVOKE OBJECT' AS command_name FROM dual UNION ALL
SELECT 19 AS command_type,'CREATE SYNONYM' AS command_name FROM dual UNION ALL
SELECT 20 AS command_type,'DROP SYNONYM' AS command_name FROM dual UNION ALL
SELECT 21 AS command_type,'CREATE VIEW' AS command_name FROM dual UNION ALL
SELECT 22 AS command_type,'DROP VIEW' AS command_name FROM dual UNION ALL
SELECT 23 AS command_type,'VALIDATE INDEX' AS command_name FROM dual UNION ALL
SELECT 24 AS command_type,'CREATE PROCEDURE' AS command_name FROM dual UNION ALL
SELECT 25 AS command_type,'ALTER PROCEDURE' AS command_name FROM dual UNION ALL
SELECT 26 AS command_type,'LOCK TABLE' AS command_name FROM dual UNION ALL
SELECT 27 AS command_type,'NO-OP' AS command_name FROM dual UNION ALL
SELECT 28 AS command_type,'RENAME' AS command_name FROM dual UNION ALL
SELECT 29 AS command_type,'COMMENT' AS command_name FROM dual UNION ALL
SELECT 30 AS command_type,'AUDIT OBJECT' AS command_name FROM dual UNION ALL
SELECT 31 AS command_type,'NOAUDIT OBJECT' AS command_name FROM dual UNION ALL
SELECT 32 AS command_type,'CREATE DATABASE LINK' AS command_name FROM dual UNION ALL
SELECT 33 AS command_type,'DROP DATABASE LINK' AS command_name FROM dual UNION ALL
SELECT 34 AS command_type,'CREATE DATABASE' AS command_name FROM dual UNION ALL
SELECT 35 AS command_type,'ALTER DATABASE' AS command_name FROM dual UNION ALL
SELECT 36 AS command_type,'CREATE ROLLBACK SEG' AS command_name FROM dual UNION ALL
SELECT 37 AS command_type,'ALTER ROLLBACK SEG' AS command_name FROM dual UNION ALL
SELECT 38 AS command_type,'DROP ROLLBACK SEG' AS command_name FROM dual UNION ALL
SELECT 39 AS command_type,'CREATE TABLESPACE' AS command_name FROM dual UNION ALL
SELECT 40 AS command_type,'ALTER TABLESPACE' AS command_name FROM dual UNION ALL
SELECT 41 AS command_type,'DROP TABLESPACE' AS command_name FROM dual UNION ALL
SELECT 42 AS command_type,'ALTER SESSION' AS command_name FROM dual UNION ALL
SELECT 43 AS command_type,'ALTER USER' AS command_name FROM dual UNION ALL
SELECT 44 AS command_type,'COMMIT' AS command_name FROM dual UNION ALL
SELECT 45 AS command_type,'ROLLBACK' AS command_name FROM dual UNION ALL
SELECT 46 AS command_type,'SAVEPOINT' AS command_name FROM dual UNION ALL
SELECT 47 AS command_type,'PL/SQL EXECUTE' AS command_name FROM dual UNION ALL
SELECT 48 AS command_type,'SET TRANSACTION' AS command_name FROM dual UNION ALL
SELECT 49 AS command_type,'ALTER SYSTEM' AS command_name FROM dual UNION ALL
SELECT 50 AS command_type,'EXPLAIN' AS command_name FROM dual UNION ALL
SELECT 51 AS command_type,'CREATE USER' AS command_name FROM dual UNION ALL
SELECT 52 AS command_type,'CREATE ROLE' AS command_name FROM dual UNION ALL
SELECT 53 AS command_type,'DROP USER' AS command_name FROM dual UNION ALL
SELECT 54 AS command_type,'DROP ROLE' AS command_name FROM dual UNION ALL
SELECT 55 AS command_type,'SET ROLE' AS command_name FROM dual UNION ALL
SELECT 56 AS command_type,'CREATE SCHEMA' AS command_name FROM dual UNION ALL
SELECT 57 AS command_type,'CREATE CONTROL FILE' AS command_name FROM dual UNION ALL
SELECT 58 AS command_type,'ALTER TRACING' AS command_name FROM dual UNION ALL
SELECT 59 AS command_type,'CREATE TRIGGER' AS command_name FROM dual UNION ALL
SELECT 60 AS command_type,'ALTER TRIGGER' AS command_name FROM dual UNION ALL
SELECT 61 AS command_type,'DROP TRIGGER' AS command_name FROM dual UNION ALL
SELECT 62 AS command_type,'ANALYZE TABLE' AS command_name FROM dual UNION ALL
SELECT 63 AS command_type,'ANALYZE INDEX' AS command_name FROM dual UNION ALL
SELECT 64 AS command_type,'ANALYZE CLUSTER' AS command_name FROM dual UNION ALL
SELECT 65 AS command_type,'CREATE PROFILE' AS command_name FROM dual UNION ALL
SELECT 66 AS command_type,'DROP PROFILE' AS command_name FROM dual UNION ALL
SELECT 67 AS command_type,'ALTER PROFILE' AS command_name FROM dual UNION ALL
SELECT 68 AS command_type,'DROP PROCEDURE' AS command_name FROM dual UNION ALL
SELECT 70 AS command_type,'ALTER RESOURCE COST' AS command_name FROM dual UNION ALL
SELECT 71 AS command_type,'CREATE MATERIALIZED VIEW LOG' AS command_name FROM dual UNION ALL
SELECT 72 AS command_type,'ALTER MATERIALIZED VIEW LOG' AS command_name FROM dual UNION ALL
SELECT 73 AS command_type,'DROP MATERIALIZED VIEW  LOG' AS command_name FROM dual UNION ALL
SELECT 74 AS command_type,'CREATE MATERIALIZED VIEW ' AS command_name FROM dual UNION ALL
SELECT 75 AS command_type,'ALTER MATERIALIZED VIEW ' AS command_name FROM dual UNION ALL
SELECT 76 AS command_type,'DROP MATERIALIZED VIEW ' AS command_name FROM dual UNION ALL
SELECT 77 AS command_type,'CREATE TYPE' AS command_name FROM dual UNION ALL
SELECT 78 AS command_type,'DROP TYPE' AS command_name FROM dual UNION ALL
SELECT 79 AS command_type,'ALTER ROLE' AS command_name FROM dual UNION ALL
SELECT 80 AS command_type,'ALTER TYPE' AS command_name FROM dual UNION ALL
SELECT 81 AS command_type,'CREATE TYPE BODY' AS command_name FROM dual UNION ALL
SELECT 82 AS command_type,'ALTER TYPE BODY' AS command_name FROM dual UNION ALL
SELECT 83 AS command_type,'DROP TYPE BODY' AS command_name FROM dual UNION ALL
SELECT 84 AS command_type,'DROP LIBRARY' AS command_name FROM dual UNION ALL
SELECT 85 AS command_type,'TRUNCATE TABLE' AS command_name FROM dual UNION ALL
SELECT 86 AS command_type,'TRUNCATE CLUSTER' AS command_name FROM dual UNION ALL
SELECT 87 AS command_type,'CREATE BITMAPFILE' AS command_name FROM dual UNION ALL
SELECT 88 AS command_type,'ALTER VIEW' AS command_name FROM dual UNION ALL
SELECT 89 AS command_type,'DROP BITMAPFILE' AS command_name FROM dual UNION ALL
SELECT 90 AS command_type,'SET CONSTRAINTS' AS command_name FROM dual UNION ALL
SELECT 91 AS command_type,'CREATE FUNCTION' AS command_name FROM dual UNION ALL
SELECT 92 AS command_type,'ALTER FUNCTION' AS command_name FROM dual UNION ALL
SELECT 93 AS command_type,'DROP FUNCTION' AS command_name FROM dual UNION ALL
SELECT 94 AS command_type,'CREATE PACKAGE' AS command_name FROM dual UNION ALL
SELECT 95 AS command_type,'ALTER PACKAGE' AS command_name FROM dual UNION ALL
SELECT 96 AS command_type,'DROP PACKAGE' AS command_name FROM dual UNION ALL
SELECT 97 AS command_type,'CREATE PACKAGE BODY' AS command_name FROM dual UNION ALL
SELECT 98 AS command_type,'ALTER PACKAGE BODY' AS command_name FROM dual UNION ALL
SELECT 99 AS command_type,'DROP PACKAGE BODY' AS command_name FROM dual UNION ALL
SELECT 157 AS command_type,'CREATE DIRECTORY' AS command_name FROM dual UNION ALL
SELECT 158 AS command_type,'DROP DIRECTORY' AS command_name FROM dual UNION ALL
SELECT 159 AS command_type,'CREATE LIBRARY' AS command_name FROM dual UNION ALL
SELECT 160 AS command_type,'CREATE JAVA' AS command_name FROM dual UNION ALL
SELECT 161 AS command_type,'ALTER JAVA' AS command_name FROM dual UNION ALL
SELECT 162 AS command_type,'DROP JAVA' AS command_name FROM dual UNION ALL
SELECT 163 AS command_type,'CREATE OPERATOR' AS command_name FROM dual UNION ALL
SELECT 164 AS command_type,'CREATE INDEXTYPE' AS command_name FROM dual UNION ALL
SELECT 165 AS command_type,'DROP INDEXTYPE' AS command_name FROM dual UNION ALL
SELECT 166 AS command_type,'ALTER INDEXTYPE' AS command_name FROM dual UNION ALL
SELECT 167 AS command_type,'DROP OPERATOR' AS command_name FROM dual UNION ALL
SELECT 168 AS command_type,'ASSOCIATE STATISTICS' AS command_name FROM dual UNION ALL
SELECT 169 AS command_type,'DISASSOCIATE STATISTICS' AS command_name FROM dual UNION ALL
SELECT 170 AS command_type,'CALL METHOD' AS command_name FROM dual UNION ALL
SELECT 171 AS command_type,'CREATE SUMMARY' AS command_name FROM dual UNION ALL
SELECT 172 AS command_type,'ALTER SUMMARY' AS command_name FROM dual UNION ALL
SELECT 173 AS command_type,'DROP SUMMARY' AS command_name FROM dual UNION ALL
SELECT 174 AS command_type,'CREATE DIMENSION' AS command_name FROM dual UNION ALL
SELECT 175 AS command_type,'ALTER DIMENSION' AS command_name FROM dual UNION ALL
SELECT 176 AS command_type,'DROP DIMENSION' AS command_name FROM dual UNION ALL
SELECT 177 AS command_type,'CREATE CONTEXT' AS command_name FROM dual UNION ALL
SELECT 178 AS command_type,'DROP CONTEXT' AS command_name FROM dual UNION ALL
SELECT 179 AS command_type,'ALTER OUTLINE' AS command_name FROM dual UNION ALL
SELECT 180 AS command_type,'CREATE OUTLINE' AS command_name FROM dual UNION ALL
SELECT 181 AS command_type,'DROP OUTLINE' AS command_name FROM dual UNION ALL
SELECT 182 AS command_type,'UPDATE INDEXES' AS command_name FROM dual UNION ALL
SELECT 183 AS command_type,'ALTER OPERATOR' AS command_name FROM dual UNION ALL
SELECT 184 AS command_type,'Do not use 184' AS command_name FROM dual UNION ALL
SELECT 185 AS command_type,'Do not use 185' AS command_name FROM dual UNION ALL
SELECT 186 AS command_type,'Do not use 186' AS command_name FROM dual UNION ALL
SELECT 187 AS command_type,'CREATE SPFILE' AS command_name FROM dual UNION ALL
SELECT 188 AS command_type,'CREATE PFILE' AS command_name FROM dual UNION ALL
SELECT 189 AS command_type,'UPSERT' AS command_name FROM dual UNION ALL
SELECT 190 AS command_type,'CHANGE PASSWORD' AS command_name FROM dual UNION ALL
SELECT 191 AS command_type,'UPDATE JOIN INDEX' AS command_name FROM dual UNION ALL
SELECT 192 AS command_type,'ALTER SYNONYM' AS command_name FROM dual UNION ALL
SELECT 193 AS command_type,'ALTER DISK GROUP' AS command_name FROM dual UNION ALL
SELECT 194 AS command_type,'CREATE DISK GROUP' AS command_name FROM dual UNION ALL
SELECT 195 AS command_type,'DROP DISK GROUP' AS command_name FROM dual UNION ALL
SELECT 196 AS command_type,'ALTER LIBRARY' AS command_name FROM dual UNION ALL
SELECT 197 AS command_type,'PURGE USER RECYCLEBIN' AS command_name FROM dual UNION ALL
SELECT 198 AS command_type,'PURGE DBA RECYCLEBIN' AS command_name FROM dual UNION ALL
SELECT 199 AS command_type,'PURGE TABLESPACE' AS command_name FROM dual UNION ALL
SELECT 200 AS command_type,'PURGE TABLE' AS command_name FROM dual UNION ALL
SELECT 201 AS command_type,'PURGE INDEX' AS command_name FROM dual UNION ALL
SELECT 202 AS command_type,'UNDROP OBJECT' AS command_name FROM dual UNION ALL
SELECT 203 AS command_type,'DROP DATABASE' AS command_name FROM dual UNION ALL
SELECT 204 AS command_type,'FLASHBACK DATABASE' AS command_name FROM dual UNION ALL
SELECT 205 AS command_type,'FLASHBACK TABLE' AS command_name FROM dual UNION ALL
SELECT 206 AS command_type,'CREATE RESTORE POINT' AS command_name FROM dual UNION ALL
SELECT 207 AS command_type,'DROP RESTORE POINT' AS command_name FROM dual UNION ALL
SELECT 209 AS command_type,'DECLARE REWRITE EQUIVALENCE' AS command_name FROM dual UNION ALL
SELECT 210 AS command_type,'ALTER REWRITE EQUIVALENCE' AS command_name FROM dual UNION ALL
SELECT 211 AS command_type,'DROP REWRITE EQUIVALENCE' AS command_name FROM dual UNION ALL
SELECT 212 AS command_type,'CREATE EDITION' AS command_name FROM dual UNION ALL
SELECT 213 AS command_type,'ALTER EDITION' AS command_name FROM dual UNION ALL
SELECT 214 AS command_type,'DROP EDITION' AS command_name FROM dual UNION ALL
SELECT 215 AS command_type,'DROP ASSEMBLY' AS command_name FROM dual UNION ALL
SELECT 216 AS command_type,'CREATE ASSEMBLY' AS command_name FROM dual UNION ALL
SELECT 217 AS command_type,'ALTER ASSEMBLY' AS command_name FROM dual UNION ALL
SELECT 218 AS command_type,'CREATE FLASHBACK ARCHIVE' AS command_name FROM dual UNION ALL
SELECT 219 AS command_type,'ALTER FLASHBACK ARCHIVE' AS command_name FROM dual UNION ALL
SELECT 220 AS command_type,'DROP FLASHBACK ARCHIVE' AS command_name FROM dual UNION ALL
SELECT 222 AS command_type,'CREATE SCHEMA SYNONYM' AS command_name FROM dual UNION ALL
SELECT 224 AS command_type,'DROP SCHEMA SYNONYM' AS command_name FROM dual UNION ALL
SELECT 225 AS command_type,'ALTER DATABASE LINK' AS command_name FROM dual )
 scmd
