


# Prepare
https://www.postgresql.org/docs/9.0/static/sql-prepare.html



# data OP

```sql
-- table copy
select * into newtable from oldtable

```



# CPU IO waiting - load average



# Performance Monitoring

Total number of connections
This will tell you how close you are to hitting your max_connections limit, and show up any clients which are leaking database connections.

SELECT count(*) FROM pg_stat_activity;
Number of connections by state
This query breaks down connections by state:

```sql
SELECT state, count(*) FROM pg_stat_activity GROUP BY state;

```

The possible states of interest are:

active
Connections currently executing queries. A large number tends to indicate DB slowness.
idle
Idle connections, not in a transaction.
idle in transaction
Connections with an open transaction, not executing a query. Lots of these can indicate long-running transactions.
idle in transaction (aborted)
Connection is in a transaction, but an error has occurred and the transaction hasn’t been rolled back.
Connections waiting for a lock
The number of connections blocked waiting for a lock can be an indicator of a slow transaction with an exclusive lock.

```sql
SELECT count(distinct pid) FROM pg_locks WHERE granted = false;
```

Maximum transaction age
Long-running transactions are bad because they prevent Postgres from vacuuming old data. This causes database bloat and, in extreme circumstances, shutdown due to transaction ID (xid) wraparound. Transactions should be kept as short as possible, ideally less than a minute.

Alert if this number gets greater than an hour or so.

```sql
SELECT max(now() - xact_start) FROM pg_stat_activity
                               WHERE state IN ('idle in transaction', 'active');

SELECT
    pg_size_pretty(pg_database_size(pg_database.datname)) AS size,
    pg_database.datname
    FROM pg_database;

-- view

CREATE OR REPLACE VIEW disk_usage AS
 SELECT pg_namespace.nspname AS schema, pg_class.relname AS relation,
    pg_size_pretty(pg_total_relation_size(pg_class.oid::regclass)) AS size,
    COALESCE(pg_stat_user_tables.seq_scan + pg_stat_user_tables.idx_scan, 0) AS scans
   FROM pg_class
   LEFT JOIN pg_stat_user_tables ON pg_stat_user_tables.relid = pg_class.oid
   LEFT JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
  WHERE pg_class.relkind = 'r'::"char"
  AND pg_namespace.nspname NOT IN ('pg_catalog', 'information_schema')
  ORDER BY pg_total_relation_size(pg_class.oid::regclass) DESC;

onion=> select * from disk_usage ;
 schema |         relation          | size  | scans
--------+---------------------------+-------+-------
 public | videoStatusMathHigh       | 14 GB |   163
 public | videoStatusMathHigh_noidx | 16 kB |     0

```

## pg_stat_statements
The pg_stat_statements module provides a means for tracking execution statistics of all SQL statements executed by a server

