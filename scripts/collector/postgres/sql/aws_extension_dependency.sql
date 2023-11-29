with alias1 as (
  select alias1.proname,
    ns.nspname,
    case
      when relkind = 'r' then 'TABLE'
    end as objType,
    depend.relname,
    pg_get_expr(pg_attrdef.adbin, pg_attrdef.adrelid) as def
  from pg_depend
    inner join (
      select distinct pg_proc.oid as procoid,
        nspname || '.' || proname as proname,
        pg_namespace.oid
      from pg_namespace,
        pg_proc
      where nspname = 'aws_oracle_ext'
        and pg_proc.pronamespace = pg_namespace.oid
    ) alias1 on pg_depend.refobjid = alias1.procoid
    inner join pg_attrdef on pg_attrdef.oid = pg_depend.objid
    inner join pg_class depend on depend.oid = pg_attrdef.adrelid
    inner join pg_namespace ns on ns.oid = depend.relnamespace
),
alias2 as (
  select alias1.nspname as SCHEMA,
    alias1.relname as TABLE_NAME,
    alias2.*
  from alias1
    cross join LATERAL (
      select i as funcname,
        cntgroup as cnt
      from (
          select (
              regexp_matches(
                alias1.def,
                'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                'ig'
              )
            ) [1] i,
            count(1) cntgroup
          group by (
              regexp_matches(
                alias1.def,
                'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                'ig'
              )
            ) [1]
        ) t
    ) as alias2
  where def ~* 'aws_oracle_ext.*'
)
select alias2.schema as schemaName,
  'N/A' as LANGUAGE,
  'TableDefaultConstraints' as type,
  alias2.table_name as typeName,
  alias2.funcname as AWSExtensionDependency,
  sum(cnt) as SCTFunctionReferenceCount
