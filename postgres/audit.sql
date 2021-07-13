
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
    pg_index.*,
    indexrelid :: REGCLASS                         AS index,
    relid :: REGCLASS                              AS table,
    'DROP INDEX ' || indexrelid :: REGCLASS || ';' AS drop_statement
FROM pg_stat_user_indexes
    JOIN pg_index USING (indexrelid)
WHERE idx_scan = 0 AND indisunique IS FALSE;

SELECT pg_total_


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




-- Query analytics
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