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



-- Procedures
SELECT * FROM pg_proc;


-- Procedure view
select proname, prosrc, * from pg_proc where proname= 'fx_proc';
