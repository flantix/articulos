-------------------------------------------------------------
--- tipo_envio (brisar tabla interna) :

create table domesa.tipo_envio(
	id bigserial not null,
	nombre varchar(100) not null,
	primary key(id)
);

create unique index index00_tipo_envio on domesa.tipo_envio (nombre);
insert into domesa.tipo_envio (nombre) values ('Sobre'), ('Paquete'), ('Caja');


-------------------------------------------------------------
--- comment :

create table domesa.forma_pago(
	id bigserial not null,
	nombre varchar(100) not null,
	primary key(id)
);

create unique index index00_forma_pago on domesa.forma_pago (nombre);
insert into domesa.forma_pago (nombre) values ('Pto. de venta'), ('Efectivo Bs'), ('Efectivo $'), ('Pago Movil'), ('Transferencia');

-------------------------------------------------------------
--- tipo_servicio :

create table domesa.tipo_servicio(
	id bigserial not null,
	nombre varchar(100) not null,
	primary key(id)
);

create unique index index00_tipo_servicio on domesa.tipo_servicio (nombre);

-------------------------------------------------------------
--- tipo_embalaje :

create table domesa.tipo_embalaje(
	id bigserial not null,
	nombre varchar(100) not null,
	primary key(id)
);

create unique index index00_tipo_embalaje on domesa.tipo_embalaje (nombre);

-------------------------------------------------------------
--- estados :

create table domesa.estado(
	id bigserial not null,
	nombre varchar(100) not null,
	primary key(id)
);

create unique index index00_estado on domesa.estado (nombre);


-------------------------------------------------------------
--- domesa status :

create table domesa.status_guia(
	id     bigserial not null,
	nombre varchar(100) not null,
	primary key(id)
);

create unique index index00_status_guia on domesa.status_guia (nombre);

-------------------------------------------------------------
--- operador :

create table domesa.operador(
	id       bigserial     not     null,
	id_auth  bigint        default null,
	nombres  varchar(255)  default null,
	username varchar(100)   not     null,
	cookie   varchar(100)   default null,
	primary key(id)
);

create unique index index00_operador on domesa.operador (id_auth);
create        index index01_operador on domesa.operador (username);
create        index index02_operador on domesa.operador (cookie);

insert into domesa.operador(nombres, username) values
	('Marilis'    , '0385Master0001'),
	('Devid'      , '0385Operador20005'),
	('Heinsember' , '0385Operador20004')
;

-------------------------------------------------------------
--- guia :

create table domesa.guia(
	id                     bigint          not     null ,
	id_tipo_envio          bigint          default null ,
	id_forma_pago          bigint          default null ,
	id_operador            bigint          default null ,
	id_tipo_servicio       bigint          not     null ,
	id_tipo_embalaje       bigint          not     null ,
	id_status_guia         bigint          not     null ,
	nro_guia               bigint          not     null ,
	peso                   numeric(14, 6)  not     null default 0,
	domesa_monto           numeric(14, 3)  not     null default 0,
	domesa_costo_servicio  numeric(14, 3)  not     null default 0,
	conciliacion           numeric(14, 3)  not     null default 0,
	comision_porcentual    numeric(14, 3)  not     null default 0,
	recarga_x_embalaje     numeric(14, 3)  not     null default 0,
	tipo_traslado          varchar(20)     default null ,
	mercadolibre           boolean         not     null default false,
	fecha_registro         bigint          not     null,
	fecha_actualizacion    bigint          not     null default app.unixtime(),
	primary key(id)
);

CREATE UNIQUE INDEX index00_guia ON domesa.guia(id, nro_guia);
CREATE UNIQUE INDEX index02_guia ON domesa.guia( nro_guia);


























