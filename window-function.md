
# Window Functions

## percentile

Get percentile of 25%, 50%, 75%, 100%

```sql
CREATE TABLE t AS SELECT generate_series(1,19) AS val;

```
[CREATE TABLE AS](https://github.com/guanghetv/postgres-feature/blob/master/create_table.md#create-table-as----define-a-new-table-from-the-results-of-a-query)

[generate_series](https://github.com/guanghetv/postgres-feature/blob/master/table-functions.md)


```sql
WITH subset AS (
    SELECT val,
       ntile(4) OVER (ORDER BY val) AS tile
    FROM t
  )
  SELECT max(val)
  FROM subset GROUP BY tile ORDER BY tile;

 max
-----
   5
  10
  15
  19
(4 rows)
```

The WITHIN GROUP clause is particularly useful when performing aggregations on ordered subsets of data.
WITHIN GROUP clause instead

```sql
SELECT unnest(percentile_disc(array[0.25,0.5,0.75,1])
   WITHIN GROUP (ORDER BY val)) as max
   FROM t;

 max
-----
   5
  10
  15
  19
(4 rows)
```

watch! percentile_cont, think about it!

```sql
SELECT unnest(percentile_cont(array[0.25,0.5,0.75,1])
   WITHIN GROUP (ORDER BY val)) as max
   FROM t;

 max
------
  5.5
   10
 14.5
   19
(4 rows)

```

## The FILTER clause

In particular case, this also simplifies the readability of scripts and improves execution performances.

```sql
SELECT count(*),
    count(CASE WHEN val % 2 = 0 THEN 1 END),
    count(CASE WHEN val % 3 = 0 THEN 1 END)
FROM t ;

-- filter
SELECT count(*),
    count(*) filter (WHERE val % 2 = 0),
    count(*) filter (WHERE val % 3 = 0)
FROM t ;
+---------+---------+---------+
|   count |   count |   count |
|---------+---------+---------|
|      19 |       9 |       6 |
+---------+---------+---------+

```



## PARTITION

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

WITH rank_list as (
    select Player, Year, HomeRuns, Rank() over (Partition BY Player order by HomeRuns DESC) as rank
    from
    Batting
)
SELECT * FROM rank_list WHERE rank = 1;
+----------+--------+------------+--------+
| player   |   year |   homeruns |   rank |
|----------+--------+------------+--------|
| A        |   2002 |         23 |      1 |
| B        |   2003 |         42 |      1 |
| B        |   2001 |         42 |      1 |
| C        |   2005 |          9 |      1 |
+----------+--------+------------+--------+


```

Now, like before, we have to deal with ties.  But now, it is much easier -- we just add a secondary sort.  Since we want to the latest year to rank higher, we just add "Year DESC" to our ORDER BY:

```sql
select Player, Year, HomeRuns,Rank() over (Partition BY Player order by HomeRuns DESC, Year DESC) as Rank,
-- cume_dist 可以将用户进行分组归类
cume_dist() over (Partition BY Player order by HomeRuns) as cume_dist,
ROW_NUMBER() over (Partition BY Player order by HomeRuns)
from 
Batting;

 player | year | homeruns | rank | cume_dist | row_number
--------+------+----------+------+-----------+------------
 A      | 2005 |       11 |    5 |       0.2 |          1
 A      | 2001 |       13 |    4 |       0.4 |          2
 A      | 2004 |       14 |    3 |       0.6 |          3
 A      | 2003 |       19 |    2 |       0.8 |          4
 A      | 2002 |       23 |    1 |         1 |          5
 B      | 2004 |       29 |    4 |      0.25 |          1
 B      | 2002 |       39 |    3 |       0.5 |          2
 B      | 2001 |       42 |    2 |         1 |          3
 B      | 2003 |       42 |    1 |         1 |          4
 C      | 2002 |        2 |    4 |      0.25 |          1
 C      | 2003 |        3 |    3 |       0.5 |          2
 C      | 2004 |        6 |    2 |      0.75 |          3
 C      | 2005 |        9 |    1 |         1 |          4

```

```sql
WITH rank_list as (
    select Player, Year, HomeRuns,
        Rank() over (Partition BY Player order by HomeRuns DESC, Year DESC) as rank
    from
    Batting
)
SELECT * FROM rank_list WHERE rank = 1;
+----------+--------+------------+--------+
| player   |   year |   homeruns |   rank |
|----------+--------+------------+--------|
| A        |   2002 |         23 |      1 |
| B        |   2003 |         42 |      1 |
| C        |   2005 |          9 |      1 |
+----------+--------+------------+--------+
```

growth by year

```sql
select Player, Year, HomeRuns,
    cast(homeRuns as numeric) / lag(homeruns, 1) over (Partition BY Player order by year) lag,
    round((cast(homeRuns as numeric) / lag(homeruns, 1) over (Partition BY Player order by year) - 1) * 100, 2) as growth
 from
 Batting;

 player | year | homeruns |          lag           | growth
--------+------+----------+------------------------+--------
 A      | 2001 |       13 |                        |
 A      | 2002 |       23 |     1.7692307692307692 |  76.92
 A      | 2003 |       19 | 0.82608695652173913043 | -17.39
 A      | 2004 |       14 | 0.73684210526315789474 | -26.32
 A      | 2005 |       11 | 0.78571428571428571429 | -21.43
 B      | 2001 |       42 |                        |
 B      | 2002 |       39 | 0.92857142857142857143 |  -7.14
 B      | 2003 |       42 |     1.0769230769230769 |   7.69
 B      | 2004 |       29 | 0.69047619047619047619 | -30.95
 C      | 2002 |        2 |                        |
 C      | 2003 |        3 |     1.5000000000000000 |  50.00
 C      | 2004 |        6 |     2.0000000000000000 | 100.00
 C      | 2005 |        9 |     1.5000000000000000 |  50.00
(13 rows)

```

returns the most frequent input value (arbitrarily choosing the first one if there are multiple equally-frequent results)
```sql
select mode() within group (order by homeruns) from batting ;
 mode
------
   42
(1 row)
```


## Hypothetical-Set Aggregate Functions

rank of the hypothetical row, with gaps for duplicate rows


```sql
-- with given homeruns were added at given player.
select player, rank(19) within group (order by homeruns desc) from batting group by player;
 player | rank
--------+------
 A      |    2
 B      |    5
 C      |    1
(3 rows)


select player, cume_dist(19) within group (order by homeruns) from batting group by player;
 player |     cume_dist
--------+-------------------
 A      | 0.833333333333333
 B      |               0.2
 C      |                 1
(3 rows)

```

[参考 Using PARTITION and RANK in your criteria](http://weblogs.sqlteam.com/jeffs/archive/2007/03/28/60146.aspx)



## Mix PERCENTILE_CONT & PARTITION

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



##  Aggregate Functions for Statistics

![the standard deviation](https://wikimedia.org/api/rest_v1/media/math/render/svg/32e3c0f27c2595926963cc5d8df113e6a12cf917)


```sql
-- user count within 1 SD
with tmp as (
    select stddev_pop(points) sd, avg(points) avg from "user"
), "1sd" as (
    select count(*) filter (where points between (select avg from tmp) and (select sd from tmp)) "+1sd",
        count(*) filter (where points between 0 and (select avg from tmp)) "-1sd"
    from "user"
), total as (
    select count(*) from "user"
)
select "+1sd",
    cast("+1sd" as numeric)/(select count from total) "+1sd_percent",
    "-1sd",
    cast("-1sd" as numeric)/(select count from total) "-1sd_percent" from "1sd";

  +1sd  |      +1sd_percent      |  -1sd   |      -1sd_percent
--------+------------------------+---------+------------------------
 708339 | 0.11659335061095798640 | 4941535 | 0.81338190161959213503
(1 row)

```

so, 92% users are in 1SD

### correlation coefficient

![correlation coefficient](https://wikimedia.org/api/rest_v1/media/math/render/svg/bd1ccc2979b0fd1c1aec96e386f686ae874f9ec0)

```sql
elect corr(points, coins) from "user";
       corr
-------------------
 0.727738347225498
(1 row)

```




