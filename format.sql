/*
create schema app;
set search_path to app;

CREATE TABLE app.estado (
	id      bigint      not null,
	nombre  varchar(50) not null,
	primary key(id)
);

create unique index index01_estado on app.estado(nombre);
create unique index index02_estado on app.estado(id);
*/

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

create or replace function app.test(jsonb) returns setof app.estado as
$$
DECLARE
	_ids     bigint[];
	_deleted bigint[];
	_updated bigint[];
	_created bigint[];
	_sql text         := 'select * from app.estado order by nombre asc';
BEGIN

	-- VALIDATION REGION :
	DECLARE _rc RECORD;
	BEGIN
		-------------------------------------------------------------
		--- Check if the input JSONB is an array and not empty:
		--- Verifica si el JSONB de entrada es un array y no está vacío:
		with validate as (
			with
			 cte1 as (select $1 as data)
			,cte2 as (select jsonb_typeof(cte1.data) as typeof , data from cte1)
			select * from cte2
		)
		select
			 data
			,typeof
			,(
				-- error de datos de entrada cuando:
				case
					when (typeof not in('object', 'array') or typeof is null) then true
					when (typeof='array'  and data = '[]'::jsonb)             then true
					when (typeof='object' and data = '{}'::jsonb)             then true
					else false end

			) as has_error into _rc
		from validate;

		-- si hay un error matamos el proceso y entregamos lo que hay en db
		IF _rc.has_error THEN
			RETURN QUERY EXECUTE _sql;
			RETURN;
		END IF;

		-- transform object to array
		IF _rc.typeof = 'object' THEN
			select jsonb_agg($1) into $1;
		END IF;

		-------------------------------------------------------------
		--- Clean the input data:
		--- Limpia los datos de entrada:

		select array_agg(r.id) as ids, jsonb_agg(r) as data from (
			with cte as (
				select
					 app.safe_cast(item->>'id'     , null::bigint)      as id
					,app.safe_cast(item->>'nombre' , null::varchar(50)) as nombre
				from jsonb_array_elements($1) as r(item)
			) select distinct on (id, nombre) * from cte
			where cte.id is not null and length(cte.nombre) > 0
		) as r into _rc;

		$1 := _rc.data;

		-------------------------------------------------------------
		--- Register valid IDs:
		--- Registra identificadores válidos:
		_ids := _rc.ids;

		-------------------------------------------------------------
		--- Validate that JSONB is not empty:
		--- Valida que el JSONB no esté vacío:

		IF COALESCE(array_length(_ids, 1) = 0 , true)  then
			RETURN QUERY EXECUTE _sql;
			RETURN;
		END IF;
	END;

	-- DML REGION :
	BEGIN
		-------------------------------------------------------------
		--- Sync records that are missing (using a DELETE operation):
		--- Sincroniza registros que faltan (usando una operación de DELETE):

		with for_delete as (
			delete from app.estado
			where not ARRAY[id] <@ _ids
			returning id
		) select array_agg(id) into _deleted from for_delete;

		-------------------------------------------------------------
		--- Sync new values for existing records (using an UPDATE operation):
		--- Sincroniza nuevos valores para registros existentes (usando una operación de UPDATE):

		with for_update as (
			update app.estado as e1
			set nombre = e2.nombre from (
				with cte as (
					select
					    (item->>'id')::bigint              as id
					   ,(item->>'nombre')::varchar(50)     as nombre
					from (select jsonb_array_elements($1)) as r(item)
				)
				select * from cte
			) as e2
			where
				e1.id            = e2.id
				and ARRAY[e1.id] <@ _ids
				and e1.nombre    <> e2.nombre
			returning e1.id
		)
		select array_agg(id) into _updated from for_update;

		-------------------------------------------------------------
		--- Insert new records (using an INSERT operation):
		--- Inserta nuevos registros (usando una operación de INSERT):

		insert into app.estado
		with for_insert as (
			select
				 (item->>'id')::bigint          as id
				,(item->>'nombre')::varchar(50) as nombre
			from jsonb_array_elements($1) as r(item)
		)
		select * from for_insert
		where not ARRAY[id] <@ (_deleted || _updated)
		and ARRAY[id] <@ _ids
		except select id, nombre from app.estado -- skip for unique constraint
		order by id asc;
	END;

	-------------------------------------------------------------
	--- TODO Cache Notify flags REGION:
	/*
		--- cache Notify flags
		--- Banderas de caché:
		if _deleted is not null then
			-- @todo write flag cache deleted
			-- @todo escribir bandera de caché eliminada
			RAISE NOTICE 'deleted= %', _deleted;
		end if;
		if _updated is not null then
			-- @todo write flag cache updated
			-- @todo escribir bandera de caché actualizada
			RAISE NOTICE 'upated= %', _updated;
		end if;
		if _inserted is not null then
			-- @todo write flag cache insert
			-- @todo escribir bandera de caché insertada
			RAISE NOTICE 'insert= %', _updated;
		end if;
	*/

	RETURN QUERY EXECUTE _sql;
