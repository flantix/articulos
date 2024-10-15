CREATE TABLE "app".cliente(
	id                       bigserial     NOT     NULL,
	id_referido              bigint        DEFAULT NULL,
	--
	id_direccion_destino     bigint        DEFAULT NULL,
	id_direccion_origen      bigint        DEFAULT NULL,
	--
	nombre                   varchar(255)  NOT     NULL,
	codigo                   varchar(16)   NOT     NULL,
	doc_legal                varchar(60)   DEFAULT NULL,
	origen                   varchar(100)  DEFAULT NULL,
	email                    varchar(255)  NOT     NULL,
	tlf1                     varchar(60)   DEFAULT NULL,
	tlf2                     varchar(60)   DEFAULT NULL,
	--
	receptor_nombre          varchar(255)  NOT     NULL,
	receptor_doc_legal       varchar(60)   DEFAULT NULL,
	--
	eliminado                boolean       NOT NULL DEFAULT FALSE,
	mail_recepcion_paquete   boolean       NOT NULL DEFAULT FALSE,
	mail_notificar_salida    boolean       NOT NULL DEFAULT FALSE,
	mail_notificar_entrega   boolean       NOT NULL DEFAULT FALSE,
	fecha_actualizacion      bigint        NOT NULL DEFAULT "app".unixtime(),
	primary key(id),
	constraint fk1_cliente foreign key (id_direccion_destino) references "app".direccion (id) on update cascade on delete set null,
	constraint fk2_cliente foreign key (id_direccion_origen)  references "app".direccion (id) on update cascade on delete set null
);

create table "app".cliente_nota(
	id         bigserial       not     null,
	id_cliente bigint          default null,
	nota       varchar(100)    not     null,
	update_at  bigint          not     null default "app".unixtime(),
	primary key(id),
	constraint fk1_cliente_nota foreign key (id_cliente) references "app".cliente on update cascade on delete cascade
);


/*
CREATE TABLE "app".cliente(
	id       bigserial     NOT NULL,
	primary key(id)
);
*/
