-------------------------------------------------------------
--- sync_domesa_servicios :

create or replace function domesa.sync_servicio(text default null) returns setof domesa.tipo_servicio as
$$
declare
	_id bigint;
BEGIN
	if($1 is null) then
		return;
	end if;


	$1 := app.upper($1);

	select id into _id
	from  domesa.tipo_servicio
	where app.unaccent(app.upper(nombre)) = app.unaccent($1);

	if not found then
		insert into domesa.tipo_servicio (nombre) values( app.upper($1) ) returning id into _id;
	else
		update domesa.tipo_servicio set nombre = app.upper($1) where id = _id;
	end if;

	return query select * from domesa.tipo_servicio where id = _id;
END;
$$ language plpgsql;


--------------------------------------------------------------
--- sync domesa_embalaje :

create or replace function domesa.sync_embalaje(text default null) returns setof domesa.tipo_embalaje as
$$
declare
	_id bigint;
BEGIN
	if($1 is null) then
		return;
	end if;


	$1 := app.upper($1);

	select id into _id
	from  domesa.tipo_embalaje
	where app.unaccent(app.upper(nombre)) = app.unaccent($1);

	if not found then
		insert into domesa.tipo_embalaje (nombre) values( app.initcap($1) ) returning id into _id;
	else
		update domesa.tipo_embalaje set nombre = app.initcap($1) where id = _id;
	end if;

	return query select * from domesa.tipo_embalaje where id = _id;
END;
$$ language plpgsql;


-------------------------------------------------------------
--- sync domesa_estados :

create or replace function domesa.sync_estado(text default null) returns setof domesa.estado as
$$
declare
	_id bigint;
BEGIN
	if($1 is null) then
		return;
	end if;

	$1 := app.upper($1);

	select id into _id
	from  domesa.estado
	where app.unaccent(app.upper(nombre)) = app.unaccent($1);

	if not found then
		insert into domesa.estado (nombre) values( app.initcap($1) ) returning id into _id;
	else
		update domesa.estado set nombre = app.initcap($1) where id = _id;
	end if;

	return query select * from domesa.estado where id = _id;
END;
$$ language plpgsql;


-------------------------------------------------------------
--- sync domesa_status_guia :

create or replace function domesa.sync_status_guia(text default null) returns setof domesa.status_guia as
$$
declare
	_id bigint;
BEGIN
	if($1 is null) then
		return;
	end if;

	$1 := app.upper($1);

	select id into _id
	from  domesa.status_guia
	where app.unaccent(app.upper(nombre)) = app.unaccent($1);

	if not found then
		insert into domesa.status_guia (nombre) values( app.initcap($1) ) returning id into _id;
	else
		update domesa.status_guia set nombre = app.initcap($1) where id = _id;
	end if;

	return query select * from domesa.status_guia where id = _id;
END;
$$ language plpgsql;

















