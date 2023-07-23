
# Mirando Más Allá de la Caja: Herramientas Adaptativas en PostgreSQL

En ocasiones en el desarrollo de software nos enfrentamos con diversos desafíos que requieren soluciones creativas. Podemos tropezar con limitaciones en el lenguaje o las herramientas que utilizamos, cosa que nos obliga a pensar fuera de la caja para encontrar soluciones innovadoras.

Cuando me refiero a **"pensar fuera de la caja"** tomo como bandera que las herramientas que integremos deben adaptarse y servir a nuestros propósitos, lógica de negocios y necesidades, en lugar de forzarnos a ajustarnos a propósitos externos. A veces, nos encontramos con productos y soluciones preconstruidas que nos obligan a adaptar nuestros requerimientos a una funcionalidad  **"externa"** para poder utilizar dicha herramienta, lo que desvía el enfoque de lo que realmente necesitamos.

En ciertas ocasiones, el uso de un framework o producto puede requerir una reestructura de nuestra lógica de negocio para hacer posible su implementación, y es en estos momentos cuando mirar desde otro enfoque puede ser la manera efectiva de abordar el problema.

Un ejemplo claro de la flexibilidad a la quiero llegar es el uso de **postgreSQL**, con SQL estándar logramos interactuar con las bases de datos, con postgreSQL obtenemos no solo una herramienta para manejar bases de datos, podríamos decir que obtenemos una suite completa para programar y adaptar cualquier necesidad sin perder el foco en  **"esos males"** que implican la adopción de una tecnología extra. (el no poder usar booleanos nativos dentro mysql es una limitación que describe muy bien a lo que me refiero)

## Hagamos un ejemplo descabellado

Supongamos que queremos implementar el uso del operador de negación  **"!"** dentro de una sentencia SQL,
El operador de negación es una de las herramientas más útiles que utilizamos en otros lenguajes de programación y utilizarlo dentro de SQL sería **"natural"** para nosotros, pero ese operador no está definido dentro del SQL estándar.

Si mi enfoque del mundo fuera solo el de mirar dentro de la caja, respondería que es imposible adoptar esa funcionalidad dentro del SGBD. Cosa que es cierta si tu herramienta es mysql, pero vuelvo a recalcar que nuestras herramientas deben adaptarse a nuestras necesidades y no al revés.

## **La solución:**
Crear un operador de negación personalizado:

En **PostgreSQL**, tenemos la capacidad de crear funciones personalizadas y, lo que es más emocionante, también podemos crear operadores personalizados basados en esas funciones, utilizando este enfoque, podemos simular el comportamiento del operador de negación **"!"** que tanto amamos.

***

#### Paso 1:

A continuación, vamos a declarar una función llamada **"negator"**, que recibe un valor booleano y devuelve su negación utilizando el bello postulado del tercero excluido, en otras palabras cualquier valor nulo pasa a false y así tendremos dos valores posibles, true o false (cosa que simula la conversión booleana de un valor de javascript por ejemplo)


```sql

CREATE OR REPLACE FUNCTION public.negator (INOUT boolean default null) AS
$$
BEGIN
    SELECT
        CASE
            WHEN $1 IS NULL THEN FALSE
            WHEN $1 =  TRUE THEN FALSE
            ELSE TRUE
        END
    INTO $1;
END;
$$
LANGUAGE plpgsql;

```

Es evidente lo simple que es la función, pero postgres es una suite completa! asi que podría simplificar aún más el código a una sola línea de esta manera:

```sql

CREATE OR REPLACE FUNCTION public.negator (INOUT boolean default null) AS
$$
BEGIN
    SELECT COALESCE(NOT($1), false) into $1;
END;
$$
LANGUAGE plpgsql;

```

***

#### Paso 2:
Una vez creada la función de negación, para utilizarla podríamos hacer algo como:

```sql
select
	 negator()               -- obtenemos un false
	,negator(null::boolean)  -- obtenemos un false
	,negator(true)           -- obtenemos un false
	,negator(false)          -- obtenemos un true

```

Aunque dista mucho de nuestro propósito de poder usar el operador **"!"** directamente,
en este punto me gustaría poder utilizar el operador de negación de esta manera:

```sql
select
	!true,
	!false;


```
O en una actualización hacer la negación:  (alguen al azar se va quedar con el status cambiado :))
```sql
update users as u set status = !u.status from (
	select * from users order by random() limit 1
) as u2
where u2.id = u.id returning u.*

```
***

#### Paso 3:

Para poder agregar esta funcionalidad necesitamos comprender que postgres puede crear operadores.

Si en este momento intentamos usar el operador de negación , obtendremos un error explicandonos que no existe el operador  **!** para un tipo de dato **booleano**:

*"No operator matches the given name and argument type. You might need to add an explicit type cast."*

creamos el operador con el siguiente código SQL:

```sql
CREATE OPERATOR public.! (
    RIGHTARG = bool,
    FUNCTION = public.negator, -- el operador utiliza la función de nagación
    NEGATOR = !<>
);
```

El uso del api de operadores es amplio, si te parece interesante puedes darte una vuelta por el manual oficial e intentar de comprender (es un tema algo difícil de digerir y con documentación reducida)
*   https://www.postgresql.org/docs/15/sql-createoperator.html
*   https://www.postgresql.org/docs/15/sql-createopclass.html


Con el operador generado ya podemos utilizar nuestra negación dentro de SQL y nuestro gestor sabrá que hacer cuando vea !(NEGATOR) y un boolean (RIGHTARG) en una sentencia SQL.

***
#### Paso 4 una pequeña prueba:
Vamos a genenrar una tabla para pruebas con la siguiente extructura

```sql
create table test (
	id serial not null,
	name varchar(255) not null,
	status boolean default false,
	primary key(id)
);
```

luego generamos el insert para 10000 registros de un **"tajo"**

```sql
insert into test(name, status)
	select format('name - %s', g),
	(
		case
			when g%3=0 then null  -- multiplos de 3 nulos
			when g%2=0 then true  -- multipos  de 2 true
		else false end            -- lo que queda false
	)
	from generate_series(1, 10000) as g; --  1000 registros
);
```

Y por ultimo podriamos usar un **update test set status=!status** directamente en una consulta de actualización, pero es **una pequeña prueba**, yo quiero que me devuelva los status de los registros antes y despues del cambio, podemos lograr esto muy facilmente usando el siguiente SQL:

```sql
update test as t set status = !t.status from (
 	select * from test
) as t2
where t2.id = t.* , t2.status as old_status;
```

## En conclusión:

En este artículo, hemos explorado una técnica poco convencional para crear un operador de negación personalizado en SQL utilizando PostgreSQL. Aunque esta solución puede ser discutible desde una perspectiva de buenas prácticas, nos ha permitido desafiarnos y pensar creativamente (o lo que llamaría **"mirar fuera de la caja"**) para resolver un problema específico.

Es importante recordar que en nuestra profesión, la flexibilidad y el conocimiento de nuestras herramientas nos proporcionan un poder invaluable para abordar desafíos de manera innovadora. Siempre debemos equilibrar la flexibilidad con las mejores prácticas y la legibilidad del código, pero por sobre todo nunca debemos dejarnos llevar a la deriva por nuestras herramientas.

Gracias por leer hasta aqui! Si tienes comentarios o preguntas, no dudes en compartirlos.




