
-- https://github.com/bcamandone/Data_Analysis_SQL/tree/main/Empresa_Pink_DesafioSQL

WITH v AS (
	select
		  (select count(qty)  as "R1" from ventas)
		, (select round(sum(qty * precio), 2) as "R2"  from ventas)
		, (select round(avg(r.t), 2) as "R3" from ( select (qty * precio) as t  from ventas) r)
		, (
			select jsonb_agg(r) as "R4" from (
				select
				pd.nombre_producto,
				round(sum(v.qty * v.precio), 2) as ingreso
				from ventas as v
				inner join producto_detalle as pd on pd.id_producto = v.id_producto
				group by v.id_producto, pd.nombre_producto order by ingreso desc
			) as r
		)
		,( select sum(descuento) from ventas) as descuento_total
		,(select jsonb_agg(r) as "R6" from (
			select
			  round((sum(v.descuento) * 100)  / (sum(v.qty * v.precio)::numeric) , 2) as descuento
			 ,pd.nombre_producto
			from ventas as v
			inner join producto_detalle as pd on pd.id_producto = v.id_producto
			group by v.id_producto, pd.nombre_producto
			order by descuento desc
		) as r)
		,( select count(*) from ( select  count(*) from ventas group by id_txn) as r where r.count = 1) as "R7"
		,(select jsonb_agg(r) as "R8" from (
			select  v.id_txn, round( sum(v.qty * v.precio) , 2)  as brutos from ventas as v group by id_txn order by brutos desc
		) as r)
		,(select jsonb_agg(r) as "R9" from (
			select v.id_txn, sum(v.qty) as nro_qty from ventas as v group by v.id_txn
			order by nro_qty desc
		) as r)
		,(
			select jsonb_agg(r) as "R10" from (
				with cte as (
					select v.id_txn,  round((sum(v.descuento) * 100)  / (sum(v.qty * v.precio)::numeric) , 2) as descuento
					from ventas as v
					group by v.id_txn
				)

				select id_txn, round(avg(descuento) , 2) as avg_desc_venta from cte -- solucion si quiere solo el avg sin calculos
				group by id_txn
				order by avg_desc_venta desc
			) as r
		)
		,(
			select jsonb_agg(r) as "R11" from (
				select
				    id_txn
				   ,round(avg((qty * precio) - descuento), 2) avg_precio_neto
				from ventas as v
				where  miembro='t'
				group by id_txn
				order by avg_precio_neto desc
			) as r
		)
		, (

			select jsonb_agg(r) as "R12" from (
				select distinct pd.nombre_producto, round(sum(v.qty * v.precio), 2) as ingresos_totales
				from ventas as v
				inner join producto_detalle as pd on pd.id_producto = v.id_producto
				group by pd.nombre_producto
				order by ingresos_totales desc limit 3
			) as r
		),

		(
			--- hahaha pense que segmento era una compra no un atributo de producto_detalle
			select to_jsonb(array_agg(r)) as "R13" from (

				with cte as(	select
						v2.id_txn
						,(
						select jsonb_agg(r) as segmentos from (
							select
							v.id_producto
							,pd.nombre_producto
							,sum(v.qty)
							,round(sum(v.descuento) , 2)        as descuento
							,round( sum(v.qty * v.precio) , 2)  as ingresos_brutos
							from ventas as v
							inner join producto_detalle as pd on pd.id_producto = v.id_producto
							where v.id_txn = v2.id_txn
							group by v.id_producto, pd.nombre_producto
						)as r)

					from ventas as v2
					group by v2.id_txn
				)
				select id_txn, cte.segmentos from cte
			) as r
		)
)
-- jsonb_pretty para que se vea en consola :)
SELECT
	 v."R1"
	,v."R2"
	,v."R3"
	,jsonb_pretty(v."R4") as "R4"
	,round(((descuento_total * 100) / v."R2"), 2) as "R5"
	,jsonb_pretty(v."R6") as "R6"
	,v."R7"
	,jsonb_pretty(v."R8") as "R8"
	,jsonb_pretty(v."R9") as "R9"
	,jsonb_pretty(v."R10") as "R10"
	,jsonb_pretty(v."R11") as "R11"
	,jsonb_pretty(v."R12") as "R12"
	,jsonb_pretty(v."R13") as "R13"
FROM v;


