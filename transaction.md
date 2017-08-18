# Transaction


## READ COMMITTED
    A statement can only see rows committed before it began. This is the default.

### Read

```sql
DROP TABLE IF EXISTS test;
create table test (id int primary key, value int);
insert into test (id, value) values (1, 10), (2, 20);

-- T1
begin; set transaction isolation level read committed;
update test set value = 11 where id = 1;

-- T2
begin; set transaction isolation level read committed;
select * from test ;
 id | value
----+-------
  1 |    10
  2 |    20

update test set value = 21 where id = 2;
select * from test ;
 id | value
----+-------
  1 |    10 -- only see rows before it began.
  2 |    21

-- T1
select * from test ;
 id | value
----+-------
  2 |    20 -- only see rows before it began.
  1 |    11

commit;

-- T2
select * from test ;
 id | value
----+-------
  1 |    11 -- can see rows committed after it began.
  2 |    21

commit;

-- T1
select * from test ;
 id | value
----+-------
  1 |    11
  2 |    21 -- can see rows committed after it began.

```


### Write

```sql
DROP TABLE IF EXISTS test;
create table test (id int primary key, value int);
insert into test (id, value) values (1, 10), (2, 20);

-- T1
begin; set transaction isolation level read committed;
update test set value = 11 where id = 1;

-- T2
begin; set transaction isolation level read committed;
update test set value = 12 where id = 1; -- blocked

-- T1
commit ; -- T2 unblocked

-- T2
commit ;

```




## REPEATABLE READ
    All statements of the current transaction can only see rows committed 
    before the first query or data-modification statement was executed in this transaction.

### Read

```sql

DROP TABLE IF EXISTS test;
create table test (id int primary key, value int);
insert into test (id, value) values (1, 10), (2, 20);

-- T1
begin; set transaction isolation level repeatable read;
update test set value = 11 where id = 1;

-- T2
begin; set transaction isolation level repeatable read;
select * from test ;
 id | value
----+-------
  1 |    10 -- can see rows committed after it began.
  2 |    20

-- T1
commit;

-- T2
select * from test ;
 id | value
----+-------
  1 |    10 -- can also not see rows committed after it began.
  2 |    20

commit;

select * from test ;
 id | value
----+-------
  2 |    20
  1 |    11 -- can see rows after committed.

```


### Write

```sql

DROP TABLE IF EXISTS test;
create table test (id int primary key, value int);
insert into test (id, value) values (1, 10), (2, 20);

-- T1
begin; set transaction isolation level repeatable read;
update test set value = 11 where id = 1;

-- T2
begin; set transaction isolation level repeatable read;
update test set value = 12 where id = 1; -- blocked

-- T1
commit ; -- T2 ERROR:  could not serialize access due to concurrent update

```



## SERIALIZABLE
    All statements of the current transaction can only see rows committed 
before the first query or data-modification statement was executed in this transaction. 
If a pattern of reads and writes among concurrent serializable transactions would create a situation 
which could not have occurred for any serial (one-at-a-time) execution of those transactions, 
one of them will be rolled back with a serialization_failure SQLSTATE.


### Read and writes among concurrent serializable

```sql

DROP TABLE IF EXISTS test;
create table test (id int primary key, value int);
insert into test (id, value) values (1, 10), (2, 20);

-- T1
begin; set transaction isolation level serializable;
select * from test ;

-- T2
begin; set transaction isolation level serializable;
select * from test ;


-- T1
update test set value = 11 where id = 1;

-- T2
update test set value = 21 where id = 2;

-- T1
commit;

-- T2
commit;
-- ERROR:  could not serialize access due to read/write dependencies among transactions
-- DETAIL:  Reason code: Canceled on identification as a pivot, during conflict out checking.

```


```sql

DROP TABLE IF EXISTS test;
create table test (id int primary key, value int);
insert into test (id, value) values (1, 10), (2, 20);

-- T1
begin; set transaction isolation level serializable;
select * from test ;

-- T2
begin; set transaction isolation level serializable;
-- select * from test ;

-- T1
update test set value = 11 where id = 1;

-- T2
update test set value = 21 where id = 2;

-- T1
commit;

-- T2
select * from test ;
-- commit;
-- ERROR:  could not serialize access due to read/write dependencies among transactions
-- DETAIL:  Reason code: Canceled on identification as a pivot, during conflict out checking.

```







