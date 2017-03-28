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


## EXCLUSION CONSTRAINTS

```sql
CREATE TABLE test (
    i INT4,
    EXCLUDE (i WITH =)
);

INSERT INTO test (i) VALUES (1);
INSERT INTO test (i) VALUES (2);

INSERT INTO test (i) VALUES (1);
ERROR:  conflicting key value violates exclusion constraint "test_i_excl"

```

```sql
CREATE TABLE test (
    from_ts TIMESTAMPTZ,
    to_ts   TIMESTAMPTZ,
    CHECK ( from_ts < to_ts ),
    CONSTRAINT overlapping_times EXCLUDE USING GIST (
        box(
            point( extract(epoch FROM from_ts at time zone 'UTC'), extract(epoch FROM from_ts at time zone 'UTC') ),
            point( extract(epoch FROM to_ts at time zone 'UTC')  , extract(epoch FROM to_ts at time zone 'UTC') )
        ) WITH &&
    )
);

INSERT INTO test ( from_ts, to_ts ) VALUES ( '2009-01-01 01:23:45 EST', '2009-01-10 23:45:12 EST' );
INSERT INTO test ( from_ts, to_ts ) VALUES ( '2009-02-01 01:23:45 EST', '2009-02-10 23:45:12 EST' );

INSERT INTO test ( from_ts, to_ts ) VALUES ( '2009-01-08 00:00:00 EST', '2009-01-15 23:59:59 EST' );
ERROR:  conflicting key value violates exclusion constraint "overlapping_times"

```

What's more – readability of the code can be dramatically improved by providing a wrapper around calculations, like this:

```sql
CREATE OR REPLACE FUNCTION box_from_ts_range(in_first timestamptz, in_second timestamptz) RETURNS box as $$
DECLARE
    first_float  float8 := extract(epoch FROM in_first  AT TIME ZONE 'UTC');
    second_float float8 := extract(epoch FROM in_second AT TIME ZONE 'UTC');
BEGIN
    RETURN box( point ( first_float, first_float), point( second_float, second_float ) );
END;
$$ language plpgsql IMMUTABLE;

CREATE TABLE test (
    from_ts TIMESTAMPTZ,
    to_ts   TIMESTAMPTZ,
    CHECK ( from_ts < to_ts ),
    CONSTRAINT overlapping_times EXCLUDE USING GIST ( box_from_ts_range( from_ts, to_ts ) WITH && )
);

```

Now, let's try to use the EXCLUDE for something more realistic – room reservations for hotel.

```sql
CREATE TABLE reservations (
    id          SERIAL PRIMARY KEY,
    room_number INT4 NOT NULL,
    from_ts     DATE NOT NULL,
    to_ts       DATE NOT NULL,
    guest_name  TEXT NOT NULL,
    CHECK       ( from_ts <= to_ts ),
    CHECK       ( room_number >= 101 AND room_number <= 700 AND room_number % 100 >= 1 AND room_number % 100 <= 25 )
);

ALTER TABLE public.reservations ADD CONSTRAINT check_overlapping_reservations EXCLUDE USING GIST (
    box (
        point(
            from_ts - '2000-01-01'::date,
            room_number
        ),
        point(
            ( to_ts - '2000-01-01'::date ) + 0.5,
            room_number + 0.5
        )
    )
    WITH &&
);

INSERT INTO reservations (room_number, from_ts, to_ts, guest_name) VALUES (101, '2010-01-05', '2010-01-23', 'test1');
INSERT INTO reservations (room_number, from_ts, to_ts, guest_name) VALUES (102, '2010-01-07', '2010-01-21', 'test2');
INSERT INTO reservations (room_number, from_ts, to_ts, guest_name) VALUES (101, '2010-01-25', '2010-01-30', 'test3');

INSERT INTO reservations (room_number, from_ts, to_ts, guest_name) VALUES (101, '2010-01-07', '2010-01-08', 'test4');
ERROR:  conflicting key value violates exclusion constraint "check_overlapping_reservations"

```

[参考 EXCLUSION CONSTRAINTS](https://www.depesz.com/2010/01/03/waiting-for-8-5-exclusion-constraints/)


## MVCC

[参考 MVCC PostgreSQL实现事务和多版本并发控制的精华](http://www.jasongj.com/sql/mvcc/)


## foreign data wrapper

[参考 PostgreSQL 9.5 新特性之 - 水平分片架构与实践](https://yq.aliyun.com/articles/6635)


## PostgreSQL中文全文检索

[参考 PostgreSQL + SCWS + zhparser + Rails4 + pg_search 实现中文全文检索](http://www.racksam.com/2016/05/03/chinese-full-text-searching-with-postgresql-zhparser-and-rails/)

