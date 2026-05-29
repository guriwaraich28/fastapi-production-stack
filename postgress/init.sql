-- postgres/init.sql
-- Runs automatically on first postgres container start

-- Enable useful extensions
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Restrict public schema access
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT  CREATE ON SCHEMA public TO appuser;