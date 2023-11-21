with global_status as (
    select upper(variable_name) as variable_name,
        variable_value
    from performance_schema.global_status
),
all_vars as (
    select upper(variable_name) as variable_name,
        variable_value
    from performance_schema.global_variables
    union
    select upper(variable_name),
        variable_value
    from performance_schema.session_variables
    where variable_name not in (
            select variable_name
            from performance_schema.global_variables
        )
),
calculated_metrics as (
    select 'IS_MARIADB' as variable_name,
        if(upper(gv.variable_value) like '%MARIADB%', 1, 0) as variable_value
    from performance_schema.global_variables gv
    where gv.variable_name = 'VERSION'
),
src as (
    select 'ALL_VARIABLES' as variable_category,
        variable_name,
        variable_value
    from all_vars
    union
    select 'GLOBAL_STATUS' as variable_category,
        variable_name,
        variable_value
    from global_status
    union
    select 'CALCULATED_METRIC' as variable_category,
        variable_name,
        variable_value
    from calculated_metrics
)
select distinct concat(char(39), @DMA_MANUAL_ID, char(39)) as PKEY,
    concat(char(39), @DMA_SOURCE_ID, char(39)) as DMA_SOURCE_ID,
    concat(char(39), @DMA_MANUAL_ID, char(39)) as DMA_MANUAL_ID,
    src.variable_category,
    src.variable_name,
    src.variable_value
from src;
