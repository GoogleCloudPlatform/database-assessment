create or replace table mysql_db_objects as
select i.CONSTRAINT_CATALOG as object_catalog,
    i.CONSTRAINT_SCHEMA as object_schema,
    'CONSTRAINT' as object_category,
    concat(i.CONSTRAINT_TYPE, ' CONSTRAINT') as object_type,
    i.CONSTRAINT_NAME as object_name
from information_schema.TABLE_CONSTRAINTS i
WHERE i.CONSTRAINT_SCHEMA NOT IN (
        'mysql',
        'information_schema',
        'performance_schema',
        'sys'
    )
union
select i.TRIGGER_CATALOG as object_catalog,
    i.TRIGGER_SCHEMA as object_schema,
    'TRIGGER' as object_category,
    concat(
        i.ACTION_TIMING,
        ' ',
        i.EVENT_MANIPULATION,
        ' TRIGGER'
    ) as object_type,
    i.TRIGGER_NAME as object_name
from information_schema.TRIGGERS i
WHERE i.TRIGGER_SCHEMA NOT IN (
        'mysql',
        'information_schema',
        'performance_schema',
        'sys'
    )
union
select i.TABLE_CATALOG as object_catalog,
    i.TABLE_SCHEMA as object_schema,
    'TABLE' as object_category,
    i.TABLE_TYPE as object_type,
    i.TABLE_NAME as object_name
from information_schema.TABLES i
WHERE i.TABLE_SCHEMA NOT IN (
        'mysql',
        'information_schema',
        'performance_schema',
        'sys'
    )
union
select i.ROUTINE_CATALOG as object_catalog,
    i.ROUTINE_SCHEMA as object_schema,
    'PROCEDURE' as object_category,
    i.ROUTINE_TYPE as object_type,
    i.ROUTINE_NAME as object_name
FROM information_schema.ROUTINES i
WHERE i.ROUTINE_TYPE = 'PROCEDURE'
    AND i.ROUTINE_SCHEMA NOT IN (
        'mysql',
        'information_schema',
        'performance_schema',
        'sys'
    )
union
select i.ROUTINE_CATALOG as object_catalog,
    i.ROUTINE_SCHEMA as object_schema,
    'FUNCTION' as object_category,
    i.ROUTINE_TYPE as object_type,
    i.ROUTINE_NAME as object_name
FROM information_schema.ROUTINES i
WHERE i.ROUTINE_TYPE = 'FUNCTION'
    AND i.ROUTINE_SCHEMA NOT IN (
        'mysql',
        'information_schema',
        'performance_schema',
        'sys'
    )
union
select i.EVENT_CATALOG as object_catalog,
    i.EVENT_SCHEMA as object_schema,
    'EVENT' as object_category,
    i.EVENT_TYPE as object_type,
    i.EVENT_NAME as object_name
FROM information_schema.EVENTS i
WHERE i.EVENT_SCHEMA NOT IN (
        'mysql',
        'information_schema',
        'performance_schema',
        'sys'
    )
union
select i.TABLE_CATALOG as object_catalog,
    i.TABLE_SCHEMA as object_schema,
    'VIEW' as object_category,
    'VIEW' as object_type,
    i.TABLE_NAME as object_name
from information_schema.VIEWS i
WHERE i.TABLE_SCHEMA NOT IN (
        'mysql',
        'information_schema',
        'performance_schema',
        'sys'
    );
