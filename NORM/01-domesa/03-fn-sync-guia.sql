CREATE OR REPLACE FUNCTION domesa.jsonb_to_vguia(JSONB default null) RETURNS TABLE(
	 id                    bigint
	,id_tipo_envio         bigint
	,id_forma_pago         bigint
	,id_operador           bigint
	,id_tipo_servicio      bigint
	,id_tipo_embalaje      bigint
	,id_status_guia        bigint
	,nro_guia              bigint
	,peso                  numeric(14,6)
	,domesa_monto          numeric(14,3)
	,domesa_costo_servicio numeric(14,3)
	,conciliacion          numeric(14,3)
	,comision_porcentual   numeric(14,3)
	,recarga_x_embalaje    numeric(14,3)
	,tipo_traslado         varchar(20)
	,mercadolibre          boolean
	,fecha_registro        bigint
) AS
$$
declare
	_requiredElements TEXT[] := '{id , nro_guia}';
BEGIN
	--tmp test hardcode
	--$1 := coalesce ( $1 ,'[{"id": 119288206, "peso": 0.02, "status": "Remesado Por Ofc. Origen", "nro_guia": 503850006812, "operador": "0385Operador20005", "conciliacion": 0, "domesa_monto": "153,280", "mercadolibre": false, "id_forma_pago": 1, "id_tipo_envio": 1, "tipo_embalaje": "Sin Envase Domesa", "tipo_servicio": "COD", "tipo_traslado": "SALIDA", "fecha_registro": "2024-10-10T15:55:00", "recarga_x_embalaje": 0, "comision_porcentual": 0, "domesa_costo_servicio": 123.61}, {"id": 119288299, "peso": 0.05, "status": "Remesado Por Ofc. Origen", "nro_guia": 503850006813, "operador": "0385Operador20005", "conciliacion": 0, "domesa_monto": "18,280", "mercadolibre": false, "id_forma_pago": 1, "id_tipo_envio": 1, "tipo_embalaje": "Sin Envase Domesa", "tipo_servicio": "COD", "tipo_traslado": "SALIDA", "fecha_registro": "2024-10-10T16:26:00", "recarga_x_embalaje": 0, "comision_porcentual": 0, "domesa_costo_servicio": 123.61}, {"id": 119288905, "peso": 0.07, "status": "En Oficina Origen", "nro_guia": 503850006814, "operador": "0385Operador20005", "conciliacion": 0, "domesa_monto": "183,930", "mercadolibre": false, "id_forma_pago": 1, "id_tipo_envio": 1, "tipo_embalaje": "Sin Envase Domesa", "tipo_servicio": "COD", "tipo_traslado": "SALIDA", "fecha_registro": "2024-10-11T11:54:00", "recarga_x_embalaje": 0, "comision_porcentual": 0, "domesa_costo_servicio": 123.61}]');

	if $1 is null then return; end if;

	return query with g as (
		with cte as  (
			select
				 app.safe_cast(item->>'id'            , null::bigint)                       as id
				,app.safe_cast(item->>'id_tipo_envio' , null::bigint)                       as id_tipo_envio
				,app.safe_cast(item->>'id_forma_pago' , null::bigint)                       as id_forma_pago
				,app.trim(item->>'operador')::varchar(100)                                  as operador
				--
				,app.upper(item->>'tipo_servicio')::varchar(100)                            as tipo_servicio
				,app.initcap(item->>'tipo_embalaje')::varchar(100)                          as tipo_embalaje
				,app.initcap(item->>'status')::varchar(100)                                 as status_guia
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
				,app.safe_cast(item->>'fecha_registro',null::timestamp without time zone)   as fecha_registro
				,row_number() over()                                                        as sort_by
			from (
				SELECT el FROM jsonb_array_elements(app.jsonb_to_array_objects($1) ) AS el
				where  el ?& _requiredElements
			)r(item)
		)
		select
			 cte.*
			,op.id as id_operador
			,row_number() over( partition by cte.id order by cte.sort_by desc) as row_number
		from cte
		inner join domesa.tipo_envio as te on te.id       = cte.id_tipo_envio
		inner join domesa.forma_pago as fp on fp.id       = cte.id_forma_pago
		inner join domesa.operador   as op on op.username = cte.operador

		where cte.id                    >  0
		and   cte.id_tipo_envio         >  0
		and   cte.id_forma_pago         >  0
		and   length(cte.operador)      >  5
		and   length(cte.tipo_servicio) >  1
		and   length(cte.tipo_embalaje) >  1
		and   cte.nro_guia              >  0
		and   cte.peso                  >  0
		and   cte.domesa_monto          >  0
		and   cte.domesa_costo_servicio >  0
		and   cte.conciliacion          >= 0
		and   cte.comision_porcentual   >= 0
		and   cte.recarga_x_embalaje    >= 0
		and   cte.tipo_traslado         in ('ENTRADA' , 'SALIDA')
		and   cte.fecha_registro        is not null
		and   cte.mercadolibre          is not null
		and   length(cte.status_guia)   > 1
	)
	select
		 g.id
		,g.id_tipo_envio
		,g.id_forma_pago
		,g.id_operador
		--
		,(domesa.sync_servicio(g.tipo_servicio)).id  as id_tipo_servicio
		,(domesa.sync_embalaje(g.tipo_embalaje)).id  as id_tipo_embalaje
		,(domesa.sync_status_guia(g.status_guia)).id as id_status_guia
		,g.nro_guia
		,g.peso
		,g.domesa_monto
		,g.domesa_costo_servicio
		,g.conciliacion
		,g.comision_porcentual
		,g.recarga_x_embalaje
		,g.tipo_traslado
		,g.mercadolibre
		,(app.unixtime(g.fecha_registro) + 14400) as fecha_registro
		from g
		where g.row_number = 1
		order by sort_by asc
	;
