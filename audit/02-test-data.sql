insert into test (name) select
	format('name - %s', g) from generate_series(1, 10) as g;

update test set name = 'name updated' where id = 1;

delete from test where id = 2;
