
create or replace function domesa.sync_tipo_embalaje(text default null) returns setof domesa.tipo_embalaje as
$$
DECLARE
	_rc RECORD;
	_sql TEXT;
BEGIN
	$1 := app.initcap($1);

	if($1 is null or length($1) < 1 ) then
		return;
	end if;

	_sql := format('
		select te as row from domesa.tipo_embalaje as te
		where app.unaccent(app.lower(te.nombre)) = app.unaccent(app.lower(%L))
	', $1);

	execute _sql into _rc;

	IF _rc.row IS NULL THEN
		insert into domesa.tipo_embalaje(nombre) values ($1)
		returning * into _rc;
		RETURN NEXT _rc;
	ELSE
		return NEXT _rc.row;
	END IF;
END;
$$ language plpgsql;

create or replace function domesa.sync_tipo_servicio(text default null) returns setof domesa.tipo_servicio as
$$
DECLARE
	_rc RECORD;
	_sql TEXT;
BEGIN
	$1 := app.upper($1);

	if($1 is null or length($1) < 1) then
		return;
	end if;

	_sql := format('
		select ts as row from domesa.tipo_servicio as ts
		where app.unaccent(app.lower(ts.nombre)) = app.unaccent(app.lower(%L))
	', $1);

	execute _sql into _rc;

	IF _rc.row IS NULL THEN
		insert into domesa.tipo_servicio(nombre) values ($1)
		returning * into _rc;
		RETURN NEXT _rc;
	ELSE
		return NEXT _rc.row;
	END IF;
END;
$$ language plpgsql;

create or replace function domesa.sync_status_guia(text default null) returns setof domesa.status_guia as
$$
DECLARE
	_id bigint;
BEGIN
	if($1 is null) then
		return;
	end if;

	$1 := app.upper($1);

	select id into _id
	from  domesa.status_guia
	where app.unaccent(app.upper(nombre)) = app.unaccent($1);

	if not found then
		insert into domesa.status_guia (nombre) values( app.initcap($1) ) returning id into _id;
	else
		update domesa.status_guia set nombre = app.initcap($1) where id = _id;
	end if;

	return query select * from domesa.status_guia where id = _id;
END;
$$ language plpgsql;


create or replace function app.safe_cast(text, anyelement) returns anyelement as
$$
DECLARE
	_rc   record;
	_query TEXT = '';
BEGIN
	BEGIN
		_query = format('select cast (%L as %s) as val', $1,  pg_typeof($2));
		-- RAISE NOTICE '%', _query;
		execute _query into _rc;
		return _rc.val;
	EXCEPTION
		WHEN OTHERS THEN
		begin
			_query = format('select cast(%s as %s) as val', $1,  pg_typeof($2));
			--RAISE NOTICE '%', _query;
			execute _query into _rc;
			return _rc.val;
			EXCEPTION
				WHEN OTHERS THEN
				return $2;
		END;
	END;
END
$$
LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION "app".trim(TEXT)
RETURNS TEXT AS
$$
	BEGIN
		IF($1 is null) THEN RETURN null; END IF;
		RETURN trim(regexp_replace($1, '(\s+\s)+', ' ', 'gi'));
	END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "app".lower(TEXT)
RETURNS TEXT AS
$$
	BEGIN
		IF($1 is null) THEN
			RETURN null;
		END IF;

		RETURN lower("app".trim($1));
	END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "app".upper(TEXT)
RETURNS TEXT AS
$$
	BEGIN
		IF($1 is null) THEN
			RETURN null;
		END IF;

		RETURN upper("app".trim($1));
	END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "app".initcap(TEXT, _onlyFirstChar boolean = false)
RETURNS TEXT AS
$$
	BEGIN
		IF($1 is null) THEN return null; END IF;
		_onlyFirstChar := COALESCE(_onlyFirstChar, false);

		$1 := ("app".lower($1));
		IF(length($1) = 1) THEN return upper($1); END IF;

		IF(_onlyFirstChar) THEN
			return initcap(substr($1, 1, 1)) || substr($1, 2);
		END IF;

		RETURN initcap($1);
	END;
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION app.jsonb_to_array_objects(
	INOUT JSONB   default null , -- json
	IN    boolean default false  -- reverse
) as
$$
DECLARE _sql TEXT;
BEGIN
	IF($1 IS NULL) THEN RETURN; END IF;

	IF (jsonb_typeof($1) NOT IN ('array', 'object')) THEN
		$1 := '[]'::jsonb;
		RETURN;
	END IF;

	-- transform object to array [object]
	IF jsonb_typeof($1) = 'object' THEN
		$1 := jsonb_build_array($1);
	END IF;

	_sql := format('
		select jsonb_agg(j) from (
			select *
			from  jsonb_array_elements(%L) as r
			WHERE NOT ( (jsonb_typeof(r)  <> ''object'') or (r = ''{}''::jsonb) )
			%s -- dynamic sort by
		)as r(j);
	', $1  , (case when $2 is true then 'order by 1 desc' else '' end));

	execute _sql into $1;
END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION app.cast_currency_ve(in TEXT, in presicion int default 3, out numeric)
RETURNS numeric AS $$
BEGIN
	IF(presicion <0 or presicion > 10) then
		presicion := 3;
	end if;

	$1 := app.trim($1);

	WITH cleaned   AS (SELECT regexp_replace($1, '\.', '', 'g')             AS value),
	without_commas AS (SELECT regexp_replace(value, ',(?=.*[,])', '', 'g')  AS value FROM cleaned),
	has_number     AS (SELECT regexp_replace(value, '\,', '.', 'g')         AS value FROM without_commas)
	select app.safe_cast(value, '0'::numeric) into $3 from has_number;


	IF($3 IS NOT NULL) THEN
		execute format('select (%s)::numeric(14, %s)', $3 , coalesce(presicion, 3)) into $3;
	END IF;
END;
$$ LANGUAGE plpgsql;
