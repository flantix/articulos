
CREATE SCHEMA    IF NOT EXISTS app;
CREATE EXTENSION IF NOT EXISTS pgcrypto with schema app;
set SEARCH_PATH to app;

CREATE OR REPLACE FUNCTION app.random_token(
	 integer = 128
	,out TEXT
) AS
$$
DECLARE
	_replaces char(1)[] := '{
		$,0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F,G,H,I,J,
		K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z,a,b,c,d,e,
		f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z
	}';
BEGIN
	-- out max length!
	$1 := (
		case
		when $1 is null then 128
		when $1 <  16   then 16
		when $1 > 512   then 512
		else $1 end
	);

	WITH  cte1 AS (SELECT replace(encode(app.gen_random_bytes(1024), 'base64'), E'\n', '') AS hash)
	     ,cte2 AS (SELECT length(hash) AS max_len, hash FROM cte1)
	     ,cte3 AS (select substring(
	     		cte2.hash FROM
	     		floor(random() * (cte2.max_len - $1) + 1)::int FOR $1) as cte3 from cte2
	    )
	 select cte3 into $2 FROM cte3;

    SELECT array[
        _replaces[floor(random() * (array_length(_replaces, 1) - 1)) + 1],  -- aleatorio para '+'
        _replaces[floor(random() * (array_length(_replaces, 1) - 1)) + 1],  -- aleatorio para '/'
        _replaces[floor(random() * (array_length(_replaces, 1) - 1)) + 1]   -- aleatorio para '='
    ] INTO _replaces;

     $2:= replace($2, '+' , _replaces[1]);
     $2:= replace($2, '/' , _replaces[2]);
     $2:= replace($2, '=' , _replaces[3]);

END;
$$ LANGUAGE plpgsql volatile;

DO $$
DECLARE _sql TEXT;
BEGIN
	select format('ALTER DATABASE %s SET SEARCH_PATH TO app'   , current_database()) into _sql;
	execute _sql;
END$$;

-- explain analyze select app.random_token(16);
explain analyze
with pow as (select pow(2,g)::int from generate_series(5, 9) as g)
select  pow as nro_chars, app.random_token(pow) from pow;




