-- conversion explicita:  unixtime(current_timestamp  AT TIME ZONE 'UTC' )

CREATE OR REPLACE function "app".unixtime( _date timestamp without time zone default null) RETURNS bigint AS
$$
BEGIN

	IF(_date is null) THEN
		_date =  current_timestamp AT TIME ZONE 'UTC';
	END IF;

	return extract(epoch from _date)::bigint;
END;
$$ language plpgsql;


--	https://www.postgresqltutorial.com/postgresql-date-functions/postgresql-to_timestamp/
--
--	Pattern	Description
--	Y,YYY	year in 4 digits with comma
--	YYYY	year in 4 digits
--	YYY	last 3 digits of year
--	YY	last 2 digits of year
--	Y	The last digit of year
--	IYYY	ISO 8601 week-numbering year (4 or more digits)
--	IYY	Last 3 digits of ISO 8601 week-numbering year
--	IY	Last 2 digits of ISO 8601 week-numbering year
--	I	Last digit of ISO 8601 week-numbering year
--	BC, bc, AD or ad	Era indicator without periods
--	B.C., b.c., A.D. ora.d.	Era indicator with periods
--	MONTH	English month name in uppercase
--	Month	Full capitalized English month name
--	month	Full lowercase English month name
--	MON	Abbreviated uppercase month name e.g., JAN, FEB, etc.
--	Mon	Abbreviated capitalized month name e.g, Jan, Feb,  etc.
--	mon	Abbreviated lowercase month name e.g., jan, feb, etc.
--	MM	month number from 01 to 12
--	DAY	Full uppercase day name
--	Day	Full capitalized day name
--	day	Full lowercase day name
--	DY	Abbreviated uppercase day name
--	Dy	Abbreviated capitalized day name
--	dy	Abbreviated lowercase day name
--	DDD	Day of year (001-366)
--	IDDD	Day of ISO 8601 week-numbering year (001-371; day 1 of the year is Monday of the first ISO week)
--	DD	Day of month (01-31)
--	D	Day of the week, Sunday (1) to Saturday (7)
--	ID	ISO 8601 day of the week, Monday (1) to Sunday (7)
--	W	Week of month (1-5) (the first week starts on the first day of the month)
--	WW	Week number of year (1-53) (the first week starts on the first day of the year)
--	IW	Week number of ISO 8601 week-numbering year (01-53; the first Thursday of the year is in week 1)
--	CC	Century e.g, 21, 22, etc.
--	J	Julian Day (integer days since November 24, 4714 BC at midnight UTC)
--	RM	Month in upper case Roman numerals (I-XII; >
--	rm	Month in lowercase Roman numerals (i-xii; >
--	HH	Hour of day (0-12)
--	HH12	Hour of day (0-12)
--	HH24	Hour of day (0-23)
--	MI	Minute (0-59)
--	SS	Second (0-59)
--	MS	Millisecond (000-9999)
--	US	Microsecond (000000-999999)
--	SSSS	Seconds past midnight (0-86399)
--	AM, am, PM or pm	Meridiem indicator (without periods)
--	A.M., a.m., P.M. or p.m.	Meridiem indicator (with periods)
--
--	ejemplo de fecha y hora :
--	select _unixtime_format(_unixtime(), 'dd/mm/yyyy HH12:MI AM')

CREATE OR REPLACE FUNCTION "app".unixtime_format(
	_unixtime bigint ,
	_format TEXT default null,
	_timeZone text default null ) returns text as
$$
BEGIN

	_timezone := COALESCE(_timeZone , 'America/Caracas');
	_format   := COALESCE(_format   , 'dd/mm/yyyy');

	IF(_unixtime is null) THEN
		return null;
	END IF;

	return TO_CHAR (timezone(_timeZone ,to_timestamp(_unixtime)), _format);
END
$$ language plpgsql;

CREATE OR REPLACE FUNCTION "app".moment(bigint default null, text default null) RETURNS "app".type_moment AS
$$
DECLARE
	_rc "app".type_moment;
	_dateTimeFormat TEXT := 'dd/mm/yyyy HH12:MI a.m.';
	_dateFormat     TEXT := 'dd/mm/yyyy';
	_timeFormat     TEXT := 'HH12:MI a.m.';
	_timeZone       TEXT := 'America/Caracas';

BEGIN

	$1 = COALESCE($1, "app".unixtime());

	IF($2 is null) THEN $2 = _timeZone;  END IF;

	with t as (
		select
			$2 as timezone_name
			,(to_timestamp($1) AT TIME ZONE $2) as now
			,$1 as unixtime
			,(to_timestamp($1) AT TIME ZONE 'UTC') as utc_time
	)
	select
		 timezone_name
		,DATE_TRUNC('second', t.now::timestamp)                                        AS timestamp
		, (t.now::timestamptz(0)::date)                                                AS date
		, (t.now::timestamptz(0)::time)                                                AS time
		, TO_CHAR(timezone(t.timezone_name ,to_timestamp(unixtime)), _dateTimeFormat)  AS timestamp_format
		, TO_CHAR(timezone(t.timezone_name ,to_timestamp(unixtime)), _dateFormat)      AS date_format
		, TO_CHAR(timezone(t.timezone_name ,to_timestamp(unixtime)), _timeFormat)      AS time_format
		, extract(day    FROM t.now)::smallint                                         AS day
		, extract(month  FROM t.now)::smallint                                         AS month
		, extract(year   FROM t.now)::smallint                                         AS year
		, extract(hour   FROM t.now)::smallint                                         AS hour
		, extract(minute FROM t.now)::smallint                                         AS minute
		, extract(second FROM t.now)::smallint                                         AS second
		, unixtime                                                                     AS unixtime
		, "app".unixtime(t.now)                                                          AS microtime
		, extract(epoch FROM (now - utc_time))::bigint                                 AS microtime_diff
		, now - utc_time                                                               AS utc_time
		into _rc
	from t;
	return _rc;
END;
$$ language plpgsql;

/*
CREATE OR REPLACE function "app".moment_required(bigint, text default null)  RETURNS "app".type_moment AS
$$
BEGIN
	IF($1 is null) then
		return null;
	end if;

	return "app".moment($1, $2);
END;
$$ language plpgsql;
*/
-------------------------------------------------------------
--- operadores :

CREATE or replace function "app".moment_is_eq("app".type_moment, "app".type_moment) returns boolean as
$$
BEGIN
	return $1.unixtime =$2.unixtime;
END;
$$ language plpgsql;

CREATE or replace function "app".moment_is_less("app".type_moment, "app".type_moment) returns boolean as
$$
BEGIN

	IF($1 is null and $2 is null) THEN
		return false;
	END if;

	IF($1 is null) THEN
		return false;
	END IF;

	IF($2 is null) THEN
		return true;
	END IF;

	return $1.unixtime < $2.unixtime;
END;
$$ language plpgsql;

CREATE or replace function "app".moment_is_more("app".type_moment, "app".type_moment) returns boolean as
$$
BEGIN

	IF($1 is null and $2 is null) THEN
		return false;
	END if;

	IF($1 is null) THEN
		return false;
	END IF;

	IF($2 is null) THEN
		return true;
	END IF;

	return $1.unixtime > $2.unixtime;
END;
$$ language plpgsql;

CREATE or replace function "app".moment_is_less_or_eq("app".type_moment, "app".type_moment) returns boolean as
$$
BEGIN
	IF(  "app".moment_is_eq($1, $2) or  "app".moment_is_less($1, $2) ) THEN
		return true;
	ELSE
		return false;
	END IF;
END;
$$ language plpgsql;

CREATE or replace function "app".moment_is_more_or_eq("app".type_moment, "app".type_moment) returns boolean as
$$
BEGIN
	IF( "app".moment_is_eq($1, $2) or "app".moment_is_more($1, $2) ) THEN
		return true;
	ELSE
		return false;
	END IF;
END;
$$ language plpgsql;

CREATE OPERATOR "app".= (
	leftarg    = "app".type_moment,
	rightarg   = "app".type_moment,
	procedure  = "app".moment_is_eq,
	commutator = =
);

CREATE OPERATOR "app".< (
	leftarg    = "app".type_moment,
	rightarg   = "app".type_moment,
	procedure  = "app".moment_is_less,
	commutator = <
);

CREATE OPERATOR "app".> (
	leftarg    = "app".type_moment,
	rightarg   = "app".type_moment,
	procedure  = "app".moment_is_more,
	commutator = >
);

CREATE OPERATOR "app".<= (
	leftarg    = "app".type_moment,
	rightarg   = "app".type_moment,
	procedure  = "app".moment_is_less_or_eq,
	commutator = <=
);

CREATE OPERATOR "app".>= (
	leftarg    = "app".type_moment,
	rightarg   = "app".type_moment,
	procedure  = "app".moment_is_more_or_eq,
	commutator = >=
);

-- converte unixtime a timestamp
CREATE OR REPLACE FUNCTION "app".from_unixtime(bigint default null,  _tz text default null) RETURNS timestamp AS
$$
DECLARE
	_output   timestamp;
BEGIN
	if($1 is null) then
		return null;
	end if;

	return ("app".moment($1, _tz)).timestamp;
END;
$$ language plpgsql;

create or replace function "app".difftime(bigint default null, bigint default null, _tz text default null ) returns jsonb as
$$
DECLARE
	_tInf         timestamp;
	_tSup         timestamp;

	-- parts time:
	_years          int     := 0;
	_totalDays      int     := 0;
	_months         int     := 0;
	_days           int     := 0;
	_hours          int     := 0;
	_minutes        int     := 0;
	_seconds        int     := 0;

	_moment  "app".type_moment;
	-- flag expired
	_has_expired    boolean := true;
begin

	if( $1 is null and $2 is null) then
		return null;
	end if;

	$1 :=coalesce($1, "app".unixtime());
	$2 :=coalesce($2, "app".unixtime());

	$1      :=coalesce($1, "app".unixtime());
	$2      :=coalesce($2, "app".unixtime());
	_moment := "app".moment($1, _tz);


	if($1 = $2) then
		return to_jsonb(r) from (
			select
				_moment.date_format as date,
				_moment.time_format as time,
				_has_expired        as has_expired,
				_totalDays	        as total_days,
				(
					select	to_jsonb(r) from (
						select
						_years   as years,
						_months  as months,
						_days    as days,
						_hours   as hours,
						_minutes as minutes,
						_seconds as seconds
					) as r
				) as part_time
		)as r;
	end if;

	IF($1 > $2) then
		select
			 ("app".moment($2, _tz)).timestamp
			,("app".moment($1, _tz)).timestamp
			,false
			into _tInf, _tSup, _has_expired;
	ELSE
		select
			 ("app".moment($1, _tz)).timestamp
			,("app".moment($2, _tz)).timestamp
			,true
			into _tInf, _tSup, _has_expired;
	end if;

	------------------------------------------------------------
	-- obteniendo dias totales
	select extract( days from _tSup - _tInf ) into _totalDays;
	------------------------------------------------------------
	-- obteniendo años
	with cte as (
		select extract( years from age(_tSup , _tInf )) as diff
	)
	select diff, (_tSup - format('%s year', diff)::interval)
	into _years, _tSup from cte;
	------------------------------------------------------------
	-- obteniendo meses:
	with cte as (
		select extract( months from age(_tSup , _tInf )) as diff
	)
	select diff, (_tSup - format('%s month', diff)::interval)
	into _months, _tSup from cte;
	---------------------------------------------------------
	-- obteninendo dias

	with cte as (
		select extract( days from  _tSup - _tInf) as diff
	)
	select diff, (_tSup - format('%s day', diff)::interval)
	into _days, _tSup from cte;
	------------------------------------------------------------
	-- obteniendo horas:
	with cte as (
		select extract( hour from  _tSup - _tInf) as diff
	)
	select diff, (_tSup - format('%s hour', diff)::interval)
	into _hours, _tSup from cte;
	------------------------------------------------------------
	-- obteniendo minutos:

	with cte as (
		select extract( minute from  _tSup - _tInf) as diff
	)
	select diff, (_tSup - format('%s minute', diff)::interval)
	into _minutes, _tSup from cte;

	------------------------------------------------------------
	-- obteniendo segundos:

	with cte as (
		select extract( second from  _tSup - _tInf) as diff
	)
	select diff, (_tSup - format('%s second', diff)::interval)
	into _seconds, _tSup from cte;

	---------------------------------------------------------------
	-- return
	return to_jsonb(r) from (
		select
			_moment.date_format as date,
			_moment.time_format as time,
			_has_expired        as has_expired,
			_totalDays	        as total_days,
			(
				select	to_jsonb(r) from (
					select
					_years   as years,
					_months  as months,
					_days    as days,
					_hours   as hours,
					_minutes as minutes,
					_seconds as seconds
				) as r
			) as part_time
	)as r;
END;
$$ language plpgsql;

































