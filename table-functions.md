# Table Functions

## Series Generating Functions

```sql

SELECT * FROM generate_series(2,4);

 generate_series
-----------------
               2
               3
               4

SELECT * FROM generate_series(5,1,-2);

 generate_series
-----------------
               5
               3
               1

SELECT generate_series(1.1, 4, 1.3);

 generate_series
-----------------
             1.1
             2.4
             3.7

SELECT current_date + i AS date FROM generate_series(0,14,7) AS t(i);

+------------+
| date       |
|------------|
| 2017-03-31 |
| 2017-04-07 |
| 2017-04-14 |
+------------+

SELECT * FROM generate_series('2008-03-01 00:00'::timestamp,
                              '2008-03-04 12:00', '10 hours');

   generate_series
---------------------
 2008-03-01 00:00:00
 2008-03-01 10:00:00
 2008-03-01 20:00:00
 2008-03-02 06:00:00
 2008-03-02 16:00:00
 2008-03-03 02:00:00
 2008-03-03 12:00:00
 2008-03-03 22:00:00
 2008-03-04 08:00:00

```

#### more insteresting!

For example, when you run a SELECT sum(data) FROM table GROUP BY date query, you might have missing dates where the sum is zero. If you use your numbers table to add days to a start date, you can join that to your query to make sure no days are missed. However, Postgres makes a numbers table obsolete with the generate_series() function.

```sql

with simul_data as (
    --Give me a random date betwen 8/1 and 8/7
    select cast(trunc(random() * 7) as int) + date '8/1/2013' as mydate
    --Give me a random number
    ,cast(trunc(random() * 100) as int) as data
    --Make 10 rows
    from generate_series(1,10))
,full_dates as (
    --Select every date between 8/1 and 8/7
    select generate_series(0,6) + date '8/1/2013' as fulldate
)

--If we do a regular aggregate, here's what you get:
select mydate, sum(data)
from simul_data
group by mydate;

--Notice the missing date? To force it in place, use a join.

select fulldate,coalesce(sum(data),0) as data_sum
from full_dates
  left join simul_data on full_dates.fulldate=simul_data.mydate
group by fulldate;

```

mock data batch easily

```sql

create table test (
  mydate date,
  data int
);

with simul_data as(
  --Give me a random date betwen 8/1 and 8/7
  select (cast(trunc(random() * 7) as int)) + date '8/1/2013' as myDate
  --Give me a random number
  ,cast(trunc(random() * 100) as int) as data
  --Make 10 rows
  from generate_series(1,10))

INSERT INTO test
  SELECT * FROM simul_data;
+------------+--------+
| mydate     |   data |
|------------+--------|
| 2013-08-02 |     59 |
| 2013-08-02 |     91 |
| 2013-08-06 |     49 |
| 2013-08-02 |     18 |
| 2013-08-04 |     71 |
| 2013-08-04 |     32 |
| 2013-08-07 |     53 |
| 2013-08-01 |     39 |
| 2013-08-05 |     84 |
| 2013-08-07 |     32 |
+------------+--------+

```

One of our database tables has a unique two-digit identifier that consists of two letters. I wanted to see which of the 26^2 two-letter codes were still available. To do this, I used generate_series() and chr() to give me a list of letters. I then created a Cartesian product of the data which I could join with the live data.

```sql

with list as(
    --65 in ASCII is "A" and 90 is "Z"
    select chr(generate_series(65,90)) letter
)
select t1.letter||t2.letter combo
from list t1
    --join every letter with every other letter
    cross join list t2;

 combo
-------
 AA
 AB
 AC
 AD
 AE
[...]
 ZV
 ZW
 ZX
 ZY
 ZZ
(676 rows)

```


## Subscript Generating Functions
generate_subscripts is a convenience function that generates the set of valid subscripts for the specified dimension of the given array

