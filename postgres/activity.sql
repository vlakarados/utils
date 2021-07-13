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


-- All activity stats
SELECT * FROM pg_stat_activity;


-- Kill by filter
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'your db name'
  AND pid <> pg_backend_pid()
  AND state = 'idle'
  AND state_change < current_timestamp - INTERVAL '5' MINUTE;



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








