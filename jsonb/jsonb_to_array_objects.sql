

CREATE OR REPLACE FUNCTION jsonb_to_array_objects(
	INOUT JSONB   default null , -- json
	IN    boolean default false  -- reverse
) as
$$
DECLARE _sql TEXT;
BEGIN
	IF($1 IS NULL) THEN RETURN; END IF;

	IF (jsonb_typeof($1) NOT IN ('array', 'object')) THEN
		$1 := '[]'::jsonb;
		RETURN ;
	END IF;

	-- object to array [object]
	IF jsonb_typeof($1) = 'object' THEN
		$1 := jsonb_build_array($1);
	END IF;

	_sql := format('
		select jsonb_agg(j) from (
			select *
			from  jsonb_array_elements(%L) as r
			WHERE NOT ( (jsonb_typeof(r)  <> ''object'') or (r = ''{}''::jsonb) )
			%s -- dinamic sort by
		)as r(j);
	', $1  , (case when $2 is true then 'order by 1 desc' else '' end));

	execute _sql into $1;
END;
$$ LANGUAGE PLPGSQL;