```sql

SELECT generate_subscripts('{NULL,1,NULL,2}'::int[], 1) AS s;

 s
---
 1
 2
 3
 4

CREATE TABLE arrays (a int[]);
INSERT INTO arrays VALUES ('{-1,-2}'), ('{100,200,300}');

SELECT *, a[subscript] FROM (
  SELECT a, generate_subscripts(a, 1) subscript FROM arrays) t;

       a       | subscript |  a
---------------+-----------+-----
 {-1,-2}       |         1 |  -1
 {-1,-2}       |         2 |  -2
 {100,200,300} |         1 | 100
 {100,200,300} |         2 | 200
 {100,200,300} |         3 | 300

 SELECT generate_subscripts('{{100,200,300}, {1,2,3}}'::int[],1);

 +-----------------------+
|   generate_subscripts |
|-----------------------|
|                     1 |
|                     2 |
+-----------------------+

SELECT generate_subscripts('{{100,200,300}, {1,2,3}}'::int[],2);

+-----------------------+
|   generate_subscripts |
|-----------------------|
|                     1 |
|                     2 |
|                     3 |
+-----------------------+

CREATE OR REPLACE FUNCTION unnest2(anyarray)
  RETURNS SETOF anyelement AS $$
  SELECT $1[i][j] FROM generate_subscripts($1, 1) g1(i),
  generate_subscripts($1,2) g2(j);
  $$ LANGUAGE sql IMMUTABLE;

SELECT unnest2('{{100,200,300}, {1,2,3}}'::int[]);

+-----------+
|   unnest2 |
|-----------|
|       100 |
|       200 |
|       300 |
|         1 |
|         2 |
|         3 |
+-----------+

SELECT * FROM unnest2(ARRAY[[1,2],[3,4]]);

+-----------+
|   unnest2 |
|-----------|
|         1 |
|         2 |
|         3 |
|         4 |
+-----------+

SELECT * FROM unnest2(ARRAY[[1,2],[3,4]]) WITH ORDINALITY;

+-----------+--------------+
|   unnest2 |   ordinality |
|-----------+--------------|
|         1 |            1 |
|         2 |            2 |
|         3 |            3 |
|         4 |            4 |
+-----------+--------------+

SELECT * FROM pg_ls_dir('.') WITH ORDINALITY AS t(ls,n);

+----------------------+-----+
| ls                   |   n |
|----------------------+-----|
| base                 |   1 |
| global               |   2 |
| pg_clog              |   3 |
| pg_commit_ts         |   4 |
| pg_dynshmem          |   5 |
| pg_hba.conf          |   6 |
| pg_ident.conf        |   7 |
| pg_logical           |   8 |
| pg_multixact         |   9 |
| pg_notify            |  10 |
| pg_replslot          |  11 |
| pg_serial            |  12 |
| pg_snapshots         |  13 |
| pg_stat              |  14 |
| pg_stat_tmp          |  15 |
| pg_subtrans          |  16 |
| pg_tblspc            |  17 |
| pg_twophase          |  18 |
| PG_VERSION           |  19 |
| pg_xlog              |  20 |
| postgresql.auto.conf |  21 |
| postgresql.conf      |  22 |
| postmaster.opts      |  23 |
| postmaster.pid       |  24 |
+----------------------+-----+

```


## Table Functions with dblink

Table functions are functions that produce a set of rows, made up of either base data types (scalar types) or composite data types (table rows). They are used like a table, view, or subquery in the FROM clause of a query.

Some examples:

```sql

CREATE TABLE foo (id int, name text);

CREATE OR REPLACE FUNCTION getfoo(int) RETURNS SETOF foo AS $$
    SELECT * FROM foo WHERE id = $1;
$$ LANGUAGE SQL;

SELECT * FROM getfoo(1) AS t1;

SELECT * FROM foo
    WHERE id IN (
        SELECT id
        FROM getfoo(foo.id)
    );

CREATE OR REPLACE VIEW vw_getfoo AS SELECT * FROM getfoo(1);

SELECT * FROM vw_getfoo;

```

```sql

SELECT * FROM
dblink(
  'user=master password=xxx host=xxx.amazonaws.com.cn dbname=onion port=5432',
  'SELECT proname, prosrc FROM pg_proc'
)
AS t1(proname name, prosrc text) WHERE proname LIKE 'bytea%';

         proname          |          prosrc
--------------------------+--------------------------
 byteain                  | byteain
 byteaout                 | byteaout
 bytea_string_agg_transfn | bytea_string_agg_transfn
 bytea_string_agg_finalfn | bytea_string_agg_finalfn
 byteaeq                  | byteaeq
 bytealt                  | bytealt
 byteale                  | byteale
 byteagt                  | byteagt
 byteage                  | byteage
 byteane                  | byteane
 byteacmp                 | byteacmp
 bytea_sortsupport        | bytea_sortsupport
 bytealike                | bytealike
 byteanlike               | byteanlike
 byteacat                 | byteacat
 bytearecv                | bytearecv
 byteasend                | byteasend
(17 rows)

```

The dblink function (part of the dblink module) executes a remote query. It is declared to return record since it might be used for any kind of query. The actual column set must be specified in the calling query so that the parser knows, for example, what * should expand to.

