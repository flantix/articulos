-- https://github.com/pyramation/totp/tree/master/extensions/%40launchql/base32 wrapper!

CREATE OR REPLACE FUNCTION base32_encode ( input text ) RETURNS text AS $$
DECLARE
	_toASCCI  int[];
	_toBinary text[];
BEGIN
	IF (character_length(input) = 0) THEN
		RETURN '';
	END IF;

	-- base32_to_ascii
	DECLARE
		i int;
	BEGIN
		FOR i IN 1 ..character_length(input) LOOP
			_toASCCI := array_append(_toASCCI, ascii(substring(input from i for 1)));
		END LOOP;
	END;

	-- base32_to_binary
	DECLARE
		i      int;
		_value int;
	BEGIN
		FOR i IN 1 ..cardinality(_toASCCI) LOOP
			_value := _toASCCI[i];
			declare
				i int = 1;
				j int = 0;
				output char[] = ARRAY['x', 'x', 'x', 'x', 'x', 'x', 'x', 'x'];
				_temp TEXT;
			BEGIN
				WHILE i < 256 LOOP
					output[8-j] = (CASE WHEN (_value & i) > 0 THEN '1' ELSE '0' END)::char;
					i = i << 1;
					j = j + 1;
				END LOOP;
				_toBinary := array_append ( _toBinary, array_to_string(output, '') );
			END;
		END LOOP;
	END;

	-- base32_to_groups:
	DECLARE
		i int;
		len int = cardinality(_toBinary);
	BEGIN
		IF ( len % 5 <> 0 ) THEN
			FOR i IN 1 .. 5 - (len % 5) LOOP
				_toBinary:= array_append(_toBinary, 'xxxxxxxx');
			END LOOP;
		END IF;
	END;

	-- base32_to_chunks
	with cte as (
		select  val, generate_series (1 , length(val) , 5) as i
		from array_to_string(_toBinary, '') g(val)
	)
	select  array_agg(substring(val, i, 5)) into _toBinary from cte;

	-- base32_fill_chunks
	DECLARE
		i int;
		chunk text;
		tmp text[];
	BEGIN
		FOR i IN 1 .. cardinality(_toBinary) LOOP
			chunk = _toBinary[i];
			IF (chunk ~* '[0-1]+') THEN
				chunk = replace(chunk, 'x', '0');
			END IF;
			tmp = array_append(tmp, chunk);
		END LOOP;

		_toBinary := tmp;
	END;

	-- base32_to_decimal:
	DECLARE
		i int;
		chunk TEXT;
		tmp  TEXT[];
	BEGIN
		FOR i IN 1 .. cardinality(_toBinary) LOOP
			chunk = _toBinary[i];
			IF (chunk ~* '[x]+') THEN
				chunk = '=';
			ELSE
				execute 'SELECT B''' || (_toBinary[i])::TEXT || '''::int' into chunk;
			END IF;
			tmp = array_append(tmp, chunk);
		END LOOP;
		_toBinary := tmp;
	END;

	-- base32_to_base32
	DECLARE
		i int;
		tmp TEXT[];
		alphabet CHAR(1)[] := '{A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z,2,3,4,5,6,7}';
		chunk text;
	BEGIN
		FOR i IN 1 ..cardinality(_toBinary) LOOP
			chunk = _toBinary[i];
			IF (chunk = '=') THEN
				chunk := '=';
			ELSE
				chunk := alphabet[(chunk::int)+1];
			END IF;
			tmp := array_append(tmp, chunk);
		END LOOP;
		return array_to_string(tmp,'');
	END;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION base32_valid ( input text , OUT BOOLEAN) RETURNS boolean AS $$
BEGIN
	select coalesce ( (upper(input) ~* '^[A-Z2-7]+=*$') , false ) into $2;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE OR REPLACE FUNCTION base32_decode( input text ) RETURNS text AS $$
DECLARE
	i      int;
	arr    int[];
	output text[];
	len    int;
	num    int;
	value  int = 0;
	index  int = 0;
	bits   int = 0;
BEGIN

	IF($1 is null) THEN
		return '';
	end if;

	len = character_length(input);
	IF (len = 0) THEN RETURN ''; END IF;

	IF (NOT base32_valid(input)) THEN
		RAISE EXCEPTION 'INVALID_BASE32';
	END IF;

	input = replace(input, '=', '');
	input = upper(input);
	len   = character_length(input);
	num   = len * 5 / 8;

	select array(select * from generate_series(1,num)) INTO arr;

	FOR i IN 1 .. len LOOP
		value = (value << 5) | (position(substring(input from i for 1) in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567')::int - 1);
		bits = bits + 5;

		IF (bits >= 8) THEN
			DECLARE
				bin text;
				m int;
				a int := value;
				b int := (bits - 8);
			BEGIN
				IF (b >= 32 OR b < -32) THEN
					m = b/32;
					b = b-(m*32);
				END IF;

				IF (b < 0) THEN
					b = 32 + b;
				END IF;

				IF (b = 0) THEN
					arr[index] := ((a>>1)&2147483647)*2::bigint+((a>>b)&1) & 255;

				ELSE
					IF (a < 0) THEN
						a = (a >> 1);
						a = a & 2147483647; -- 0x7fffffff
						a = a | 1073741824; -- 0x40000000
						a = (a >> (b - 1));
					ELSE
						a = (a >> b);
					END IF;

					arr[index] := a & 255;
				END IF;
			END;

			index = index + 1;
			bits = bits - 8;
		END IF;
	END LOOP;

	len = cardinality(arr);

	FOR i IN 0 .. len-2 LOOP
		output = array_append(output, chr(arr[i]));
	END LOOP;

	RETURN array_to_string(output, '');
END;
$$ LANGUAGE plpgsql IMMUTABLE;


/*
	select base32_encode('hola ámigo!*Ç') = 'NBXWYYJA4FWWSZ3PEEVMO===' as is_ok,
	base32_encode('hola ámigo!*Ç') , 'hola ámigo!*Ç' as val
*/
