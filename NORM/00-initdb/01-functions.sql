-------------------------------------------------------------
--- random :

CREATE OR REPLACE FUNCTION "app".rand_int(_min INT, _max INT) RETURNS INT AS
$$
	BEGIN
		IF(_min = _max) THEN
			return _min;
		END IF;

		IF(_min < _max) THEN
			RETURN floor(random()* (_max-_min + 1) + _min);
		ELSE
			RETURN floor(random()* (_min-_max + 1) + _max);
		END IF;
	END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION "app".rand_str(_length integer, _chars char(1)[] default null) returns VARCHAR(255) AS
$$
	DECLARE
		result text     := '';
		i      integer  := 0;

	BEGIN

		IF(_chars is null or array_length(_chars, 1) is null or array_length(_chars, 1) <2) THEN
			_chars := '{0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z,a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z}';
		END IF;

		IF (_length < 0) THEN
			return result;
			RAISE NOTICE 'truncate to length 0';
		END IF;

		IF(_length > 1000) THEN
			_length = 1000;
			RAISE NOTICE 'truncate to length 255';
		END IF;

		for i IN 1.._length
		loop
			result := result || _chars[1+random()*(array_length(_chars, 1)-1)::integer];
		END loop;
		return result;
	END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "app".pin_verify(_length integer = 4, out pin text) returns TEXT AS
$$
	BEGIN
		IF(_length is NULL or _length < 1) THEN _length = 4; END if;
		pin := "app".rand_str(_length, '{1,2,3,4,5,6,7,8,9,0}');
	END;
$$ LANGUAGE plpgsql;


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


