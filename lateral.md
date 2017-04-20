
# LATERAL WITH ORDINALITY

One of the neat little features that arrived at PostgreSQL 9.4 is the WITH ORDINALITY ANSI-SQL construct. What this construct does is to tack an additional column called ordinality as an additional column when you use a set returning function in the FROM part of an SQL Statement.

## Basic WITH ORDINALITY

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

## LATERAL WITH ORDINALITY

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
