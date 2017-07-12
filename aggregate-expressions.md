```sql

SELECT count(*) FROM test;
+---------+
|   count |
|---------|
|       3 |
+---------+


SELECT count(*) FROM test;
+---------+
|   count |
|---------|
|       3 |
+---------+

count(f1) yields the number of input rows in which f1 is non-null, since count ignores nulls;


SELECT count(name) FROM test;
+---------+
|   count |
|---------|
|       2 |
+---------+


SELECT count(distinct name) FROM test;
+---------+
|   count |
|---------|
|       1 |
+---------+

count(distinct f1) yields the number of distinct non-null values of f1



-- Order by

SELECT *, (i || name) FROM test ORDER BY (i || name)::text NULLs last; -- wrong
+-----+--------+------------+
|   i | name   | ?column?   |
|-----+--------+------------|
|   1 | xx     | 1xx        |
|   3 | xx     | 3xx        |
|   1 | <null> | <null>     |
+-----+--------+------------+


SELECT *, (i || name) tt FROM test ORDER BY tt NULLs last; -- correct
+-----+--------+--------+
|   i | name   | tt     |
|-----+--------+--------|
|   1 | xx     | 1xx    |
|   2 | yy     | 2yy    |
|   3 | xx     | 3xx    |
|   1 | <null> | <null> |
+-----+--------+--------+

This restriction is made to reduce ambiguity.



-- Aggregate Expressions

SELECT string_agg(name, '-' order by name desc) FROM test;
+--------------+
| string_agg   |
|--------------|
| yy-xx-xx     |
+--------------+


SELECT string_agg(DISTINCT name, '-' order by name desc) FROM test;
+--------------+
| string_agg   |
|--------------|
| yy-xx        |
+--------------+



There is a subclass of aggregate functions called ordered-set aggregates for which an order_by_clause is required, usually because the aggregate's computation is only sensible in terms of a specific ordering of its input rows. Typical examples of ordered-set aggregates include rank and percentile calculations.
For an ordered-set aggregate, the order_by_clause is written inside WITHIN GROUP (...), as shown in the final syntax alternative above

An example of an ordered-set aggregate call is:
https://www.postgresql.org/docs/9.6/static/sql-expressions.html#SYNTAX-AGGREGATES


SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY name) FROM test;

If FILTER is specified, then only the input rows for which the filter_clause evaluates to true are fed to the aggregate function; other rows are discarded.

SELECT
    count(*) AS unfiltered,
    count(*) FILTER (WHERE i < 5) AS filtered
FROM generate_series(1,10) AS s(i);



-- Scalar Subqueries

SELECT publisher.*, semesters
            FROM publisher INNER JOIN LATERAL (
                SELECT json_agg(semester ORDER BY id) semesters
                FROM semester
                WHERE EXISTS (
                    SELECT 1 FROM chapter
                    WHERE semester.id = chapter."semesterId"
                    AND chapter."publisherId" = publisher.id
                    AND state = 'published'
                    AND "subjectId" = 1
                )
            ) s
            ON true
            WHERE semesters NOTNULL 
            ORDER BY id


-- more simple way

SELECT publisher.*, (
    SELECT json_agg(semester ORDER BY id) semesters
    FROM semester
    WHERE EXISTS (
        SELECT 1 FROM chapter
        WHERE semester.id = chapter."semesterId"
        AND chapter."publisherId" = publisher.id
        AND state = 'published'
        AND "subjectId" = 1
    )
) FROM publisher

```


