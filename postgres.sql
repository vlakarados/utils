
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
