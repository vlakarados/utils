
-- Version
SELECT version();

-- Role set
SET ROLE myrolename;


-- Server uptime
SELECT pg_postmaster_start_time();

-- Uptime
select current_timestamp - pg_postmaster_start_time() as uptime;

-- Is master
select pg_is_in_recovery();

-- Triggers disable
SET session_replication_role = replica;

-- Triggers enable
SET session_replication_role = DEFAULT;

-- Show
SHOW work_mem;
SHOW wal_writer_delay;
SHOW autovacuum_vacuum_cost_limit;
SHOW autovacuum_vacuum_threshold;
SHOW autovacuum_freeze_max_age;
SHOW autovacuum_max_workers; -- = 6
SHOW auto_vacuum_cost_limit; -- = 1500
SHOW maintenance_work_mem; -- = RDS default
SHOW session_replication_role; -- Show triggers on or off


SELECT * FROM pg_stat_all_tables;
SELECT * FROM pg_stat_database;

-- List databases
SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname DESC;



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