from alias2
group by alias2.schema,
  alias2.table_name,
  alias2.funcname
)
union
(
  with alias1 as (
    select pgc.conname as CONSTRAINT_NAME,
      ccu.table_schema as table_schema,
      ccu.table_name,
      ccu.column_name,
      pg_get_constraintdef(pgc.oid) as def
    from pg_constraint pgc
      join pg_namespace nsp on nsp.oid = pgc.connamespace
      join pg_class cls on pgc.conrelid = cls.oid
      left join information_schema.constraint_column_usage ccu on pgc.conname = ccu.constraint_name
      and nsp.nspname = ccu.constraint_schema
    where contype = 'c'
    order by pgc.conname
  ),
  alias2 as (
    select alias1.table_schema,
      alias1.constraint_name,
      alias1.table_name,
      alias1.column_name,
      alias2.*
    from alias1
      cross join LATERAL (
        select i as funcname,
          cntgroup as cnt
        from (
            select (
                regexp_matches(
                  alias1.def,
                  'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                  'ig'
                )
              ) [1] i,
              count(1) cntgroup
            group by (
                regexp_matches(
                  alias1.def,
                  'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                  'ig'
                )
              ) [1]
          ) t
      ) as alias2
    where def ~* 'aws_oracle_ext.*'
  )
  select alias2.table_schema as schemaName,
    'N/A' as LANGUAGE,
    'TableCheckConstraints' as type,
    alias2.table_name as typeName,
    alias2.funcname as AWSExtensionDependency,
    sum(cnt) as SCTFunctionReferenceCount
  from alias2
  group by alias2.table_schema,
    alias2.table_name,
    alias2.funcname
)
union
(
  with alias1 as (
    select alias1.proname,
      nspname,
      case
        when relkind = 'i' then 'INDEX'
      end as objType,
      depend.relname,
      pg_get_indexdef(depend.oid) def
    from pg_depend
      inner join (
        select distinct pg_proc.oid as procoid,
          nspname || '.' || proname as proname,
          pg_namespace.oid
        from pg_namespace,
          pg_proc
        where nspname = 'aws_oracle_ext'
          and pg_proc.pronamespace = pg_namespace.oid
      ) alias1 on pg_depend.refobjid = alias1.procoid
      inner join pg_class depend on depend.oid = pg_depend.objid
      inner join pg_namespace ns on ns.oid = depend.relnamespace
    where relkind = 'i'
  ),
  alias2 as (
    select alias1.nspname as SCHEMA,
      alias1.relname as IndexName,
      alias2.*
    from alias1
      cross join LATERAL (
        select i as funcname,
          cntgroup as cnt
        from (
            select (
                regexp_matches(
                  alias1.def,
                  'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                  'ig'
                )
              ) [1] i,
              count(1) cntgroup
            group by (
                regexp_matches(
                  alias1.def,
                  'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                  'ig'
                )
              ) [1]
          ) t
      ) as alias2
    where def ~* 'aws_oracle_ext.*'
  )
  select alias2.Schema as schemaName,
    'N/A' as LANGUAGE,
    'TableIndexesAsFunctions' as type,
    alias2.IndexName as typeName,
    alias2.funcname as AWSExtensionDependency,
    sum(cnt) as SCTFunctionReferenceCount
  from alias2
  group by alias2.Schema,
    alias2.IndexName,
    alias2.funcname
)
union
(
  with alias1 as (
    select alias1.proname,
      nspname,
      case
        when depend.relkind = 'v' then 'VIEW'
      end as objType,
      depend.relname,
      pg_get_viewdef(depend.oid) def
    from pg_depend
      inner join (
        select distinct pg_proc.oid as procoid,
          nspname || '.' || proname as proname,
          pg_namespace.oid
        from pg_namespace,
          pg_proc
        where nspname = 'aws_oracle_ext'
          and pg_proc.pronamespace = pg_namespace.oid
      ) alias1 on pg_depend.refobjid = alias1.procoid
      inner join pg_rewrite on pg_rewrite.oid = pg_depend.objid
      inner join pg_class depend on depend.oid = pg_rewrite.ev_class
      inner join pg_namespace ns on ns.oid = depend.relnamespace
    where not exists (
        select 1
        from pg_namespace
        where pg_namespace.oid = depend.relnamespace
          and nspname = 'aws_oracle_ext'
      )
  ),
  alias2 as (
    select alias1.nspname as SCHEMA,
      alias1.relname as ViewName,
      alias2.*
    from alias1
      cross join LATERAL (
        select i as funcname,
          cntgroup as cnt
        from (
            select (
                regexp_matches(
                  alias1.def,
                  'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                  'ig'
                )
              ) [1] i,
              count(1) cntgroup
            group by (
                regexp_matches(
                  alias1.def,
                  'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                  'ig'
                )
              ) [1]
          ) t
      ) as alias2
    where def ~* 'aws_oracle_ext.*'
  )
  select alias2.Schema as schemaName,
    'N/A' as LANGUAGE,
    'Views' as type,
    alias2.ViewName as typeName,
    alias2.funcname as AWSExtensionDependency,
    sum(cnt) as SCTFunctionReferenceCount
  from alias2
  group by alias2.Schema,
    alias2.ViewName,
    alias2.funcname
)
union
(
  with alias1 as (
    select distinct n.nspname as function_schema,
      p.proname as function_name,
      l.lanname as function_language,
      (
        select 'Y'
        from pg_trigger
        where tgfoid = (n.nspname || '.' || p.proname)::regproc
      ) as Trigger_Func,
      lower(pg_get_functiondef(p.oid)::text) as def
    from pg_proc p
      left join pg_namespace n on p.pronamespace = n.oid
      left join pg_language l on p.prolang = l.oid
      left join pg_type t on t.oid = p.prorettype
    where n.nspname not in (
        'pg_catalog',
        'information_schema',
        'aws_oracle_ext'
      )
      and p.prokind not in ('a', 'w')
      and l.lanname in ('sql', 'plpgsql')
    order by function_schema,
      function_name
  ),
  alias2 as (
    select alias1.function_schema,
      alias1.function_name,
      alias1.function_language,
      alias1.Trigger_Func,
      alias2.*
    from alias1
      cross join LATERAL (
        select i as funcname,
          cntgroup as cnt
        from (
            select (
                regexp_matches(
                  alias1.def,
                  'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                  'ig'
                )
              ) [1] i,
              count(1) cntgroup
            group by (
                regexp_matches(
                  alias1.def,
                  'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                  'ig'
                )
              ) [1]
          ) t
      ) as alias2
    where def ~* 'aws_oracle_ext.*'
      and Trigger_Func = 'Y'
  )
  select function_schema as schemaName,
    function_language as LANGUAGE,
    'Triggers' as type,
    function_name as typeName,
    funcname as AWSExtensionDependency,
    sum(cnt) as SCTFunctionReferenceCount
  from alias2
  where 1 = 1
  group by function_schema,
    function_language,
    function_name,
    funcname
  order by 3,
    4 desc
)
union
(
  with alias1 as (
    select distinct n.nspname as function_schema,
      p.proname as function_name,
      l.lanname as function_language,
      (
        select 'Y'
        from pg_trigger
        where tgfoid = (n.nspname || '.' || p.proname)::regproc
      ) as Trigger_Func,
      lower(pg_get_functiondef(p.oid)::text) as def
    from pg_proc p
      left join pg_namespace n on p.pronamespace = n.oid
      left join pg_language l on p.prolang = l.oid
      left join pg_type t on t.oid = p.prorettype
    where n.nspname not in (
        'pg_catalog',
        'information_schema',
        'aws_oracle_ext'
      )
      and p.prokind not in ('a', 'w', 'p')
      and l.lanname in ('sql', 'plpgsql')
    order by function_schema,
      function_name
  ),
  alias2 as (
    select alias1.function_schema,
      alias1.function_name,
      alias1.function_language,
      alias1.Trigger_Func,
      alias2.*
    from alias1
      cross join LATERAL (
        select i as funcname,
          cntgroup as cnt
        from (
            select (
                regexp_matches(
                  alias1.def,
                  'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                  'ig'
                )
              ) [1] i,
              count(1) cntgroup
            group by (
                regexp_matches(
                  alias1.def,
                  'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                  'ig'
                )
              ) [1]
          ) t
      ) as alias2
    where def ~* 'aws_oracle_ext.*'
      and alias1.Trigger_Func is null
  )
  select function_schema as schemaName,
    function_language as LANGUAGE,
    'Functions' as type,
    function_name as typeName,
    funcname as AWSExtensionDependency,
    sum(cnt) as SCTFunctionReferenceCount
  from alias2
  where 1 = 1
  group by function_schema,
    function_language,
    function_name,
    funcname
  order by 3,
    4 desc
)
union
(
  with alias1 as (
    select distinct n.nspname as function_schema,
      p.proname as function_name,
      l.lanname as function_language,
      (
        select 'Y'
        from pg_trigger
        where tgfoid = (n.nspname || '.' || p.proname)::regproc
      ) as Trigger_Func,
      lower(pg_get_functiondef(p.oid)::text) as def
    from pg_proc p
      left join pg_namespace n on p.pronamespace = n.oid
      left join pg_language l on p.prolang = l.oid
      left join pg_type t on t.oid = p.prorettype
    where n.nspname not in (
        'pg_catalog',
        'information_schema',
        'aws_oracle_ext'
      )
      and p.prokind not in ('a', 'w', 'f')
      and l.lanname in ('sql', 'plpgsql')
    order by function_schema,
      function_name
  ),
  alias2 as (
    select alias1.function_schema,
      alias1.function_name,
      alias1.function_language,
      alias1.Trigger_Func,
      alias2.*
    from alias1
      cross join LATERAL (
        select i as funcname,
          cntgroup as cnt
        from (
            select (
                regexp_matches(
                  alias1.def,
                  'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                  'ig'
                )
              ) [1] i,
              count(1) cntgroup
            group by (
                regexp_matches(
                  alias1.def,
                  'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                  'ig'
                )
              ) [1]
          ) t
      ) as alias2
    where def ~* 'aws_oracle_ext.*'
  )
  select chr(34) || :PKEY || chr(34) as pkey,
    chr(34) || :DMA_SOURCE_ID || chr(34) as dma_source_id,
    chr(34) || :DMA_MANUAL_ID || chr(34) as dma_manual_id,
    chr(34) || function_schema || chr(34) as object_schema_name,
    chr(34) || function_language || chr(34) as object_language,
    chr(34) || 'Procedures' || chr(34) as object_type,
    chr(34) || function_name || chr(34) as object_name,
    chr(34) || funcname || chr(34) as aws_extension_dependency,
    chr(34) || sum(cnt) || chr(34) as sct_function_reference_count
  from alias2
  where 1 = 1
  group by function_schema,
    function_language,
    function_name,
    funcname
  order by 3,
    4 desc
