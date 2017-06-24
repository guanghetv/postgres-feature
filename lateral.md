
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


```sql
-- get hyper video info,this sql can't handle it

SELECT video.id, video.name,
json_agg("videoAddress") AS addresses,
json_agg("videoInteraction") AS interactions,
json_agg("videoClip") AS clips
from video
inner join "videoAddress" ON "videoAddress"."videoId" = video.id
left join "videoInteraction" on "videoInteraction"."videoId" = video.id
left join "videoClip" on "videoClip"."videoId" = video.id
GROUP BY video.id

limit 1;

-- use lateral instead


with hv as (
    SELECT video.id, video.name, addresses, interactions, clips
    from video
    inner join lateral (
        -- SELECT json_agg(json_build_object('url', url, 'format', format)) addresses
        -- select json_agg(row_to_json( (select r from (select url, format) r) ))
        -- SELECT json_agg( (select r from (select url, format) r) ) addresses
        -- select json_agg(cast(ROW(url, format) as temp_type)) addresses
        -- select json_agg(ROW(url, format)::temp_type) addresses
        SELECT json_agg(s) addresses
        from "videoAddress"
        cross join lateral
            (select url, format) s
        where "videoId" = video.id
    ) AS va ON true
    left join lateral (
        SELECT json_agg(s) interactions
        from "videoInteraction"
        cross join lateral (SELECT choices, time) s
        where "videoId" = video.id
    ) vi ON true
    left join lateral (
        SELECT json_agg(s) clips
        from "videoClip"
        cross join lateral
            (select id, start) s
        where "videoId" = video.id
    ) vc ON true
)
SELECT * from hv

limit 2;

-- test composite type

select video.name, tmp.*
from video left join lateral (
    select s.* from "videoAddress"
    cross join lateral (
        select "videoId", url, format from "videoAddress"
    ) s
    where "videoAddress"."videoId" = s."videoId"
) tmp ON true

```

[参考 PostgreSQL's Powerful New Join Type: LATERAL](https://blog.heapanalytics.com/postgresqls-powerful-new-join-type-lateral/)