END;
$$
language plpgsql;


-------------------------------------------------------------
--- examples :

/*

-- first time, insert for JSON:
-- primera vez, inserta para JSON:

select jsonb_agg(r) from app.test('[{"id": "1", "nombre": "Amazonas"}, {"id": "2", "nombre": "Anzoátegui"}, {"id": "3", "nombre": "Apure"}, {"id": "4", "nombre": "Aragua"}, {"id": "5", "nombre": "Barinas"}, {"id": "6", "nombre": "Bolívar"}, {"id": "7", "nombre": "Carabobo"}, {"id": "8", "nombre": "Cojedes"}, {"id": "9", "nombre": "Delta Amacuro"}, {"id": "10", "nombre": "Distrito Capital"}, {"id": "11", "nombre": "Falcón"}, {"id": "12", "nombre": "Guárico"}, {"id": "13", "nombre": "Lara"}, {"id": "14", "nombre": "Mérida"}, {"id": "15", "nombre": "Miranda"}, {"id": "16", "nombre": "Monagas"}, {"id": "17", "nombre": "Nueva Esparta"}, {"id": "18", "nombre": "Otro"}, {"id": "19", "nombre": "Portuguesa"}, {"id": "20", "nombre": "Sucre"}, {"id": "21", "nombre": "Táchira"}, {"id": "22", "nombre": "Trujillo"}, {"id": "23", "nombre": "Yaracuy"}, {"id": "24", "nombre": "Zulia"}, {"id": "27", "nombre": "Dependencias Federales"}, {"id": "28", "nombre": "Vargas"}]') as r;

-- update for json when rows id 1,2,3 not exist 
-- actualizar para JSON cuando las filas con id 1,2,3 no existen

select jsonb_agg(r) from app.test('[{"id": "4", "nombre": "Aragua"}, {"id": "5", "nombre": "Barinas"}, {"id": "6", "nombre": "Bolívar"}, {"id": "7", "nombre": "Carabobo"}, {"id": "8", "nombre": "Cojedes"}, {"id": "9", "nombre": "Delta Amacuro"}, {"id": "10", "nombre": "Distrito Capital"}, {"id": "11", "nombre": "Falcón"}, {"id": "12", "nombre": "Guárico"}, {"id": "13", "nombre": "Lara"}, {"id": "14", "nombre": "Mérida"}, {"id": "15", "nombre": "Miranda"}, {"id": "16", "nombre": "Monagas"}, {"id": "17", "nombre": "Nueva Esparta"}, {"id": "18", "nombre": "Otro"}, {"id": "19", "nombre": "Portuguesa"}, {"id": "20", "nombre": "Sucre"}, {"id": "21", "nombre": "Táchira"}, {"id": "22", "nombre": "Trujillo"}, {"id": "23", "nombre": "Yaracuy"}, {"id": "24", "nombre": "Zulia"}, {"id": "27", "nombre": "Dependencias Federales"}, {"id": "28", "nombre": "Vargas"}]') as r;

-- update for json when rows id 99,100 is append in json not exist 
-- actualizar para JSON cuando las filas con id 99,100 se agregan en JSON y no existen

select jsonb_agg(r) from app.test('[{"id": "99", "nombre": "new1"} , {"id": "100", "nombre": "new2"} , {"id": "4", "nombre": "Aragua"}, {"id": "5", "nombre": "Barinas"}, {"id": "6", "nombre": "Bolívar"}, {"id": "7", "nombre": "Carabobo"}, {"id": "8", "nombre": "Cojedes"}, {"id": "9", "nombre": "Delta Amacuro"}, {"id": "10", "nombre": "Distrito Capital"}, {"id": "11", "nombre": "Falcón"}, {"id": "12", "nombre": "Guárico"}, {"id": "13", "nombre": "Lara"}, {"id": "14", "nombre": "Mérida"}, {"id": "15", "nombre": "Miranda"}, {"id": "16", "nombre": "Monagas"}, {"id": "17", "nombre": "Nueva Esparta"}, {"id": "18", "nombre": "Otro"}, {"id": "19", "nombre": "Portuguesa"}, {"id": "20", "nombre": "Sucre"}, {"id": "21", "nombre": "Táchira"}, {"id": "22", "nombre": "Trujillo"}, {"id": "23", "nombre": "Yaracuy"}, {"id": "24", "nombre": "Zulia"}, {"id": "27", "nombre": "Dependencias Federales"}, {"id": "28", "nombre": "Vargas"}]') as r;

-- object single json value
-- valor JSON de objeto único
select * from app.test('{"id": "99", "nombre": "new1"}');

-------------------------------------------------------------
--- for invalid typeof json:
--- para tipos de JSON inválidos:

-- empty json array
-- array JSON vacío
select * from app.test('[]');

-- scalar json value
-- valor escalar JSON
select * from app.test('123456');


*/
