



create or replace function domesa.jsonb_to_vguia(JSONB default null) RETURNS setof domesa.guia as
$$
declare
	_requiredAttributes TEXT[] := '{
		 id
		,id_tipo_envio
		,id_forma_pago
		,id_operador
		,tipo_servicio
		,tipo_embalaje
		,status
		,nro_guia
		,peso
		,domesa_monto
		,domesa_costo_servicio
		,conciliacion
		,comision_porcentual
		,recarga_x_embalaje
		,tipo_traslado
		,mercadolibre
		,rastreo
		,fecha_registro
	}';
BEGIN
	-- debug si es nulo el parametro de entrada (estoy en debug) analizo este json si es el mismo tomara el ultimo de los iguales por id
	-- pero la exclucion se hace al final en el row_number por si falla alguna validacion que no sea la duplicidad
	$1 = coalesce(
		$1
		,'[
			{"id": 119122158, "peso": 5.63, "status": "Entregado", "rastreo": [{"id": 275333088, "tipo": "DESPACHADO HACIA EL DESTINO", "ciudad": "Caracas", "oficina": "0385 - AA - BRISAR EXPRESS, C.A.", "fegestion": "03/05/2024 4:17PM", "descripcion": "Encomienda en transito"}, {"id": 275322417, "tipo": "DESPACHADO HACIA EL DESTINO", "ciudad": "Caracas", "oficina": "0385 - AA - BRISAR EXPRESS, C.A.", "fegestion": "02/05/2024 3:15PM", "descripcion": "Encomienda en transito"}], "nro_guia": 503850006335, "id_operador": 3, "conciliacion": 0, "domesa_monto": "660,15", "mercadolibre": 0, "id_forma_pago": 1, "id_tipo_envio": 1, "tipo_embalaje": "SIN ENVASE DOMESA", "tipo_servicio": "Contado", "tipo_traslado": "SALIDA", "fecha_registro": "02/05/2024 11:59 AM", "recarga_x_embalaje": 0, "comision_porcentual": 0, "domesa_costo_servicio": 532.38},
			{"id": 119122158, "peso": 5.63, "status": "Entregado", "rastreo": [{"id": 275333088, "tipo": "DESPACHADO HACIA EL DESTINO", "ciudad": "Caracas", "oficina": "0385 - AA - BRISAR EXPRESS, C.A.", "fegestion": "03/05/2024 4:17PM", "descripcion": "Encomienda en transito"}, {"id": 275322417, "tipo": "DESPACHADO HACIA EL DESTINO", "ciudad": "Caracas", "oficina": "0385 - AA - BRISAR EXPRESS, C.A.", "fegestion": "02/05/2024 3:15PM", "descripcion": "Encomienda en transito"}], "nro_guia": 503850006335, "id_operador": 3, "conciliacion": 0, "domesa_monto": "660,15", "mercadolibre": 0, "id_forma_pago": 1, "id_tipo_envio": 1, "tipo_embalaje": "SIN ENVASE DOMESA", "tipo_servicio": "Contado", "tipo_traslado": "SALIDA", "fecha_registro": "02/05/2024 11:59 AM", "recarga_x_embalaje": 0, "comision_porcentual": 0, "domesa_costo_servicio": 532.38}
		]'
	);


	$1 := app.jsonb_to_array_objects($1);
	if ($1 is null or $1='[]')
		then return;
	end if;

	return query with cte as (
		select
			 app.safe_cast(item->>'id'            , null::bigint)                       as id
			,app.safe_cast(item->>'id_tipo_envio' , null::bigint)                       as id_tipo_envio
			,app.safe_cast(item->>'id_forma_pago' , null::bigint)                       as id_forma_pago
			,app.safe_cast(item->>'id_operador'   , null::bigint)                       as id_operador
			-- estos pasaran a fk
			,app.upper(item->>'tipo_servicio')::varchar(100)                            as tipo_servicio
			,app.initcap(item->>'tipo_embalaje')::varchar(100)                          as tipo_embalaje
			,app.initcap(item->>'status')::varchar(100)                                 as status
			--
			,app.safe_cast(item->>'nro_guia', null::bigint)                             as nro_guia
			,app.safe_cast(item->>'peso', 0::numeric)::numeric(14,6)                    as peso
			,app.cast_currency_ve(item->>'domesa_monto',3)::numeric(14,3)               as domesa_monto
			,app.safe_cast(item->>'domesa_costo_servicio' , 0::numeric)::numeric(14,3)  as domesa_costo_servicio
			,app.safe_cast(item->>'conciliacion'          , 0::numeric)::numeric(14,3)  as conciliacion
			,app.safe_cast(item->>'comision_porcentual'   , 0::numeric)::numeric(14,3)  as comision_porcentual
			,app.safe_cast(item->>'recarga_x_embalaje'    , 0::numeric)::numeric(14,3)  as recarga_x_embalaje
			,app.upper(item->>'tipo_traslado')::varchar(20)                             as tipo_traslado
			,coalesce(app.safe_cast(item->>'mercadolibre', false::boolean), false)      as mercadolibre
			,coalesce(app.safe_cast(item->>'rastreo', null::jsonb), '[]')               as rastreo
			,app.safe_cast(item->>'fecha_registro',null::timestamp without time zone)   as fecha_registro
			from (
				SELECT el FROM jsonb_array_elements($1) AS el
				where  el ?& _requiredAttributes -- (operator ?&) https://www.postgresql.org/docs/9.5/functions-json.html
			)r(item)
	),
	cte2 as (
		select cte.*
			,row_number() over(partition by cte.id order by cte.id desc) as sort
			,row_number() over() as nro_row

		from cte
			inner  join domesa.bx_tipo_envio as te on te.id  = cte.id_tipo_envio
			inner  join domesa.bx_forma_pago as fp on fp.id  = cte.id_forma_pago
			inner  join domesa.operador      as op on op.id  = cte.id_operador

		where true
			and   cte.id                    >  0
			and   cte.id_tipo_envio         >  0
			and   cte.id_forma_pago         >  0
			and   length(cte.tipo_servicio) >  1
			and   length(cte.tipo_embalaje) >  1
			and   cte.nro_guia              >  0
			and   cte.peso                  >  0
			and   cte.domesa_monto          >  0
			and   cte.domesa_costo_servicio >  0
			and   cte.conciliacion          >= 0
			and   cte.comision_porcentual   >= 0
			and   cte.recarga_x_embalaje    >= 0
			and   cte.tipo_traslado         in ('ENTRADA', 'SALIDA')
			and   cte.fecha_registro        is not null
			and   cte.mercadolibre          is not null
			and   length(cte.status)   > 1
	),
	cte3 as (
		select
		 cte2.id
		,cte2.id_tipo_envio
		,cte2.id_forma_pago
		,cte2.id_operador
		--
		,(domesa.sync_tipo_servicio(cte2.tipo_servicio)).id  as id_tipo_servicio
		,(domesa.sync_tipo_embalaje(cte2.tipo_embalaje)).id  as id_tipo_embalaje
		,(domesa.sync_status_guia(cte2.status)).id           as id_status_guia
		--
		,cte2.nro_guia
		,cte2.peso
		,cte2.domesa_monto
		,cte2.domesa_costo_servicio
		,cte2.conciliacion
		,cte2.comision_porcentual
		,cte2.recarga_x_embalaje
		,cte2.tipo_traslado
		,cte2.mercadolibre
		,app.jsonb_to_array_objects(cte2.rastreo)    as rastreo
		,(app.unixtime(cte2.fecha_registro) + 14400) as fecha_registro
		,(app.unixtime())                            as fecha_actualizacion
		from cte2
	)

	select * from cte3 where true
	and not cte3.id_tipo_servicio is null
	and not cte3.id_tipo_embalaje is null
	and not cte3.id_status_guia   is null;
END;
$$ LANGUAGE PLPGSQL;

insert into domesa.guia
select * from domesa.jsonb_to_vguia() returning *
