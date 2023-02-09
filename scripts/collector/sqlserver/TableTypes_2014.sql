select schema_name(schema_id) as schema_name,
       name as table_name,
        case when is_filetable = 1 then 'File table'
			when is_memory_optimized <> 0 then 'in-memory table'
            else 'User Table'
        end as table_type
        from sys.tables