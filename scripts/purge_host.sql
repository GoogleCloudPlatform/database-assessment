Create or replace procedure `projectID.dataset.P_DS_PURGE_HOST` (IN p_hostname STRING)
Begin
   FOR tablist IN (SELECT table_name, column_name
                   FROM `projectID.dataset.INFORMATION_SCHEMA.COLUMNS`
                   WHERE lower(column_name) LIKE '%pkey%'
                     AND TABLE_NAME NOT IN (select table_name FROM `projectID.dataset.INFORMATION_SCHEMA.VIEWS`)
                   ORDER BY table_name) DO

     execute immediate "DELETE FROM `projectID.dataset." || tablist.table_name || "` WHERE " || tablist.column_name || " IN  (SELECT DISTINCT pkey FROM `projectID.dataset.dbinstances` WHERE host_name = ? ) " USING p_hostname;
    END FOR;
End;

