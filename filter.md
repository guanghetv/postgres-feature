
# The FILTER clause
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
## filter与where的区别

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
