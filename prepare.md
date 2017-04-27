
# PREPARE

```sql
create table test (id int, name text) ;

PREPARE testplan (int, text) AS
    INSERT INTO test VALUES ($1, $2);
EXECUTE testplan(1, 'jack');
EXECUTE testplan(2, 'yamaha');

select name, statement from pg_prepared_statements ;
   name   |               statement
----------+---------------------------------------
 testplan | PREPARE testplan (int, text) AS      +
          |     INSERT INTO test VALUES ($1, $2);
(1 row)

-- avoid sql inject
execute testplan (3, 'xx; drop table test')

-- escape string
execute testplan (4, $$Sarah O'Hara4$$)

```
