drop schema if EXISTS public     cascade;
drop schema if EXISTS app        cascade;
drop schema if EXISTS domesa     cascade;

create schema app;
create schema domesa;
set search_path to app;
\! reset

/*
DO $$
DECLARE _sql TEXT;
BEGIN
	select format('ALTER DATABASE %s SET SEARCH_PATH TO app, domesa', current_database() ) into  _sql;
	select format('alter database %s set timezone to ''UTC'' ', current_database()) into _sql;
	execute _sql;
END$$;
*/

-- init
-- \! reset
\i 00-initdb/00-init.sql
\i 00-initdb/01-functions.sql
\i 00-initdb/02-moment.sql

-- mod domesa
\i 01-domesa/00-schema.sql
\i 01-domesa/01-views.sql
\i 01-domesa/02-functions.sql
\i 01-domesa/03-fn-sync-guia.sql