[pg_stat_statements](https://www.postgresql.org/docs/9.3/static/pgstatstatements.html)

pg_buffercache - (版本 9.4.5 和更高版本) 提供一种实时检查共享缓冲区缓存中发生的情况的方法。
每台 PostgreSQL 服务器都使用一定数量的缓冲区。缓冲区数量由 shared_buffer_space 参数（可以进行配置）和缓冲区数据块大小参数（客户无法配置）决定。例如，如果服务器具有 128MB 的 shared_buffer_space，并且每个数据块的大小是 8 KB，则系统中总共有 16384 个缓冲区。借助此扩展，您可以查看服务器上缓存了哪些表/关系。通过服务器上缓存的数据可以更快执行查询或其他操作，因为数据在内存中进行缓存，无需从磁盘加载

[pg_buffercache](https://www.postgresql.org/docs/9.1/static/pgbuffercache.html)


# role manage

```sql
create user dbuser with password 'abcD1234' createdb connection limit 30;
create user dbuser with password 'abcD1234' valid until '2017-06-10';

GRANT SELECT, INSERT, UPDATE, DELETE
ON ALL TABLES IN SCHEMA public 
TO jack;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO myuser;

To use a backslash ('\') in your MD5 password, escape the backslash with a backslash in your source string. The following example creates a user named slashpass with a single backslash ( '\') as the password.

select md5('\\'||'slashpass');
md5
--------------------------------
0c983d1a624280812631c5389e60d48c

create user slashpass password 'md50c983d1a624280812631c5389e60d48c';

```

## tune tricks

#### TABLESAMPLE - get table row count faster

```sql

SELECT 100 * count(*) AS estimate FROM mytable TABLESAMPLE SYSTEM (1);
-- TABLESAMPLE SYSTEM (1) is similiar to "select * from foo where random()<0.01".

```



## LATERAL WITH ORDINALITY

One of the neat little features that arrived at PostgreSQL 9.4 is the WITH ORDINALITY ANSI-SQL construct. What this construct does is to tack an additional column called ordinality as an additional column when you use a set returning function in the FROM part of an SQL Statement.

#### Basic WITH ORDINALITY

```sql

SELECT *
FROM unnest('{my,dog, eats, dog food}'::text[] )
    WITH ordinality;

SELECT *
FROM unnest('{my,dog, eats, dog food}'::text[] )
    WITH ordinality AS t(a,b);

SELECT * from unnest(array[array[14,41,7],array[54,9,49]]::int[])
   WITH ORDINALITY AS t(elts, num);
 elts | num
------+-----
   14 |   1
   41 |   2
    7 |   3
   54 |   4
    9 |   5
   49 |   6
(6 rows)

SELECT * FROM unnest('{1,2,3}'::int[], '{4,5,6,7}'::int[])
   WITH ORDINALITY AS t(a1, a2, num) ORDER BY t.num DESC;
 a1 | a2 | num
----+----+-----
    |  7 |   4
  3 |  6 |   3
  2 |  5 |   2
  1 |  4 |   1
(4 rows)

```

#### LATERAL WITH ORDINALITY

The greatest value of WITH ORDINALITY comes when you apply it to rows of data. How do you do that when you need to use WITH ORDINALITY. This is where one of our favorite constructs, the LATERAL construct comes to the rescue.

First let's construct our table with a text array column for demonstration. Note that the fish has no tags.

```sql
CREATE TABLE pets(pet varchar(100) PRIMARY KEY, tags text[]);
INSERT INTO pets(pet, tags)
    VALUES ('dog', '{big, furry, friendly, eats steak}'::text[]),
        ('cat', '{small, snob, eats greenbeans, plays with mouse}'::text[]),
        ('mouse', '{very small, fits in pocket, eat peanuts, watches cat}'::text[]),
        ('fish', NULL);

-- If you do a cross join, you'll leave out fish because he's got no tags

SELECT pet, sort_order, tag
FROM pets, unnest(tags)
    WITH ORDINALITY As f(tag, sort_order) ;
  pet  | sort_order |       tag
-------+------------+------------------
 dog   |          1 | big
 dog   |          2 | furry
 dog   |          3 | friendly
 dog   |          4 | eats steak
 cat   |          1 | small
 cat   |          2 | snob
 cat   |          3 | eats greenbeans
 cat   |          4 | plays with mouse
 mouse |          1 | very small
 mouse |          2 | fits in pocket
 mouse |          3 | eat peanuts
 mouse |          4 | watches cat
(12 rows)

-- In order to include pets that have no tags, you need to do a LEFT JOIN like so

SELECT pet, sort_order, tag
FROM pets LEFT JOIN
    LATERAL unnest(tags)
        WITH ORDINALITY As f(tag, sort_order) ON true;
  pet  | sort_order |       tag
-------+------------+------------------
 dog   |          1 | big
 dog   |          2 | furry
 dog   |          3 | friendly
 dog   |          4 | eats steak
 cat   |          1 | small
 cat   |          2 | snob
 cat   |          3 | eats greenbeans
 cat   |          4 | plays with mouse
 mouse |          1 | very small
 mouse |          2 | fits in pocket
 mouse |          3 | eat peanuts
 mouse |          4 | watches cat
 fish  |            |
(13 rows)

```



## Use copy command import array of Composite Types data

```sql

CREATE TYPE e_theme_icon_type AS ENUM ('perfect', 'common');

CREATE TYPE theme_icon AS (
  image varchar(200),
  svg varchar(200),
  background varchar(20),
  type e_theme_icon_type,
  goldenBackground varchar(200)
);

CREATE TABLE test (a theme_icon[], b text);

-- import file(t.copy) content
{"(g,#eeeeee,#FBCF00,perfect,#eeeeee)","(g,#678,#FBCF00,common,#123)"},jack

\copy test FROM '/Users/jack/t.copy'
# malformed array literal: "{"(g,#eeeeee,#FBCF00,perfect,#eeeeee)","(g,#678,#FBCF00,common,#123)"},jack"
# DETAIL:  Junk after closing right brace.

-- use '|' instead
{"(g,#eeeeee,#FBCF00,perfect,#eeeeee)","(g,#678,#FBCF00,common,#123)"}|jack

\copy test FROM '/Users/jack/t.copy' DELIMITER '|'

SELECT * FROM test;
+------------------------------------------------------------------------+------+
| a                                                                      | b    |
|------------------------------------------------------------------------+------|
| {"(g,#eeeeee,#FBCF00,perfect,#eeeeee)","(g,#678,#FBCF00,common,#123)"} | jack |
+------------------------------------------------------------------------+------+

```



## Set Returning Functions
functions that possibly return more than one row.



## The FILTER clause
The FILTER clause helps to manage subsets of data that meet certain conditions, thereby avoiding aggregations.

```sql
SELECT
    count(*) AS unfiltered,
    count(*) FILTER (WHERE i < 5) AS filtered
FROM generate_series(1,10) AS s(i);

+--------------+------------+
|   unfiltered |   filtered |
|--------------+------------|
|           10 |          4 |
+--------------+------------+

```
#### filter与where的区别

```sql
CREATE TABLE countries (
  code CHAR(2) NOT NULL,
  year INT NOT NULL,
  gdp_per_capita DECIMAL(10, 2) NOT NULL
);

INSERT INTO countries VALUES
    ('CA', 2009, 40764),
    ('DE', 2009, 40270),
    ('FR', 2009, 40488),
    ('CA', 2010, 47465),
    ('DE', 2010, 40408),
    ('FR', 2010, 39448)

SELECT
  year,
  count(*) FILTER (WHERE gdp_per_capita >= 40000)
FROM
  countries
GROUP BY
  year

```

```sql
-- 返回所有记录
SELECT
  year,
  code,
  gdp_per_capita,
  count(*)
    FILTER (WHERE gdp_per_capita >= 40000)
    OVER   (PARTITION BY year)
FROM
  countries

 year | code | gdp_per_capita | count
------+------+----------------+-------
 2009 | CA   |       40764.00 |     3
 2009 | DE   |       40270.00 |     3
 2009 | FR   |       40488.00 |     3
 2010 | CA   |       47465.00 |     2
 2010 | DE   |       40408.00 |     2
 2010 | FR   |       39448.00 |     2

-- 返回满足where条件的记录

SELECT
  year,
  code,
  gdp_per_capita,
  count(*)
    OVER   (PARTITION BY year)
FROM
  countries
WHERE gdp_per_capita >= 40000

 year | code | gdp_per_capita | count
------+------+----------------+-------
 2009 | CA   |       40764.00 |     3
 2009 | DE   |       40270.00 |     3
 2009 | FR   |       40488.00 |     3
 2010 | CA   |       47465.00 |     2
 2010 | DE   |       40408.00 |     2

```


## Array Constructors
An array constructor is an **expression** that builds an array value using values for its member elements.

```sql
SELECT ARRAY[1,2,3+4];
SELECT ARRAY[1,2,3+4]::int[];
```
Multidimensional array:

```sql
SELECT ARRAY[ARRAY[1,2], ARRAY[3,4]];

CREATE TABLE arr(f1 int[], f2 int[]);

INSERT INTO arr VALUES (ARRAY[[1,2],[3,4]], ARRAY[[5,6],[7,8]]);

SELECT ARRAY[f1, f2, '{{9,10},{11,12}}'::int[]] FROM arr;
```

you must explicitly cast your empty array to the desired type:
```sql
SELECT ARRAY[]::integer[];
```

construct an array from the results of a subquery
```sql
SELECT ARRAY(SELECT oid FROM pg_proc WHERE proname LIKE 'bytea%');
SELECT ARRAY(SELECT ARRAY[i, i*2] FROM generate_series(1,5) AS a(i));
```

## Row Constructors
 row constructor is an expression that builds a row value (also called a composite value) using values for its member fields
 
```sql 
 SELECT ROW(1,2.5,'this is a test');
 
 SELECT ROW(t.*, 42) FROM t;
 SELECT ROW(t.f1, t.f2, 42) FROM t;
 
 SELECT ROW(1,2.5,'this is a test') = ROW(1, 3, 'not the same');
 SELECT ROW(table.*) IS NULL FROM table;  -- detect all-null rows
```

## Expression Evaluation Rules
When it is essential to force evaluation order, a CASE construct can be used. For example, this is an untrustworthy way of trying to avoid division by zero in a WHERE clause:

```sql
SELECT ... WHERE x > 0 AND y/x > 1.5;
```

But this is safe:

```sql
SELECT ... WHERE CASE WHEN x > 0 THEN y/x > 1.5 ELSE false END;
```

## Constants 

#### Unicode Escapes

```sql
SELECT U&'\0061 \0062';
SELECT U&'!0061 !0062' UESCAPE '!';

+------------+
| ?column?   |
|------------|
| a b        |
+------------+
```

#### Dollar-quoted

```sql
SELECT $$Dianne's horse$$;
$SomeTag$Dianne's horse$SomeTag$
```

#### Bit-string
```sql
SELECT B'1001';

SELECT X'1FF';

+--------------+
| ?column?     |
|--------------|
| 000111111111 |
+--------------+
```

#### Numeric Constants
```sql
SELECT 5e2;

+------------+
|   ?column? |
|------------|
|      500.0 |
+------------+

SELECT 1.925e-3;

+------------+
|   ?column? |
|------------|
|   0.001925 |
+------------+

SELECT REAL '1.23'; -- force casting it

+----------+
|   float4 |
|----------|
|     1.23 |
+----------+
```

## Calling Functions

#### named/positional notation
```sql
CREATE FUNCTION concat_lower_or_upper(a text, b text, uppercase boolean DEFAULT false)
RETURNS text
AS
$$
 SELECT CASE
        WHEN $3 THEN UPPER($1 || ' ' || $2)
        ELSE LOWER($1 || ' ' || $2)
        END;
$$
LANGUAGE SQL IMMUTABLE STRICT;

SELECT concat_lower_or_upper('Hello', 'World', true);
SELECT concat_lower_or_upper(a => 'Hello', b => 'World', uppercase => true);
+-------------------------+
| concat_lower_or_upper   |
|-------------------------|
| HELLO WORLD             |
+-------------------------+
```

## LATERAL join

LATERAL join is like a SQL foreach loop, in which PostgreSQL will iterate over each row in a result set and evaluate a subquery using that row as a parameter.

#### An example conversion funnel

```sql
CREATE TABLE event (
  user_id BIGINT,
  time BIGINT NOT NULL,
  data JSON NOT NULL
);

INSERT INTO event VALUES
  (1, 100, '{"type": "view_homepage"}'),
  (1, 200, '{"type": "view_homepage"}'),
  (2, 100, '{"type": "view_homepage"}'),
  (2, 500, '{"type": "enter_credit_card"}'),
  (3, 100, '{"type": "view_homepage"}'),
  (3, 300, '{"type": "view_homepage"}'),
  (3, 500, '{"type": "enter_credit_card"}'),
  (4, 100, '{"type": "enter_credit_card"}');

SELECT 
  user_id,
  view_homepage,
  view_homepage_time,
  enter_credit_card,
  enter_credit_card_time
FROM (
  -- Get the first time each user viewed the homepage.
  SELECT
    user_id,
    1 AS view_homepage,
    min(time) AS view_homepage_time
  FROM event
  WHERE
    data->>'type' = 'view_homepage'
  GROUP BY user_id
) e1 LEFT JOIN LATERAL (
  -- For each row, get the first time the user_id did the enter_credit_card
  -- event, if one exists within two weeks of view_homepage_time.
  SELECT
    1 AS enter_credit_card,
    time AS enter_credit_card_time
  FROM event
  WHERE
    user_id = e1.user_id AND
    data->>'type' = 'enter_credit_card' AND
    time BETWEEN view_homepage_time AND (view_homepage_time + 1000*60*60*24*14)
  ORDER BY time
  LIMIT 1
) e2 ON true

+-----------+-----------------+----------------------+---------------------+--------------------------+
|   user_id |   view_homepage |   view_homepage_time |   enter_credit_card |   enter_credit_card_time |
|-----------+-----------------+----------------------+---------------------+--------------------------|
|         1 |               1 |                  100 |              <null> |                   <null> |
|         2 |               1 |                  100 |                   1 |                      500 |
|         3 |               1 |                  100 |                   1 |                      500 |
+-----------+-----------------+----------------------+---------------------+--------------------------+

SELECT 
  sum(view_homepage) AS viewed_homepage,
  sum(enter_credit_card) AS entered_credit_card
FROM (
  -- Get the first time each user viewed the homepage.
  SELECT
    user_id,
    1 AS view_homepage,
    min(time) AS view_homepage_time
  FROM event
  WHERE
    data->>'type' = 'view_homepage'
  GROUP BY user_id
) e1 LEFT JOIN LATERAL (
  -- For each (user_id, view_homepage_time) tuple, get the first time that
  -- user did the enter_credit_card event, if one exists within two weeks.
  SELECT
    1 AS enter_credit_card,
    time AS enter_credit_card_time
  FROM event
  WHERE
    user_id = e1.user_id AND
    data->>'type' = 'enter_credit_card' AND
    time BETWEEN view_homepage_time AND (view_homepage_time + 1000*60*60*24*14)
  ORDER BY time
  LIMIT 1
) e2 ON true

+-------------------+-----------------------+
|   viewed_homepage |   entered_credit_card |
|-------------------+-----------------------|
|                 3 |                     2 |
+-------------------+-----------------------+
```

add a use_demo step between viewing the homepage and entering a credit card.

```sql

INSERT INTO event VALUES
  (1, 600, '{"type": "use_demo"}'),
  (1, 900, '{"type": "use_demo"}'),
  (2, 400, '{"type": "use_demo"}'),
  (4, 700, '{"type": "use_demo"}');
  

SELECT 
  user_id,
  view_homepage,
  view_homepage_time,
  use_demo,
  use_demo_time,
  enter_credit_card,
  enter_credit_card_time
FROM (
  -- Get the first time each user viewed the homepage.
  SELECT
    user_id,
    1 AS view_homepage,
    min(time) AS view_homepage_time
  FROM event
  WHERE
    data->>'type' = 'view_homepage'
  GROUP BY user_id
) e1 LEFT JOIN LATERAL (
  SELECT
    1 AS use_demo,
    time AS use_demo_time
  FROM event
  WHERE
    user_id = e1.user_id AND
    data->>'type' = 'use_demo' AND
    time BETWEEN view_homepage_time AND (view_homepage_time + 1000*60*60*24*14)
  ORDER BY time
  LIMIT 1
) e2 ON true LEFT JOIN LATERAL (
  -- For each row, get the first time the user_id did the enter_credit_card
  -- event, if one exists within two weeks of use_demo_time.
  SELECT
    1 AS enter_credit_card,
    time AS enter_credit_card_time
  FROM event
  WHERE
    user_id = e1.user_id AND
    data->>'type' = 'enter_credit_card' AND
    time BETWEEN use_demo_time AND (use_demo_time + 1000*60*60*24*14)
  ORDER BY time
  LIMIT 1
) e3 ON true

 user_id | view_homepage | view_homepage_time | use_demo | use_demo_time | enter_credit_card | enter_credit_card_time
---------+---------------+--------------------+----------+---------------+-------------------+------------------------
       1 |             1 |                100 |        1 |           600 |                   |
       2 |             1 |                100 |        1 |           400 |                 1 |                    500
       3 |             1 |                100 |          |               |                   |


SELECT 
  sum(view_homepage) AS viewed_homepage,
  sum(use_demo) AS use_demo,
  sum(enter_credit_card) AS entered_credit_card
FROM (
  -- Get the first time each user viewed the homepage.
  SELECT
    user_id,
    1 AS view_homepage,
    min(time) AS view_homepage_time
  FROM event
  WHERE
    data->>'type' = 'view_homepage'
  GROUP BY user_id
) e1 LEFT JOIN LATERAL (
  SELECT
    1 AS use_demo,
    time AS use_demo_time
  FROM event
  WHERE
    user_id = e1.user_id AND
    data->>'type' = 'use_demo' AND
    time BETWEEN view_homepage_time AND (view_homepage_time + 1000*60*60*24*14)
  ORDER BY time
  LIMIT 1
) e2 ON true LEFT JOIN LATERAL (
  -- For each row, get the first time the user_id did the enter_credit_card
  -- event, if one exists within two weeks of use_demo_time.
  SELECT
    1 AS enter_credit_card,
    time AS enter_credit_card_time
  FROM event
  WHERE
    user_id = e1.user_id AND
    data->>'type' = 'enter_credit_card' AND
    time BETWEEN use_demo_time AND (use_demo_time + 1000*60*60*24*14)
  ORDER BY time
  LIMIT 1
) e3 ON true

+-------------------+------------+-----------------------+
|   viewed_homepage |   use_demo |   entered_credit_card |
|-------------------+------------+-----------------------|
|                 3 |          2 |                     1 |
+-------------------+------------+-----------------------+
```

[参考 PostgreSQL's Powerful New Join Type: LATERAL](https://blog.heapanalytics.com/postgresqls-powerful-new-join-type-lateral/)


## Returning Hierarchical Data in a Single SQL Query

```sql
CREATE TABLE employee (
  employee_id INT PRIMARY KEY,
  name TEXT NOT NULL
);

CREATE TABLE project (
  project_id INT PRIMARY KEY,
  employee_id INT NOT NULL REFERENCES employee(employee_id),
  name text NOT NULL
);

INSERT INTO employee VALUES
    (1, 'Jon Snow'),
    (2, 'Thoren Smallwood'),
    (3, 'Samwell Tarley')

INSERT INTO project VALUES
    (1, 1, $$Infiltrate Mance Rayder's Camp$$),
    (2, 3, $$Research the Wights$$)
    
```

row_to_json provides the ability to turn a database row into a json object, which is the key:

```sql
SELECT
  p.*,
  row_to_json(e.*) as employee
FROM project p
INNER JOIN employee e USING(employee_id)
```

Sometimes it is necessary to return additional fields along with a given object that may not be directly included in the database table

```sql
ALTER TABLE project ADD COLUMN dateassigned DATE;

UPDATE project SET dateassigned = '2013/09/10' WHERE project_id = 1;
UPDATE project SET dateassigned = '2013/09/16' WHERE project_id = 2;

INSERT INTO project (project_id, employee_id, name, dateassigned)
VALUES (3, 3, 'Send a raven to Kings Landing', '2013/09/21');
INSERT INTO project (project_id, employee_id, name, dateassigned)
VALUES (4, 2, 'Scout wildling movement', '2013/09/01');

-- CTE
WITH project AS (
  SELECT
    p.*,
    date_part('epoch', age(now(), dateassigned::timestamp)) as time
  FROM project p
)

SELECT
  e.employee_id,
  e.name,
  json_agg(p.*) as projects
FROM employee e
INNER JOIN project p USING (employee_id)
WHERE employee_id = 3
GROUP BY e.employee_id, e.name
```

#### Recursive Common Table Expressions

```sql
ALTER TABLE employee ADD COLUMN superior_id INT REFERENCES employee(employee_id);

INSERT INTO employee (employee_id, name, superior_id)
VALUES (4, 'Jeor Mormont', null);
UPDATE employee SET superior_id = 4 WHERE employee_id <> 4;

INSERT INTO employee (employee_id, name, superior_id)
VALUES (5, 'Ghost', 1);
INSERT INTO employee (employee_id, name, superior_id)
VALUES (6, 'Iron Emmett', 1);
INSERT INTO employee (employee_id, name, superior_id)
VALUES (7, 'Hareth', 6);
```
We can now use a recursive CTE (common table expression) to return this tree of data in a single query along with the depth of each node. Recursive CTEs allow you to reference the virtual table within its own definition. They take the form of two queries joined by a union, where one query acts as the terminating condition of the recursion and the other joins to it. Technically they are implemented iteratively in the underlying engine, but it can be useful to think recursively when composing the queries.

```sql
WITH RECURSIVE employeetree AS (
  SELECT e.*, 0 as depth
  FROM employee e
  WHERE e.employee_id = 1

  UNION ALL

  SELECT e.*, t.depth + 1 as depth
  FROM employee e
  INNER JOIN employeetree t
    ON t.employee_id = e.superior_id
)

SELECT * FROM employeetree

 employee_id |    name     | superior_id | depth
-------------+-------------+-------------+-------
           1 | Jon Snow    |           4 |     0
           5 | Ghost       |           1 |     1
           6 | Iron Emmett |           1 |     1
           7 | Hareth      |           6 |     2
```

Combining Everything

```sql
WITH RECURSIVE employeetree AS (
  WITH employeeprojects AS (
    SELECT
      p.employee_id,
      json_agg(p.*) as projects
    FROM (
      SELECT
        p.*,
        date_part('day', age(now(), dateassigned::timestamp)) as age
      FROM project p
    ) AS p
    GROUP BY p.employee_id
  )

  SELECT
    e.*,
    null::json as superior,
    COALESCE(ep.projects, '[]') as projects
  FROM employee e
  LEFT JOIN employeeprojects ep
    USING(employee_id)
  WHERE superior_id IS NULL

  UNION ALL

  SELECT
    e.*,
    row_to_json(sup.*) as superior,
    COALESCE(ep.projects, '[]') as projects
  FROM employee e
  INNER JOIN employeetree sup
    ON sup.employee_id = e.superior_id
  LEFT JOIN employeeprojects ep
    ON ep.employee_id = e.employee_id
)

SELECT *
FROM employeetree
WHERE employee_id = 7
```

[参考 Returning Hierarchical Data in a Single SQL Query](http://bender.io/2013/09/22/returning-hierarchical-data-in-a-single-sql-query/)




## MVCC

[参考 MVCC PostgreSQL实现事务和多版本并发控制的精华](http://www.jasongj.com/sql/mvcc/)



## PostgreSQL中文全文检索

[参考 PostgreSQL + SCWS + zhparser + Rails4 + pg_search 实现中文全文检索](http://www.racksam.com/2016/05/03/chinese-full-text-searching-with-postgresql-zhparser-and-rails/)


## GROUPING SETS, CUBE, and ROLLUP

#### GROUPING SETS

```sql

CREATE TABLE items_sold (
    brand text,
    size  text,
    sales int
);

INSERT INTO items_sold VALUES
    ('Foo', 'L', 10),
    ('Foo', 'M', 20),
    ('Bar', 'M', 15),
    ('Bar', 'L', 5);

SELECT brand, size, sum(sales) FROM items_sold GROUP BY GROUPING SETS ((brand), (size), ());

 brand | size | sum
-------+------+-----
 Bar   |      |  20
 Foo   |      |  30
       |      |  50
       | L    |  15
       | M    |  35

```

#### ROLLUP

```sql

ROLLUP ( e1, e2, e3, ... )
-- represents the given list of expressions and all prefixes of the list including the empty list; thus it is equivalent to

GROUPING SETS (
    ( e1, e2, e3, ... ),
    ...
    ( e1, e2 ),
    ( e1 ),
    ( )
)

```

```sql

SELECT brand, size, sum(sales) FROM items_sold GROUP BY ROLLUP (brand, size);

 brand | size | sum
-------+------+-----
 Bar   | L    |   5
 Bar   | M    |  15
 Bar   |      |  20
 Foo   | L    |  10
 Foo   | M    |  20
 Foo   |      |  30
       |      |  50

```

```sql

ROLLUP ( a, (b, c), d )
-- is equivalent to

GROUPING SETS (
    ( a, b, c, d ),
    ( a, b, c    ),
    ( a          ),
    (            )
)
```

```sql

SELECT brand, size, sum(sales) FROM items_sold GROUP BY ROLLUP ((brand, size), (brand));

 brand | size | sum
-------+------+-----
 Bar   | L    |   5
 Bar   | L    |   5
 Bar   | M    |  15
 Bar   | M    |  15
 Foo   | L    |  10
 Foo   | L    |  10
 Foo   | M    |  20
 Foo   | M    |  20
       |      |  50
(9 rows)

```


#### CUBE

```sql
CUBE ( a, b, c )
-- is equivalent to
GROUPING SETS (
    ( a, b, c ),
    ( a, b    ),
    ( a,    c ),
    ( a       ),
    (    b, c ),
    (    b    ),
    (       c ),
    (         )
)
```

```sql

SELECT brand, size, sum(sales) FROM items_sold GROUP BY CUBE (brand, size);

 brand | size | sum
-------+------+-----
 Bar   | L    |   5
 Bar   | M    |  15
 Bar   |      |  20
 Foo   | L    |  10
 Foo   | M    |  20
 Foo   |      |  30
       |      |  50
       | L    |  15
       | M    |  35
(9 rows)

```

```sql
CUBE ( (a, b), (c, d) )
-- is equivalent to

GROUPING SETS (
    ( a, b, c, d ),
    ( a, b       ),
    (       c, d ),
    (            )
)

```

```sql

SELECT brand, size, sum(sales) FROM items_sold GROUP BY CUBE ((brand, size), (brand));

 brand | size | sum
-------+------+-----
 Bar   | L    |   5
 Bar   | L    |   5
 Bar   | M    |  15
 Bar   | M    |  15
 Bar   |      |  20
 Foo   | L    |  10
 Foo   | L    |  10
 Foo   | M    |  20
 Foo   | M    |  20
 Foo   |      |  30
       |      |  50
(11 rows)

```

If multiple grouping items are specified in a single GROUP BY clause, then the final list of grouping sets is the cross product of the individual items. For example:

```sql
-- GROUP BY a, CUBE (b, c), GROUPING SETS ((d), (e))
-- is equivalent to

GROUP BY GROUPING SETS (
    (a, b, c, d), (a, b, c, e),
    (a, b, d),    (a, b, e),
    (a, c, d),    (a, c, e),
    (a, d),       (a, e)
)

```

[参考 QUERIES-GROUPING-SETS](https://www.postgresql.org/docs/9.5/static/queries-table-expressions.html#QUERIES-GROUPING-SETS)


## Block-range indexes

uuid

[参考 BRIN Indexes](https://www.postgresql.org/docs/9.5/static/brin-intro.html)


# Parallel JOIN, aggregate

set max_parallel_workers_per_gather to 8 ;
show max_parallel_workers_per_gather ;

```sql
explain analyze select count(*) from "user" u inner join "dailySignin" d on d.name = u.name;

                                                                          QUERY PLAN
---------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize Aggregate  (cost=1214278.97..1214278.98 rows=1 width=8) (actual time=60989.651..60989.652 rows=1 loops=1)
   ->  Gather  (cost=1214278.25..1214278.96 rows=7 width=8) (actual time=60962.915..60989.628 rows=8 loops=1)
         Workers Planned: 7
         Workers Launched: 7
         ->  Partial Aggregate  (cost=1213278.25..1213278.26 rows=1 width=8) (actual time=60741.495..60741.497 rows=1 loops=8)
               ->  Hash Join  (cost=320257.10..1210927.94 rows=940122 width=0) (actual time=39614.448..59028.595 rows=780059 loops=8)
                     Hash Cond: ((d.name)::text = (u.name)::text)
                     ->  Parallel Seq Scan on "dailySignin" d  (cost=0.00..797923.31 rows=2716331 width=11) (actual time=0.128..9681.567 rows=2376975 loops=8)
                     ->  Hash  (cost=214686.49..214686.49 rows=6073249 width=11) (actual time=36794.569..36794.569 rows=3395758 loops=8)
                           Buckets: 131072  Batches: 128  Memory Usage: 2138kB
                           ->  Seq Scan on "user" u  (cost=0.00..214686.49 rows=6073249 width=11) (actual time=0.065..19564.054 rows=6075295 loops=8)
 Planning time: 0.373 ms
 Execution time: 61076.038 ms
(13 rows)

set max_parallel_workers_per_gather to 0 ;

explain analyze  select count(*) from "user" u inner join "dailySignin" d on d.nickname = u.nickname;

30m+

```

[参考 WAITING FOR 9.6 – SUPPORT PARALLEL AGGREGATION.](https://www.depesz.com/2016/03/23/waiting-for-9-6-support-parallel-aggregation/)


## Row-Level Security

[参考 CREATE POLICY](https://www.postgresql.org/docs/9.5/static/sql-createpolicy.html)

https://www.postgresql.org/docs/9.0/static/sql-notify.html


## Phrase search
[参考 WAITING FOR 9.6 – PHRASE FULL TEXT SEARCH.](https://www.depesz.com/2016/04/22/waiting-for-9-6-phrase-full-text-search/)


## Materialized views

Use materialized views cautiously
If you’re not familiar with materialized view they’re a query that has been actually created as a table. So it’s a materialized or basically snapshotted version of some query or “view”. In their initial version materialized versions, which were long requested in Postgres, were entirely unusuable because when you it was a locking transaction which could hold up other reads and acticities avainst that view.
They’ve since gotten much better, but there’s no tooling for refreshing them out of the box. This means you have to setup some scheduler job or cron job to regularly refresh your materialized views. If you’re building some reporting or BI app you may undoubtedly need them, but their usability could still be advanced so that Postgres knew how to more automatically refresh them.


## A simpler method for pivot tables

Table_func is often referenced as the way to compute a pivot table in Postgres. Sadly though it’s pretty difficult to use, and the more basic method would be to just do it with raw SQL. This will get much better with Postgres 9.5, but until then something where you sum up each condition where it’s true or false and then totals is much simpler to reason about:


select date,
       sum(case when type = 'OSX' then val end) as osx,
       sum(case when type = 'Windows' then val end) as windows,
       sum(case when type = 'Linux' then val end) as linux
from daily_visits_per_os
group by date
order by date
limit 4;

http://www.craigkerstiens.com/2014/02/26/Tracking-MoM-growth-in-SQL/


## PostGIS

earth_distance extension

GiST indexes