END;
$$ LANGUAGE PLPGSQL;


CREATE OR REPLACE FUNCTION domesa.sync_guia(JSONB default null) RETURNS SETOF domesa.guia
AS
$$
declare
	_created bigint[];
BEGIN

	if $1 is null then return; end if;

	-- TODO sync from update!
	-- delete if exists:
	delete from domesa.guia where id in (
		select g.id from domesa.jsonb_to_vguia( $1 ) as j
		inner join domesa.guia as g on (g.id = j.id or g.nro_guia = j.nro_guia)
	);

	WITH for_insert AS (
		INSERT INTO domesa.guia (
			id,
			id_tipo_envio,
			id_forma_pago,
			id_operador,
			id_tipo_servicio,
			id_tipo_embalaje,
			id_status_guia,
			nro_guia,
			peso,
			domesa_monto,
			domesa_costo_servicio,
			conciliacion,
			comision_porcentual,
			recarga_x_embalaje,
			tipo_traslado,
			mercadolibre,
			fecha_registro,
			fecha_actualizacion
		)
		SELECT cte.* ,app.unixtime() AS fecha_actualizacion
		FROM domesa.jsonb_to_vguia($1) AS cte
		ON CONFLICT (id) DO NOTHING
		RETURNING id
	) select array_agg(id) into _created from for_insert;

	-- TODO add nofity sync guias
	-- raise notice 'guias %', _created

	RETURN QUERY select * from domesa.guia where ARRAY[id] <@ _created;
END;
$$ language plpgsql;

-- test:

select * from domesa.sync_guia('[
    {
		"id":119288905,
		"peso":0.07,
		"status":"En Oficina Origen",
		"nro_guia":503850006814,
		"operador":"0385Operador20005",
		"conciliacion":0,
		"domesa_monto":"183,930",
		"mercadolibre":false,
		"id_forma_pago":1,
		"id_tipo_envio":1,
		"tipo_embalaje":"Sin Envase Domesa",
		"tipo_servicio":"COD",
		"tipo_traslado":"SALIDA",
		"fecha_registro":"2024-10-11T11:54:00",
		"recarga_x_embalaje":0,
		"comision_porcentual":0,
		"domesa_costo_servicio":123.61
    },
	{
		"id":119288905,
		"peso":0.07,
		"status":"En Oficina Origen",
		"nro_guia":503850006814,
		"operador":"0385Operador20005",
		"conciliacion":0,
		"domesa_monto":"183,930",
		"mercadolibre":false,
		"id_forma_pago":1,
		"id_tipo_envio":1,
		"tipo_embalaje":"Sin Envase Domesa",
		"tipo_servicio":"COD",
		"tipo_traslado":"SALIDA",
		"fecha_registro":"2024-10-11T11:54:00",
		"recarga_x_embalaje":0,
		"comision_porcentual":0,
		"domesa_costo_servicio":123.61
	},
	{
		"id":119288905,
		"peso":0.07,
		"status":"En Oficina Origen",
		"nro_guia":503850006814,
		"operador":"0385Operador20005",
		"conciliacion":0,
		"domesa_monto":"183,930",
		"mercadolibre":false,
		"id_forma_pago":1,
		"id_tipo_envio":1,
		"tipo_embalaje":"Sin Envase Domesa",
		"tipo_servicio":"COD",
		"tipo_traslado":"SALIDA",
		"fecha_registro":"2024-10-11T11:54:00",
		"recarga_x_embalaje":0,
		"comision_porcentual":0,
		"domesa_costo_servicio":123.61
	},
    {
		"id":119288905,
		"peso":0.07,
		"status":"En Oficina Origen",
		"nro_guia":503850006814,
		"operador":"0385Operador20005",
		"conciliacion":0,
		"domesa_monto":"183,930",
		"mercadolibre":false,
		"id_forma_pago":1,
		"id_tipo_envio":1,
		"tipo_embalaje":"Sin Envase Domesa",
		"tipo_servicio":"COD",
		"tipo_traslado":"SALIDA",
		"fecha_registro":"2024-10-11T11:54:00",
		"recarga_x_embalaje":0,
		"comision_porcentual":0,
		"domesa_costo_servicio":123.61
    },
    {
		"id":55555,
		"peso":0.02,
		"status":"Remesado Por Ofc. Origen",
		"nro_guia":55555,
		"operador":"0385Operador20005",
		"conciliacion":20,
		"domesa_monto":"153,280",
		"mercadolibre":false,
		"id_forma_pago":1,
		"id_tipo_envio":2,
		"tipo_embalaje":"Sin Envase Domesa",
		"tipo_servicio":"COD-uno",
		"tipo_traslado":"SALIDA",
		"fecha_registro":"2024-10-10T15:55:00",
		"recarga_x_embalaje":0,
		"comision_porcentual":0,
		"domesa_costo_servicio":123.61
    }
]');
