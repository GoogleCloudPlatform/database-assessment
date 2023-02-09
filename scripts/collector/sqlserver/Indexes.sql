select a.table_view,
a.index_type,
 count(a.index_type) as index_count
 from (
select
    schema_name(t.schema_id) + '.' + t.[name] as table_view, 
--i.[name] as index_name,
    case when i.[type] = 1 then 'Clustered index'
        when i.[type] = 2 then 'Nonclustered unique index'
        when i.[type] = 3 then 'XML index'
        when i.[type] = 4 then 'Spatial index'
        when i.[type] = 5 then 'Clustered columnstore index'
        when i.[type] = 6 then 'Nonclustered columnstore index'
        when i.[type] = 7 then 'Nonclustered hash index'
        end as index_type
from sys.objects t
inner join sys.indexes i
on t.object_id = i.object_id
where t.is_ms_shipped <> 1
and index_id > 0 ) as a
group by a.table_view,
a.index_type
order by index_count desc;