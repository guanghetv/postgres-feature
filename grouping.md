
## GROUPING SETS, CUBE, and ROLLUP

CUBE, ROLLUP and GROUPING SETS: These new standard SQL clauses let users produce reports with multiple levels of summarization in one query instead of requiring several. CUBE will also enable tightly integrating PostgreSQL with more Online Analytic Processing (OLAP) reporting tools such as Tableau.



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
