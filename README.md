


# Prepare
https://www.postgresql.org/docs/9.0/static/sql-prepare.html



# data OP

```sql
-- table copy
select * into newtable from oldtable

```



# CPU IO waiting - load average




## tune tricks

#### TABLESAMPLE - get table row count faster

```sql

SELECT 100 * count(*) AS estimate FROM mytable TABLESAMPLE SYSTEM (1);
-- TABLESAMPLE SYSTEM (1) is similiar to "select * from foo where random()<0.01".

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





