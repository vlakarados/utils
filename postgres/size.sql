SELECT
    relname,
    schemaname,
    pg_size_pretty(pg_total_relation_size(relid)) AS size_full,
    pg_size_pretty(pg_table_size(relid)) AS size_table,
    pg_size_pretty(pg_relation_size(relid)) AS size_relation,
    pg_size_pretty(pg_indexes_size(relid)) AS size_indexes,
    pg_size_pretty(pg_total_relation_size(relid) - pg_relation_size(relid)) AS size_external
FROM pg_catalog.pg_statio_user_tables
--WHERE
-- relname = 'mytable'
-- schemaname = 'public'
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 20;



-- Databaze size
SELECT pg_size_pretty(pg_database_size('mydbname'));

-- Size columns in a table
select
    sum(pg_column_size(column)) as total_size,
    avg(pg_column_size(column)) as average_size,
    sum(pg_column_size(column)) * 100.0 / pg_relation_size('mytable') as percentage
from mytable;






----------------
-- Variations


-- Table sizes
SELECT nspname || '.' || relname AS "relation",
       pg_size_pretty(pg_relation_size(C.oid)) AS "size"
FROM pg_class C
    LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace)
WHERE nspname NOT IN ('pg_catalog', 'information_schema')
      --AND relname ILIKE '%reject%'
    --AND relname ILIKE 'my%'
ORDER BY pg_relation_size(C.oid) DESC
--LIMIT 20
;

-- Size with indexes
SELECT
    table_name,
    pg_size_pretty(table_size) AS table_size,
    pg_size_pretty(indexes_size) AS indexes_size,
    pg_size_pretty(total_size) AS total_size
FROM (
    SELECT
        table_name,
        pg_table_size(table_name) AS table_size,
        pg_indexes_size(table_name) AS indexes_size,
        pg_total_relation_size(table_name) AS total_size
    FROM (
        SELECT ('"' || table_schema || '"."' || table_name || '"') AS table_name
        FROM information_schema.tables
    ) AS all_tables
    ORDER BY total_size DESC
) AS pretty_sizes limit 50;