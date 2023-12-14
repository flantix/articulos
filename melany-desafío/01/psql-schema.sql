
create table "Empleados"(
	"Id" serial not null,
	"Nombre" varchar(100) not null,
	"Deparamento" varchar(100) not null,
	"Salario" numeric(10,2) not null default 0,
	primary key ("Id")
);



insert into "Empleados"
select
	 g as Id
	,format('Usuario %s', g) as "Nombre"
	,('{"Dep. Ventas", "Dep. Soporte Técnico", "Dep. HHRR"}'::VARCHAR[50])[floor(random() * 3 + 1)] "Departamento"
	,(floor(random()* 100 + 1) || '.' || floor(random()* 10 + 1))::numeric(10, 2) as "Salario"
 FROM generate_series(1, 10000) as g returning *;

SELECT pg_catalog.setval('public."Empleados_Id_seq"', 10000, true);
