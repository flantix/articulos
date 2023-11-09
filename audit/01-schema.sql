CREATE EXTENSION IF NOT EXISTS hstore;

create table audit(
	id         bigserial,
	operation  varchar(20)   NOT NULL,
	ipclient   varchar(100)  NOT NULL,
	userdb     varchar(100)  NOT NULL,
	tbname     varchar(250)  NOT NULL,
	log_sql    TEXT          DEFAULT current_query(),
	old_rc     json,
	new_rc     json,
	old_txt    TEXT,
	new_txt    TEXT,
	created_at timestamp without time zone not null default current_timestamp,
	primary key(id)
);

create index audit_index00 on audit (operation);
create index audit_index01 on audit (ipclient);
create index audit_index02 on audit (userdb);
create index audit_index03 on audit (tbname);
create index audit_index04 on audit (log_sql);
create index audit_index05 on audit (new_txt);
create index audit_index06 on audit (old_txt);
create index audit_index07 on audit (created_at);


CREATE OR REPLACE FUNCTION tgb_audit() returns trigger as
$BODY$
BEGIN
	raise exception 'writing directly to the audit table is not allowed';
END
$BODY$
LANGUAGE PLPGSQL;

CREATE TRIGGER tgb_audit
BEFORE INSERT OR UPDATE OR DELETE
ON audit
FOR EACH ROW
WHEN (pg_trigger_depth() = 0) -- the audit table can only be written when called by a trigger
EXECUTE PROCEDURE tgb_audit();


------- audit triggers:

CREATE OR REPLACE FUNCTION tg_audit() returns trigger as
$BODY$
	DECLARE
		_oldH     hstore;
		_newH     hstore;
		_oldTXT   TEXT;
		_newTXT   TEXT;
		_key 	  TEXT;
		_tb       TEXT = format('%s.%s', TG_TABLE_SCHEMA,TG_TABLE_NAME);
BEGIN
	IF(_tb = 'public.audit') THEN
		IF(TG_OP = 'DELETE') THEN
			return NULL;
		END IF;

		RETURN NEW;
	END IF;

	_oldH := hstore(OLD);
	_newH := hstore(NEW);

	-- all columns to TXT
	FOREACH _key IN ARRAY akeys(_oldH) LOOP
		_oldTXT := format('%s %s', _oldTXT, _oldH->_key);
		_newTXT := format('%s %s', _newTXT, _newH->_key);
	END LOOP;

	IF(TG_OP='DELETE') THEN
		insert into audit(operation, ipclient, userdb, tbname, old_rc, old_txt, created_at)
			select
				 TG_OP
				,inet_client_addr()::TEXT
				,current_user
				,_tb
				,row_to_json(OLD)
				,_oldTXT
				,current_timestamp;
		RETURN OLD;
	END IF;

	IF(TG_OP='INSERT') THEN
		insert into audit(operation, ipclient, userdb, tbname, new_rc, new_txt, created_at)
			select
				 TG_OP
				,inet_client_addr()::TEXT
				,current_user
				,_tb
				,row_to_json(NEW)
				,_newTXT
				,current_timestamp;
		return NEW;
	END IF;

	-- only save audit when saved data is not the same
	IF(_newTXT <> _oldTXT) THEN
		insert into audit(operation, ipclient, userdb, tbname, new_rc, new_txt, old_rc, old_txt, created_at)
			select
				TG_OP
				,inet_client_addr()::TEXT
				,current_user
				,_tb
				,row_to_json(NEW)
				,_newTXT
				,row_to_json(OLD)
				,_oldTXT
				,current_timestamp;
	END IF;

	return NEW;
END
$BODY$
LANGUAGE PLPGSQL;

------------------------------
-- test table:
create table test(
	id serial not null,
	name varchar(255) not null,
	primary key(id)
);

-- register audit trigger for test table:
CREATE TRIGGER aaaa_test_audit -- the name of the trigger is important when there is more than one trigger they are sorted alphabetically
AFTER INSERT OR UPDATE OR DELETE
ON test
FOR EACH ROW
EXECUTE PROCEDURE tg_audit();


