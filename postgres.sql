
-- Triggers: disable/enable triggers for current session

-- Triggers disable
SET session_replication_role = replica;

-- Triggers enable
SET session_replication_role = DEFAULT;

-- Show triggers on or off
SHOW session_replication_role;

-- Size

-- Show size of each column in a table
select
    sum(pg_column_size(COLUMN NAME)) as total_size,
    avg(pg_column_size(COLUMN NAME)) as average_size,
    sum(pg_column_size(COLUMN NAME)) * 100.0 / pg_relation_size('TABLE NAME') as percentage
from TABLE NAME;
                       
                       
                       
                       

------------------------------------------------------------------------------------------------------------------------

-- Activity
SELECT
    pid, client_addr, state, waiting,
    --clock_timestamp() - xact_start AS xact_age,
    clock_timestamp() - query_start AS query_age,
    query,
    *
FROM pg_stat_activity
--WHERE state != 'idle'
WHERE usename = 'dms'
ORDER BY query_start;

-- Server uptime
SELECT pg_postmaster_start_time();

-- Version
SELECT version();

-- Show
SHOW work_mem;
SHOW wal_writer_delay;
SHOW autovacuum_vacuum_cost_limit;
SHOW autovacuum_vacuum_threshold;
SHOW autovacuum_freeze_max_age;
SHOW autovacuum_max_workers; -- = 6
SHOW auto_vacuum_cost_limit; -- = 1500
SHOW maintenance_work_mem; -- = RDS default

-- All activity stats
SELECT * FROM pg_stat_activity;


-- Uptime
select current_timestamp - pg_postmaster_start_time() as uptime;

-- Is master
select pg_is_in_recovery();

-- Kill by filter
SELECT pg_terminate_backend(pid)
    FROM pg_stat_activity
    WHERE datname = 'your db name'
      AND pid <> pg_backend_pid()
      AND state = 'idle'
      AND state_change < current_timestamp - INTERVAL '5' MINUTE;


-- Role set
SET ROLE stelshevsky;

-- Procedure view
select proname, prosrc, * from pg_proc where proname= 'fx_proc';

-- Procedures
SELECT * FROM pg_proc;

-- Current running processes
SELECT
    pid, client_addr, state, waiting,
    clock_timestamp() - xact_start AS xact_age,
    clock_timestamp() -
     query_start AS query_age,
    query,
    *
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY query_start;

-- Kills
SELECT pg_cancel_backend(29456);
SELECT pg_terminate_backend(pid), pid FROM pg_stat_activity WHERE pid IN (1);
SELECT pg_terminate_backend(73531);






-- Age = transactions since wraparound
SELECT c.oid::regclass as table_name,
       greatest(age(c.relfrozenxid),age(t.relfrozenxid)) as age
FROM pg_class c
         LEFT JOIN pg_class t ON c.reltoastrelid = t.oid
WHERE c.relkind IN ('r', 'm')
ORDER BY age DESC;

-- Database age
SELECT datname, age(datfrozenxid), 2137483648 - age(datfrozenxid) as world_ends_in FROM pg_database ORDER BY 2 DESC LIMIT 20;

-- Table age
SELECT c.oid::regclass as table_name,
       greatest(age(c.relfrozenxid),age(t.relfrozenxid)) as age,
       pg_size_pretty(pg_table_size(c.oid)) as table_size
FROM pg_class c
         LEFT JOIN pg_class t ON c.reltoastrelid = t.oid
WHERE c.relkind = 'r'
ORDER BY 2 DESC LIMIT 20;


-- Wraparound
WITH max_age AS (
    SELECT 2000000000 as max_old_xid
         , setting AS autovacuum_freeze_max_age
    FROM pg_catalog.pg_settings
    WHERE name = 'autovacuum_freeze_max_age' )
   , per_database_stats AS (
    SELECT datname
         , m.max_old_xid::int
         , m.autovacuum_freeze_max_age::int
         , age(d.datfrozenxid) AS oldest_current_xid
    FROM pg_catalog.pg_database d
             JOIN max_age m ON (true)
    WHERE d.datallowconn )
SELECT max(oldest_current_xid) AS oldest_current_xid
     , max(ROUND(100*(oldest_current_xid/max_old_xid::float))) AS percent_towards_wraparound
     , max(ROUND(100*(oldest_current_xid/autovacuum_freeze_max_age::float))) AS percent_towards_emergency_autovac
FROM per_database_stats;

-- Locks 2
SELECT
    a.datname,
    c.relname,
    c.reltype,
    l.transactionid,
    l.mode,
    l.GRANTED,
    a.usename,
    a.query,
    a.query_start,
    age(now(), a.query_start) AS "age",
    a.pid

FROM pg_stat_activity a
JOIN pg_locks l ON l.pid = a.pid
JOIN pg_class c ON c.oid = l.relation
WHERE
    mode != 'AccessShareLock'
    AND
    reltype != 0
ORDER BY a.query_start;

-- Locks
SELECT
    blocked_locks.pid         AS blocked_pid,
    blocked_activity.usename  AS blocked_user,
    blocking_locks.pid        AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query    AS blocked_statement,
    blocking_activity.query   AS current_statement_in_blocking_process
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity  ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks         blocking_locks ON
            blocking_locks.locktype = blocked_locks.locktype
        AND blocking_locks.DATABASE IS NOT DISTINCT FROM blocked_locks.DATABASE
        AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
        AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
        AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
        AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
        AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
        AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
        AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
        AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
        AND blocking_locks.pid != blocked_locks.pid

JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.GRANTED;