/*
	schema
	table
	column
	length
*/
CREATE OR REPLACE FUNCTION "app".uniqid(text, text, text, int default null) RETURNS TEXT as
$$
	DECLARE
		_sql     TEXT;
		_randStr TEXT;
		_count   int;
		_schema  TEXT = $1;
		_tb      TEXT = format('%s.%s', $1,$2);
		_column  TEXT = format('%s.%s.%s', $1,$2,$3);
		_size    int  = $4;
	BEGIN

		-- block check params:
		DECLARE
			_rc      RECORD;
			_sql     TEXT;
			_types   text[] = '{bpchar,varchar,text}'::varchar[];

		-- validar campos:
		BEGIN
			_sql = format('

				SELECT
					COALESCE(CAST(
						information_schema._pg_char_max_length(information_schema._pg_truetypid(a, t), information_schema._pg_truetypmod(a, t))
						AS numeric
					),255) AS size,

					string_to_array(COALESCE(td.typname, tb.typname, t.typname), '''') AS data_type

					from pg_class c

					inner JOIN pg_attribute a ON a.attrelid = c.oid
					LEFT  JOIN pg_attrdef ad ON a.attrelid = ad.adrelid AND a.attnum = ad.adnum
					LEFT  JOIN pg_type t ON a.atttypid = t.oid
					LEFT  JOIN pg_type tb ON (a.attndims > 0 OR t.typcategory=''A'') AND t.typelem > 0 AND t.typelem = tb.oid OR t.typbasetype > 0 AND t.typbasetype = tb.oid
					LEFT  JOIN pg_type td ON t.typndims > 0 AND t.typbasetype > 0 AND tb.typelem = td.oid
					LEFT  JOIN pg_namespace d ON d.oid = c.relnamespace

				WHERE
					a.attnum > 0 AND t.typname != '''' AND NOT a.attisdropped
					and d.nspname not in (''pg_catalog'', ''pg_toast'', ''information_schema'')
					and (format(''%%s.%%s.%%s'', d.nspname, c.relname, a.attname) = %L)
			', _column);

			execute _sql into _rc;

			IF(_rc is null) THEN
				raise exception 'No existe el campo "%"',  _column;
			END IF;

			IF(_rc.size is null) THEN
				raise exception 'No existe el campo "%"',  _column;
			END IF;

			IF(_size is null or _size < 16) THEN
				_size := _rc.size;
			end IF;

			IF(_size < 16) THEN
				raise exception 'parametro size "%" no debe menor a 16 para aplicar "app".uniqid', _size;
			END IF;

			-- check  data type in data_types:
			IF(_types  @> _rc.data_type  = false) THEN
				raise exception 'el campo "%" debe ser del tipo % para aplicar "app".uniqid', _column, _types;
			end if;

			-- check min size:
			IF(_rc.size < 16 ) THEN
				raise exception 'el campo "%"  debe tener un minimo de 16 caracteres para aplicar "app".uniqid', _column;
			END IF;

			IF(_size > _rc.size) THEN
				raise exception 'parametro size "%" no debe ser mayor que "%" para aplicar "app".uniqid en la columna "%"', _size , _rc.size, _column;
			END IF;
		END;

		LOOP
			_randStr = "app".rand_str(_size);
			_sql     = format('SELECT COUNT(id) FROM %s WHERE %s=%L', _tb, $3, _randStr);
			execute _sql into _count;
			IF(_count = 0) THEN EXIT;
			END IF;
		END LOOP;

		RETURN _randStr;
	END;
$$
LANGUAGE plpgsql;

-------------------------------------------------------------
--- strings fn :

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

CREATE OR REPLACE FUNCTION "app".slug(_str TEXT)
RETURNS TEXT AS
$BODY$
	BEGIN
		IF(_str is null) THEN RETURN null; END IF;
		_str = "app".lower("app".unaccent('/' || _str || '/'));
		_str = regexp_replace(_str , '(&amp;{1,})','-and-', 'gi');
		_str = regexp_replace(_str , '( & )','-and-', 'gi');
		_str = regexp_replace(_str, '[^a-z0-9\-_\/]+', '-', 'gi');
		_str = regexp_replace(regexp_replace(_str, '\-+$', ''), '^\-', '');
		_str = regexp_replace(_str, '(-{2,})', '-', 'gi');
		_str = regexp_replace(_str, '(\/{2,})', '/', 'gi');
		_str = regexp_replace(_str, '(-\/)', '/', 'gi');
		_str = regexp_replace(_str, '(\/-)$', '/', 'gi');
		_str = regexp_replace(regexp_replace(_str, '\-+$', ''), '^\-', '');
		return _str;
	END;
$BODY$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "app".slug(_str TEXT, _ext TEXT)
RETURNS TEXT AS
$BODY$
	BEGIN
		_str := "app".slug(_str);
		if(_str = '/') THEN return null; END IF;
		_str = "app".lower(regexp_replace(_str , '(\/)$', '' , 'gi'));
		_ext = regexp_replace(_ext, '[^a-z0-9]+', '', 'gi');

		IF(length(_ext) < 1) THEN
			return _str || '/';
		END IF;

		return _str || '.' || _ext;
	END;
$BODY$
LANGUAGE plpgsql;


-------------------------------------------------------------
--- arrays :

CREATE OR REPLACE FUNCTION "app".array_length (ANYARRAY) RETURNS bigint AS
$$
declare _count bigint = 0;
begin
	IF($1 is null) then
		return 0;
	END IF;

	select array_length($1, 1) into _count;
	IF(_count is null) then
		return 0;
	end if;

	return _count;
end;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "app".array_merge (ANYARRAY, ANYARRAY) RETURNS ANYARRAY AS
$$
	SELECT ARRAY_AGG(x ORDER BY x)
	FROM (
		SELECT DISTINCT UNNEST($1 || $2) AS x
	) s;
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE FUNCTION "app".array_unique (ANYARRAY) RETURNS ANYARRAY AS
$$
	SELECT ARRAY_AGG(x ORDER BY x)
	FROM (
		SELECT DISTINCT UNNEST($1) AS x
	) s;
$$ LANGUAGE SQL STRICT;

CREATE or replace function "app".array_upper(TEXT[]) returns TEXT[] as
$$
	SELECT ARRAY_AGG(x order by x)
	FROM (SELECT DISTINCT "app".upper(UNNEST($1)) AS x) s;
$$ LANGUAGE SQL STRICT;

CREATE or replace function "app".array_lower(TEXT[]) returns TEXT[] as
$$
	SELECT ARRAY_AGG(x order by x)
	FROM (SELECT DISTINCT "app".lower(UNNEST($1)) AS x) s;
$$ LANGUAGE SQL STRICT;

CREATE or replace function "app".is_mobile(TEXT default null ) returns boolean as
$$
	select (
		"app".array_length(regexp_match(r,'^\d+$', 'i')) > 0  and
		"app".array_length(regexp_match(r,'^(0414|0424|0412|0416)', 'i')) > 0 and
		length(r) = 11

	) as is_mobile
	from ( select coalesce($1,'')) as r(r)
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION "app".initcap(TEXT, _onlyFirstChar boolean = false)
RETURNS TEXT AS
$$
	BEGIN
		IF($1 is null) THEN return null; END IF;
		_onlyFirstChar := COALESCE(_onlyFirstChar, false);

		$1 := ("app".lower($1));
		IF(length($1) = 1) THEN return "app".upper($1); END IF;

		IF(_onlyFirstChar) THEN
			return initcap(substr($1, 1, 1)) || substr($1, 2);
		END IF;

		RETURN initcap($1);
	END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "app".array_intersect (ANYARRAY, ANYARRAY) RETURNS ANYARRAY AS
$$
	SELECT ARRAY(SELECT UNNEST($1) INTERSECT SELECT UNNEST($2)) order by 1;
$$ LANGUAGE SQL STRICT;

-------------------------------------------------------------
--- passwod hash :

CREATE OR REPLACE FUNCTION  "app".password_hash(varchar(70) default null) returns varchar(70) as
$$
	select "app".crypt( COALESCE($1, "app".rand_str(10)), "app".gen_salt('bf') );
$$ language sql;

CREATE OR REPLACE FUNCTION  "app".check_passw( _passw varchar(70) default null, _hash varchar(70) default null) returns boolean as
$$
	select ( hash = "app".crypt(raw , hash))
	from (
		select
			COALESCE(_passw, "app".rand_str(10))    as raw,
			COALESCE(_passw, "app".password_hash()) as passw,
			COALESCE(_hash,  "app".password_hash()) as hash
	) as r;
$$ language sql;


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












