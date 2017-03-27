# postgres-feature

## Window function

#### The WITHIN GROUP clause is particularly useful when performing aggregations on ordered subsets of data.

```sql
CREATE TABLE t AS SELECT generate_series(1,20) AS val;

WITH subset AS (
    SELECT val,
       ntile(4) OVER (ORDER BY val) AS tile
    FROM t
  )
  SELECT max(val)
  FROM subset GROUP BY tile ORDER BY tile;

+-------+
|   max |
|-------|
|     5 |
|    10 |
|    15 |
|    20 |
+-------+
```

WITHIN GROUP clause instead

```sql
SELECT unnest(percentile_disc(array[0.25,0.5,0.75,1])
   WITHIN GROUP (ORDER BY val)) as max
   FROM t;

+-------+
|   max |
|-------|
|     5 |
|    10 |
|    15 |
|    20 |
+-------+
```

watch! percentile_cont, think about it!

```sql
SELECT unnest(percentile_cont(array[0.25,0.5,0.75,1])
   WITHIN GROUP (ORDER BY val)) as max
   FROM t;

+-------+
|   max |
|-------|
|  5.75 |
| 10.5  |
| 15.25 |
| 20.0  |
+-------+

```

[参考 The WITHIN GROUP and FILTER SQL clauses](https://blog.2ndquadrant.com/the-within-group-and-filter-sql-clauses-of-postgresql-9-4/)

#### PARTITION and RANK

```sql
create table Batting
 (Player varchar(10), Year int, Team varchar(10), HomeRuns int, primary key(Player,Year))

insert into Batting
select 'A',2001,'Red Sox',13 union all
select 'A',2002,'Red Sox',23 union all
select 'A',2003,'Red Sox',19 union all
select 'A',2004,'Red Sox',14 union all
select 'A',2005,'Red Sox',11 union all
select 'B',2001,'Yankees',42 union all
select 'B',2002,'Yankees',39 union all
select 'B',2003,'Yankees',42 union all
select 'B',2004,'Yankees',29 union all
select 'C',2002,'Yankees',2 union all
select 'C',2003,'Yankees',3 union all
select 'C',2004,'Red Sox',6 union all
select 'C',2005,'Red Sox',9

```
Suppose we would like to find out which year each player hit their most home runs, and which team they played for.  As a tie-breaker, return the latest year

First, get the MAX(HomeRuns) per player, and then join back to the Batting table to return the rest of the data:

```sql
select b.*
from
batting b
inner join
(    select player, Max(HomeRuns) as MaxHR
    from Batting
    group by player
) m 
on b.Player = m.player and b.HomeRuns = m.MaxHR

+----------+--------+---------+------------+
| player   |   year | team    |   homeruns |
|----------+--------+---------+------------|
| A        |   2002 | Red Sox |         23 |
| B        |   2001 | Yankees |         42 |
| B        |   2003 | Yankees |         42 |
| C        |   2005 | Red Sox |          9 |
+----------+--------+---------+------------+

```
Note that for player 'B', we get two rows back since he has two years that tie for the most home runs (2001 and 2003).  How do we return just the latest year? 

```sql
select b.*
from
batting b
inner join
(    select player, Max(HomeRuns) as MaxHR
    from Batting
    group by player
) m 
    on b.Player = m.player and b.HomeRuns = m.MaxHR
inner join
(  select player, homeRuns, Max(Year) as MaxYear
   from Batting
   group by Player, HomeRuns
) y
   on m.player= y.player and m.maxHR = y.HomeRuns and b.Year = y.MaxYear
   
+----------+--------+---------+------------+
| player   |   year | team    |   homeruns |
|----------+--------+---------+------------|
| B        |   2003 | Yankees |         42 |
| C        |   2005 | Red Sox |          9 |
| A        |   2002 | Red Sox |         23 |
+----------+--------+---------+------------+

```

An alternate way to do this is to calculate the "ranking" of each home run for each player, using a correlated subquery:

```sql
select b.*, 
  (select count(*) from batting b2 where b.player = b2.player and b2.HomeRuns >= b.HomeRuns) as Rank
from batting b;

+----------+--------+---------+------------+--------+
| player   |   year | team    |   homeruns |   rank |
|----------+--------+---------+------------+--------|
| A        |   2001 | Red Sox |         13 |      4 |
| A        |   2002 | Red Sox |         23 |      1 |
| A        |   2003 | Red Sox |         19 |      2 |
| A        |   2004 | Red Sox |         14 |      3 |
| A        |   2005 | Red Sox |         11 |      5 |
| B        |   2001 | Yankees |         42 |      2 |
| B        |   2002 | Yankees |         39 |      3 |
| B        |   2003 | Yankees |         42 |      2 |
| B        |   2004 | Yankees |         29 |      4 |
| C        |   2002 | Yankees |          2 |      4 |
| C        |   2003 | Yankees |          3 |      3 |
| C        |   2004 | Red Sox |          6 |      2 |
| C        |   2005 | Red Sox |          9 |      1 |
+----------+--------+---------+------------+--------+
```

However, notice that we still have not handled ties! (notice that Player "B" has no #1 ranking, just two #2 rankings!) To do that, we must make things a little more complicated:

```sql
select b.*, 
  (select count(*) from batting b2 where b.player = b2.player and (b2.HomeRuns > b.HomeRuns or (b2.HomeRuns = b.HomeRuns and b2.Year >= b.Year))) as Rank
from batting b;

+----------+--------+---------+------------+--------+
| player   |   year | team    |   homeruns |   rank |
|----------+--------+---------+------------+--------|
| A        |   2001 | Red Sox |         13 |      4 |
| A        |   2002 | Red Sox |         23 |      1 |
| A        |   2003 | Red Sox |         19 |      2 |
| A        |   2004 | Red Sox |         14 |      3 |
| A        |   2005 | Red Sox |         11 |      5 |
| B        |   2001 | Yankees |         42 |      2 |
| B        |   2002 | Yankees |         39 |      3 |
| B        |   2003 | Yankees |         42 |      1 |
| B        |   2004 | Yankees |         29 |      4 |
| C        |   2002 | Yankees |          2 |      4 |
| C        |   2003 | Yankees |          3 |      3 |
| C        |   2004 | Red Sox |          6 |      2 |
| C        |   2005 | Red Sox |          9 |      1 |
+----------+--------+---------+------------+--------+
```

And, with that, we can use our "ranking" formula to return only the #1 rankings to get our results by moving the subquery to the WHERE clause:

```sql
select b.*
from batting b
where (select count(*) from batting b2 where b.player = b2.player and (b2.HomeRuns > b.HomeRuns or (b2.HomeRuns = b.HomeRuns and b2.Year >= b.Year))) =1;

+----------+--------+---------+------------+
| player   |   year | team    |   homeruns |
|----------+--------+---------+------------|
| A        |   2002 | Red Sox |         23 |
| B        |   2003 | Yankees |         42 |
| C        |   2005 | Red Sox |          9 |
+----------+--------+---------+------------+
```

use partition & rank instead:

```sql
select Player, Year, HomeRuns, Rank() over (Partition BY Player order by HomeRuns DESC) as Rank
from 
Batting;

+----------+--------+------------+--------+
| player   |   year |   homeruns |   rank |
|----------+--------+------------+--------|
| A        |   2002 |         23 |      1 |
| A        |   2003 |         19 |      2 |
| A        |   2004 |         14 |      3 |
| A        |   2001 |         13 |      4 |
| A        |   2005 |         11 |      5 |
| B        |   2003 |         42 |      1 |
| B        |   2001 |         42 |      1 |
| B        |   2002 |         39 |      3 |
| B        |   2004 |         29 |      4 |
| C        |   2005 |          9 |      1 |
| C        |   2004 |          6 |      2 |
| C        |   2003 |          3 |      3 |
| C        |   2002 |          2 |      4 |
+----------+--------+------------+--------+
```

Now, like before, we have to deal with ties.  But now, it is much easier -- we just add a secondary sort.  Since we want to the latest year to rank higher, we just add "Year DESC" to our ORDER BY:

```sql
select Player, Year, HomeRuns,Rank() over (Partition BY Player order by HomeRuns DESC, Year DESC) as Rank,
ROW_NUMBER() over (Partition BY Player order by HomeRuns)
from 
Batting;

+----------+--------+------------+--------+--------------+
| player   |   year |   homeruns |   rank |   row_number |
|----------+--------+------------+--------+--------------|
| A        |   2005 |         11 |      5 |            1 |
| A        |   2001 |         13 |      4 |            2 |
| A        |   2004 |         14 |      3 |            3 |
| A        |   2003 |         19 |      2 |            4 |
| A        |   2002 |         23 |      1 |            5 |
| B        |   2004 |         29 |      4 |            1 |
| B        |   2002 |         39 |      3 |            2 |
| B        |   2001 |         42 |      2 |            3 |
| B        |   2003 |         42 |      1 |            4 |
| C        |   2002 |          2 |      4 |            1 |
| C        |   2003 |          3 |      3 |            2 |
| C        |   2004 |          6 |      2 |            3 |
| C        |   2005 |          9 |      1 |            4 |
+----------+--------+------------+--------+--------------+
```

[参考 Using PARTITION and RANK in your criteria](http://weblogs.sqlteam.com/jeffs/archive/2007/03/28/60146.aspx)

#### Mix PERCENTILE_CONT & OVER

The following example computes the median salary & rank in each department:

```sql
CREATE TABLE employees (
  name text,
  SALARY int NOT NULL,
  DEPARTMENT_ID BIGINT NOT NULL
);

INSERT INTO employees VALUES
('Raphaely', 11000, 1),
('Khoo', 3100, 1),
('Baida', 2900, 1),
('Tobias', 2800, 2),
('Himuro', 2600, 2),
('Colmenares', 2500, 3),
('Hunold', 9000, 3),
('Ernst', 6000, 3),
('Austin', 4800, 4),
('Pataballa', 4800, 4),
('Lorentz', 4200, 4);


   PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary DESC) 

select t1.*, t2.percentile_cont from (
    SELECT name, salary, department_id,
       PERCENT_RANK()
          OVER (PARTITION BY department_id ORDER BY salary DESC) "Percent_Rank",
       RANK()
          OVER (PARTITION BY department_id ORDER BY salary DESC) "Rank"
    FROM employees
) t1 left join (
    SELECT department_id,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary DESC) percentile_cont from employees
        group by department_id
) t2 on t2.department_id = t1.department_id

+------------+----------+-----------------+----------------+--------+-------------------+
| name       |   salary |   department_id |   Percent_Rank |   Rank |   percentile_cont |
|------------+----------+-----------------+----------------+--------+-------------------|
| Raphaely   |    11000 |               1 |            0.0 |      1 |            3100.0 |
| Khoo       |     3100 |               1 |            0.5 |      2 |            3100.0 |
| Baida      |     2900 |               1 |            1.0 |      3 |            3100.0 |
| Tobias     |     2800 |               2 |            0.0 |      1 |            2700.0 |
| Himuro     |     2600 |               2 |            1.0 |      2 |            2700.0 |
| Hunold     |     9000 |               3 |            0.0 |      1 |            6000.0 |
| Ernst      |     6000 |               3 |            0.5 |      2 |            6000.0 |
| Colmenares |     2500 |               3 |            1.0 |      3 |            6000.0 |
| Austin     |     4800 |               4 |            0.0 |      1 |            4800.0 |
| Pataballa  |     4800 |               4 |            0.0 |      1 |            4800.0 |
| Lorentz    |     4200 |               4 |            1.0 |      3 |            4800.0 |
+------------+----------+-----------------+----------------+--------+-------------------+
```

[参考 PERCENTILE_CONT](https://docs.oracle.com/cd/B19306_01/server.102/b14200/functions110.htm)

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



