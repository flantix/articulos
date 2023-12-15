------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.url_encode(data bytea) RETURNS text LANGUAGE sql AS $$
	SELECT translate(encode(data, 'base64'), E'+/=\n', '-_');
$$ IMMUTABLE;

CREATE OR REPLACE FUNCTION app.url_decode(data text) RETURNS bytea LANGUAGE sql AS $$
	WITH t AS (SELECT translate(data, '-_', '+/') AS trans),
	rem AS (SELECT length(t.trans) % 4 AS remainder FROM t) -- compute padding size
	SELECT decode(
		t.trans ||
		CASE WHEN rem.remainder > 0 THEN repeat('=', (4 - rem.remainder))
		ELSE '' END,
	'base64') FROM t, rem;
$$ IMMUTABLE;

CREATE OR REPLACE function app.jwt_sign(payload json, secrect text, out token text) RETURNS TEXT AS
$$
BEGIN
		IF(secrect is null or length(secrect) < 6 ) THEN
			raise exception 'secret debe ser de por lo menos 6 caracteres';
		END IF;

		IF(payload is null) THEN
			raise exception 'payload no debe ser nulo';
		END IF;

		with prefix as (
			select format(
				 '%s.%s'
				,app.url_encode(convert_to('{"alg":"HS256","typ":"JWT"}', 'utf8'))
				,app.url_encode(convert_to(payload::text, 'utf8'))
			) as data
		)
		select prefix.data || '.' || app.url_encode(app.hmac(prefix.data, secrect, 'sha256'))
		into token from prefix;
END;
$$ language plpgsql;

--@todo refactory....
create or replace function app.jwt_verify(token text, secrect text)
RETURNS TABLE(header json, payload json, valid boolean) as
$$
	with cto as(
		select regexp_split_to_array(token, '\.') as r
	),
	cto2 as(
		select app.url_encode(app.hmac(format('%s.%s', r[1] , r[2]), secrect, 'sha256')) = r[3]
		as valid from cto
	)
	select
		convert_from(app.url_decode(r[1]), 'utf8')::json AS header,
		convert_from(app.url_decode(r[2]), 'utf8')::json AS payload,
		cto2.valid
	from cto, cto2;
$$  LANGUAGE sql;


/*
------------------------------------------------------------------------------------------------------
-- test ok
with cto as (
	select token from app.jwt_sign('{"test" : 1 }', '123456')
)
select (app.jwt_verify(cto.token, '123456')).*  from cto;

-- test fail:
with cto as (
	select token from app.jwt_sign('{"test" : 1 }', '123456')
)
select (app.jwt_verify(cto.token, '654321')).*  from cto;
*/



