create extension if not exists pgcrypto    SCHEMA "app";
create extension if not exists unaccent    SCHEMA "app";
create extension if not exists hstore      SCHEMA "app";
create extension if not exists "uuid-ossp" SCHEMA "app";

create type "app".type_http_response as (
	status   boolean,
	code     int,
	message  text,
	data     jsonb
);

create type "app".type_moment as (
	timezone       varchar(100)
	,timestamp      timestamp without time zone
	,date           date
	,time           time without time zone
	--
	,timestamp_format varchar(100)
	,date_format      varchar(100)
	,time_format      varchar(100)
	--
	,day            smallint
	,month          smallint
	,year           smallint
	,hour           smallint
	,minute         smallint
	,second         smallint
	,unixtime       bigint
	,microtime      bigint
	,microtime_diff bigint
	,utc_offset     interval
);

CREATE OR REPLACE FUNCTION "app".inherits_trigger_exception() returns trigger as
$$
BEGIN
	raise exception '%', format('"%s"."%s" es una tabla base. No se puede relalizar operaciones DML en una tabla creada para implementar herencias', TG_TABLE_SCHEMA , TG_TABLE_NAME);
END;
$$
LANGUAGE PLPGSQL;
