\ o output / opdb__awsextensiondependency_ :VTAG.csv (
  WITH alias1 AS (
    SELECT alias1.proname,
      ns.nspname,
      CASE
        WHEN relkind = 'r' THEN 'TABLE'
      END AS objType,
      depend.relname,
      pg_get_expr(pg_attrdef.adbin, pg_attrdef.adrelid) AS def
    FROM pg_depend
      INNER JOIN (
        SELECT DISTINCT pg_proc.oid AS procoid,
          nspname || '.' || proname AS proname,
          pg_namespace.oid
        FROM pg_namespace,
          pg_proc
        WHERE nspname = 'aws_oracle_ext'
          AND pg_proc.pronamespace = pg_namespace.oid
      ) alias1 ON pg_depend.refobjid = alias1.procoid
      INNER JOIN pg_attrdef ON pg_attrdef.oid = pg_depend.objid
      INNER JOIN pg_class depend ON depend.oid = pg_attrdef.adrelid
      INNER JOIN pg_namespace ns ON ns.oid = depend.relnamespace
  ),
  alias2 AS (
    SELECT alias1.nspname AS SCHEMA,
      alias1.relname AS TABLE_NAME,
      alias2.*
    FROM alias1
      CROSS JOIN LATERAL (
        SELECT i AS funcname,
          cntgroup AS cnt
        FROM (
            SELECT (
                regexp_matches(
                  alias1.def,
                  'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                  'ig'
                )
              ) [1] i,
              count(1) cntgroup
            GROUP BY (
                regexp_matches(
                  alias1.def,
                  'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                  'ig'
                )
              ) [1]
          ) t
      ) AS alias2
    WHERE def ~* 'aws_oracle_ext.*'
  )
  SELECT alias2.schema AS schemaName,
    'N/A' AS LANGUAGE,
    'TableDefaultConstraints' AS TYPE,
    alias2.table_name AS typeName,
    alias2.funcname AS AWSExtensionDependency,
    sum(cnt) AS SCTFunctionReferenceCount
  FROM alias2
  GROUP BY alias2.schema,
    alias2.table_name,
    alias2.funcname
)
UNION
(
  WITH alias1 AS (
    SELECT pgc.conname AS CONSTRAINT_NAME,
      ccu.table_schema AS table_schema,
      ccu.table_name,
      ccu.column_name,
      pg_get_constraintdef(pgc.oid) AS def
    FROM pg_constraint pgc
      JOIN pg_namespace nsp ON nsp.oid = pgc.connamespace
      JOIN pg_class cls ON pgc.conrelid = cls.oid
      LEFT JOIN information_schema.constraint_column_usage ccu ON pgc.conname = ccu.constraint_name
      AND nsp.nspname = ccu.constraint_schema
    WHERE contype = 'c'
    ORDER BY pgc.conname
  ),
  alias2 AS (
    SELECT alias1.table_schema,
      alias1.constraint_name,
      alias1.table_name,
      alias1.column_name,
      alias2.*
    FROM alias1
      CROSS JOIN LATERAL (
        SELECT i AS funcname,
          cntgroup AS cnt
        FROM (
            SELECT (
                regexp_matches(
                  alias1.def,
                  'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                  'ig'
                )
              ) [1] i,
              count(1) cntgroup
            GROUP BY (
                regexp_matches(
                  alias1.def,
                  'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                  'ig'
                )
              ) [1]
          ) t
      ) AS alias2
    WHERE def ~* 'aws_oracle_ext.*'
  )
  SELECT alias2.table_schema AS schemaName,
    'N/A' AS LANGUAGE,
    'TableCheckConstraints' AS TYPE,
    alias2.table_name AS typeName,
    alias2.funcname AS AWSExtensionDependency,
    sum(cnt) AS SCTFunctionReferenceCount
  FROM alias2
  GROUP BY alias2.table_schema,
    alias2.table_name,
    alias2.funcname
)
UNION
(
  WITH alias1 AS (
    SELECT alias1.proname,
      nspname,
      CASE
        WHEN relkind = 'i' THEN 'INDEX'
      END AS objType,
      depend.relname,
      pg_get_indexdef(depend.oid) def
    FROM pg_depend
      INNER JOIN (
        SELECT DISTINCT pg_proc.oid AS procoid,
          nspname || '.' || proname AS proname,
          pg_namespace.oid
        FROM pg_namespace,
          pg_proc
        WHERE nspname = 'aws_oracle_ext'
          AND pg_proc.pronamespace = pg_namespace.oid
      ) alias1 ON pg_depend.refobjid = alias1.procoid
      INNER JOIN pg_class depend ON depend.oid = pg_depend.objid
      INNER JOIN pg_namespace ns ON ns.oid = depend.relnamespace
    WHERE relkind = 'i'
  ),
  alias2 AS (
    SELECT alias1.nspname AS SCHEMA,
      alias1.relname AS IndexName,
      alias2.*
    FROM alias1
      CROSS JOIN LATERAL (
        SELECT i AS funcname,
          cntgroup AS cnt
        FROM (
            SELECT (
                regexp_matches(
                  alias1.def,
                  'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                  'ig'
                )
              ) [1] i,
              count(1) cntgroup
            GROUP BY (
                regexp_matches(
                  alias1.def,
                  'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                  'ig'
                )
              ) [1]
          ) t
      ) AS alias2
    WHERE def ~* 'aws_oracle_ext.*'
  )
  SELECT alias2.Schema AS schemaName,
    'N/A' AS LANGUAGE,
    'TableIndexesAsFunctions' AS TYPE,
    alias2.IndexName AS typeName,
    alias2.funcname AS AWSExtensionDependency,
    sum(cnt) AS SCTFunctionReferenceCount
  FROM alias2
  GROUP BY alias2.Schema,
    alias2.IndexName,
    alias2.funcname
)
UNION
(
  WITH alias1 AS (
    SELECT alias1.proname,
      nspname,
      CASE
        WHEN depend.relkind = 'v' THEN 'VIEW'
      END AS objType,
      depend.relname,
      pg_get_viewdef(depend.oid) def
    FROM pg_depend
      INNER JOIN (
        SELECT DISTINCT pg_proc.oid AS procoid,
          nspname || '.' || proname AS proname,
          pg_namespace.oid
        FROM pg_namespace,
          pg_proc
        WHERE nspname = 'aws_oracle_ext'
          AND pg_proc.pronamespace = pg_namespace.oid
      ) alias1 ON pg_depend.refobjid = alias1.procoid
      INNER JOIN pg_rewrite ON pg_rewrite.oid = pg_depend.objid
      INNER JOIN pg_class depend ON depend.oid = pg_rewrite.ev_class
      INNER JOIN pg_namespace ns ON ns.oid = depend.relnamespace
    WHERE NOT exists (
        SELECT 1
        FROM pg_namespace
        WHERE pg_namespace.oid = depend.relnamespace
          AND nspname = 'aws_oracle_ext'
      )
  ),
  alias2 AS (
    SELECT alias1.nspname AS SCHEMA,
      alias1.relname AS ViewName,
      alias2.*
    FROM alias1
      CROSS JOIN LATERAL (
        SELECT i AS funcname,
          cntgroup AS cnt
        FROM (
            SELECT (
                regexp_matches(
                  alias1.def,
                  'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                  'ig'
                )
              ) [1] i,
              count(1) cntgroup
            GROUP BY (
                regexp_matches(
                  alias1.def,
                  'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                  'ig'
                )
              ) [1]
          ) t
      ) AS alias2
    WHERE def ~* 'aws_oracle_ext.*'
  )
  SELECT alias2.Schema AS schemaName,
    'N/A' AS LANGUAGE,
    'Views' AS TYPE,
    alias2.ViewName AS typeName,
    alias2.funcname AS AWSExtensionDependency,
    sum(cnt) AS SCTFunctionReferenceCount
  FROM alias2
  GROUP BY alias2.Schema,
    alias2.ViewName,
    alias2.funcname
)
UNION
(
  WITH alias1 AS (
    SELECT DISTINCT n.nspname AS function_schema,
      p.proname AS function_name,
      l.lanname AS function_language,
      (
        SELECT 'Y'
        FROM pg_trigger
        WHERE tgfoid = (n.nspname || '.' || p.proname)::regproc
      ) AS Trigger_Func,
      lower(pg_get_functiondef(p.oid)::text) AS def
    FROM pg_proc p
      LEFT JOIN pg_namespace n ON p.pronamespace = n.oid
      LEFT JOIN pg_language l ON p.prolang = l.oid
      LEFT JOIN pg_type t ON t.oid = p.prorettype
    WHERE n.nspname not in (
        'pg_catalog',
        'information_schema',
        'aws_oracle_ext'
      )
      AND p.prokind not in ('a', 'w')
      AND l.lanname in ('sql', 'plpgsql')
    ORDER BY function_schema,
      function_name
  ),
  alias2 AS (
    SELECT alias1.function_schema,
      alias1.function_name,
      alias1.function_language,
      alias1.Trigger_Func,
      alias2.*
    FROM alias1
      CROSS JOIN LATERAL (
        SELECT i AS funcname,
          cntgroup AS cnt
        FROM (
            SELECT (
                regexp_matches(
                  alias1.def,
                  'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                  'ig'
                )
              ) [1] i,
              count(1) cntgroup
            GROUP BY (
                regexp_matches(
                  alias1.def,
                  'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                  'ig'
                )
              ) [1]
          ) t
      ) AS alias2
    WHERE def ~* 'aws_oracle_ext.*'
      AND Trigger_Func = 'Y'
  )
  SELECT function_schema AS schemaName,
    function_language AS LANGUAGE,
    'Triggers' AS TYPE,
    function_name AS typeName,
    funcname AS AWSExtensionDependency,
    sum(cnt) AS SCTFunctionReferenceCount
  FROM alias2
  WHERE 1 = 1
  GROUP BY function_schema,
    function_language,
    function_name,
    funcname
  ORDER BY 3,
    4 DESC
)
UNION
(
  WITH alias1 AS (
    SELECT DISTINCT n.nspname AS function_schema,
      p.proname AS function_name,
      l.lanname AS function_language,
      (
        SELECT 'Y'
        FROM pg_trigger
        WHERE tgfoid = (n.nspname || '.' || p.proname)::regproc
      ) AS Trigger_Func,
      lower(pg_get_functiondef(p.oid)::text) AS def
    FROM pg_proc p
      LEFT JOIN pg_namespace n ON p.pronamespace = n.oid
      LEFT JOIN pg_language l ON p.prolang = l.oid
      LEFT JOIN pg_type t ON t.oid = p.prorettype
    WHERE n.nspname not in (
        'pg_catalog',
        'information_schema',
        'aws_oracle_ext'
      )
      AND p.prokind not in ('a', 'w', 'p')
      AND l.lanname in ('sql', 'plpgsql')
    ORDER BY function_schema,
      function_name
  ),
  alias2 AS (
    SELECT alias1.function_schema,
      alias1.function_name,
      alias1.function_language,
      alias1.Trigger_Func,
      alias2.*
    FROM alias1
      CROSS JOIN LATERAL (
        SELECT i AS funcname,
          cntgroup AS cnt
        FROM (
            SELECT (
                regexp_matches(
                  alias1.def,
                  'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                  'ig'
                )
              ) [1] i,
              count(1) cntgroup
            GROUP BY (
                regexp_matches(
                  alias1.def,
                  'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                  'ig'
                )
              ) [1]
          ) t
      ) AS alias2
    WHERE def ~* 'aws_oracle_ext.*'
      AND alias1.Trigger_Func IS NULL
  )
  SELECT function_schema AS schemaName,
    function_language AS LANGUAGE,
    'Functions' AS TYPE,
    function_name AS typeName,
    funcname AS AWSExtensionDependency,
    sum(cnt) AS SCTFunctionReferenceCount
  FROM alias2
  WHERE 1 = 1
  GROUP BY function_schema,
    function_language,
    function_name,
    funcname
  ORDER BY 3,
    4 DESC
)
UNION
(
  WITH alias1 AS (
    SELECT DISTINCT n.nspname AS function_schema,
      p.proname AS function_name,
      l.lanname AS function_language,
      (
        SELECT 'Y'
        FROM pg_trigger
        WHERE tgfoid = (n.nspname || '.' || p.proname)::regproc
      ) AS Trigger_Func,
      lower(pg_get_functiondef(p.oid)::text) AS def
    FROM pg_proc p
      LEFT JOIN pg_namespace n ON p.pronamespace = n.oid
      LEFT JOIN pg_language l ON p.prolang = l.oid
      LEFT JOIN pg_type t ON t.oid = p.prorettype
    WHERE n.nspname not in (
        'pg_catalog',
        'information_schema',
        'aws_oracle_ext'
      )
      AND p.prokind not in ('a', 'w', 'f')
      AND l.lanname in ('sql', 'plpgsql')
    ORDER BY function_schema,
      function_name
  ),
  alias2 AS (
    SELECT alias1.function_schema,
      alias1.function_name,
      alias1.function_language,
      alias1.Trigger_Func,
      alias2.*
    FROM alias1
      CROSS JOIN LATERAL (
        SELECT i AS funcname,
          cntgroup AS cnt
        FROM (
            SELECT (
                regexp_matches(
                  alias1.def,
                  'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                  'ig'
                )
              ) [1] i,
              count(1) cntgroup
            GROUP BY (
                regexp_matches(
                  alias1.def,
                  'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                  'ig'
                )
              ) [1]
          ) t
      ) AS alias2
    WHERE def ~* 'aws_oracle_ext.*'
  )
  SELECT chr(39) || :PKEY || chr(39),
    chr(39) || :DMA_SOURCE_ID || chr(39) AS DMA_SOURCE_ID,
    chr(39) || :DMA_MANUAL_ID || chr(39) AS DMA_MANUAL_ID,
    function_schema AS schemaName,
    function_language AS LANGUAGE,
    'Procedures' AS TYPE,
    function_name AS typeName,
    funcname AS AWSExtensionDependency,
    sum(cnt) AS SCTFunctionReferenceCount
  FROM alias2
  WHERE 1 = 1
  GROUP BY function_schema,
    function_language,
    function_name,
    funcname
  ORDER BY 3,
    4 DESC
)