-- Missing indexes
SELECT
    relname,
    schemaname,
    seq_scan - idx_scan                   AS too_much_seq,
    CASE WHEN seq_scan - idx_scan > 0
        THEN 'Missing Index?'
    ELSE 'OK' END,
    pg_relation_size(relname :: REGCLASS) AS rel_size,
    seq_scan,
    idx_scan,
    seq_scan / CASE idx_scan WHEN 0 THEN 0.0001 ELSE 1 END * pg_relation_size(relname :: REGCLASS) AS coeff,
    CASE idx_scan WHEN 0 THEN 1 WHEN null THEN 1 ELSE idx_scan END / CASE seq_scan WHEN 0 THEN 1 WHEN null THEN 1 ELSE seq_scan END
    --COALESCE(seq_scan, 1) / COALESCE(idx_scan, 1) AS coef

FROM pg_stat_all_tables
WHERE
    schemaname = 'public'
    AND
    pg_relation_size(relname :: REGCLASS) > 80000
    AND
    seq_scan > 50
--ORDER BY too_much_seq DESC
ORDER BY coeff DESC;


-- Unused indexes 1
SELECT
    indexrelid :: REGCLASS                         AS index,
    relid :: REGCLASS                              AS table,
    'DROP INDEX ' || indexrelid :: REGCLASS || ';' AS drop_statement
FROM pg_stat_user_indexes
JOIN pg_index USING (indexrelid)
WHERE idx_scan = 0 AND indisunique IS FALSE;


-- Unused indexes 2
SELECT *
FROM
    pg_stat_all_indexes
WHERE
    -- Not used at all
    idx_scan = 0
    -- Schema public (do not list system pg_ stuff, may require extending)
    AND
    schemaname = 'public'
    -- no primary keys
    AND
    indexrelname NOT LIKE '%_pkey';



SELECT * FROM pg_stat_all_tables;
SELECT * FROM pg_stat_database;


-- List databases
SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname DESC;

-- Relations
select
    t.relname as table_name,
    i.relname as index_name,
    a.attname as column_name
from
    pg_class t,
    pg_class i,
    pg_index ix,
    pg_attribute a
where
    t.oid = ix.indrelid
    and i.oid = ix.indexrelid
    and a.attrelid = t.oid
    and a.attnum = ANY(ix.indkey)
    and t.relkind = 'r'
    --and t.relname = 'crm_communication'
order by
    t.relname,
    i.relname;




with s AS
(SELECT sum(total_time) AS t,sum(calls) AS s,sum(rows) as r FROM pg_stat_statements WHERE dbid=(SELECT oid from pg_database where datname=current_database()))
SELECT
(100*total_time/(SELECT t FROM s))::numeric(20,2) AS time_percent,
total_time::numeric(20,2) as total_time,
(total_time*1000/calls)::numeric(10,3) AS avg_time,
calls,
(100*calls/(SELECT s FROM s))::numeric(20,2) AS calls_percent,
rows,
(100*rows/(SELECT r from s))::numeric(20,2) AS row_percent,
query
FROM pg_stat_statements
WHERE
calls/(SELECT s FROM s)>=0.01
AND dbid=(SELECT oid from pg_database where datname=current_database())
UNION all
SELECT
(100*sum(total_time)/(SELECT t FROM s))::numeric(20,2) AS time_percent,
sum(total_time)::numeric(20,2),
(sum(total_time)*1000/sum(calls))::numeric(10,3) AS avg_time,
sum(calls),
(100*sum(calls)/(SELECT s FROM s))::numeric(20,2) AS calls_percent,
sum(rows),
(100*sum(rows)/(SELECT r from s))::numeric(20,2) AS row_percent,
'other' AS query
FROM pg_stat_statements
WHERE
calls/(SELECT s FROM s)<0.01
AND dbid=(SELECT oid from pg_database where datname=current_database())

ORDER BY 4 DESC;


-- Table sizes
SELECT nspname || '.' || relname AS "relation",
    pg_size_pretty(pg_relation_size(C.oid)) AS "size"
  FROM pg_class C
  LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace)
  WHERE nspname NOT IN ('pg_catalog', 'information_schema')
        --AND relname ILIKE '%reject%'
        AND relname ILIKE 'mini%'
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



-- With toast data
SELECT
    relname as "Table",
    pg_size_pretty(pg_total_relation_size(relid)) As "Size",
    pg_size_pretty(pg_total_relation_size(relid) - pg_relation_size(relid)) as "External Size"
FROM pg_catalog.pg_statio_user_tables ORDER BY pg_total_relation_size(relid) DESC limit 10;

-- With toast data
SELECT
    relname as "Table",
    pg_size_pretty(pg_total_relation_size(relid)) As "Size",
    pg_size_pretty(pg_total_relation_size(relid) - pg_relation_size(relid)) as "External Size"
FROM pg_catalog.pg_statio_user_tables
WHERE relname = 'mytable'
ORDER BY pg_total_relation_size(relid) DESC limit 10;


-- To check how much bytes were read, compare to table size with toast and indexes (for autovacuum progress)
-- $ while true; do cat /proc/123/io | grep read_bytes; sleep 60; done





-- Registering functions:
create or replace function fx_processes()
    returns table (pid INTEGER, ip INET, username NAME, app_name TEXT, state TEXT, waiting BOOL, xact_age TEXT, query_age TEXT, query TEXT)
as
$body$
SELECT
    pid::INTEGER,
    client_addr AS ip,
    usename AS username,
    application_name AS app_name,
    state,
    waiting,
    to_char(clock_timestamp() - xact_start, 'DD HH24:MI:SS.US') AS xact_age,
    to_char(clock_timestamp() - query_start, 'DD HH24:MI:SS.US') AS query_age,
    query
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY query_start;
$body$
    language sql;
