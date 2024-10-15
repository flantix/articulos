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
	select format('ALTER DATABASE %s SET SEARCH_PATH TO app, geozona', current_database() ) into  _sql;
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

































-- auth
-- \i 01-auth/00-base/00-schema.sql
-- \i 01-auth/01-admin/00-schema.sql




-- \i 01-auth/00-schema.sql
-- --
-- \i 02-direccion.sql
-- \i 03-cliente.sql
-- \i data/01-direccion.sql


-------------------------------------------------------------
--- test data :
-- \! reset



/*




--- cliente :

insert into "app".direccion(id_pais, id_estado, id_ciudad, id_municipio , codigo_postal, direccion, detalle, tlf1, tlf2) values
	(1,1,1,1,'00001', 'direccion1' , 'detalle de direccion1' , '0414-000-00-01', '0414-000-00-02'),
	(1,1,1,2,'00002', 'direccion2' , 'detalle de direccion2' , '0414-000-00-03', '0414-000-00-04');

insert into "app".cliente(
	id_direccion_destino,
	id_direccion_origen,
	nombre,
	codigo,
	doc_legal,
	origen,
	email,
	tlf1,
	tlf2,
	receptor_nombre,
	receptor_doc_legal,
	eliminado,
	mail_recepcion_paquete,
	mail_notificar_entrega,
	mail_notificar_salida
)
values (
	1,
	2,
	'Usuario Uno',
	'USUN',
	'V-000001',
	'Origen1' ,
	'user1@mail.com',
	'0212-000-00-01',
	'0212-000-00-02',
	'Usuario quien recibe1',
	'V-000002',
	false,
	true,
	false,
	true
);

insert into app.cliente_nota(id_cliente, nota) values (1, 'Primera nota') , (1, 'Segunda nota');
*/
