-- cuidado que se va a eliminar el esquema por completo!
drop schema public cascade;
create schema public;

CREATE OR REPLACE FUNCTION public.negator (INOUT boolean default null) AS
$$
BEGIN
    SELECT COALESCE(NOT($1), false) into $1;
END;
$$
LANGUAGE plpgsql;

CREATE OPERATOR public.! (
    RIGHTARG = bool,
    FUNCTION = public.negator, -- el operador utiliza la función de nagación
    NEGATOR = !<>
);

create table test (
	id serial not null,
	name varchar(255) not null,
	status boolean default false,
	primary key(id)
);

insert into test(name, status)
	select format('name - %s', g),
	(
		case
			when g%3=0 then null
			when g%2=0 then true
		else false end
	)
	from generate_series(1, 1000) as g;

update test as t set status = !t.status from (
 	select * from test
) as t2
where t2.id = t.id returning t.id, t.name, t.status , t2.status as old_status;
