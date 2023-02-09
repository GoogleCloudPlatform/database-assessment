select tab.name  as table_name, 
	t.name as data_type,
	t.precision,
	t.scale,
    count(*) as [countofcolumns]
  from sys.tables as tab
       inner join sys.columns as col
        on tab.object_id = col.object_id
       left join sys.types as t
        on col.user_type_id = t.user_type_id
group by tab.name, t.name, t.precision, t.scale
UNION
--getting all computed columns
select object_name(c.object_id) as table_name, 
'Computed Column' as data_type, 
NULL as 'precision', 
NULL as 'scale',
count(c.name) as  [countofcolumns]
from sys.computed_columns c
join sys.objects o on o.object_id = c.object_id
group by  object_name(c.object_id), c.name
order by tab.name, t.name, t.precision, t.scale;

