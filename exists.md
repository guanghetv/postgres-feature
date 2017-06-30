
-- ```sql
CREATE TABLE a (id int, name text);
CREATE TABLE b (id int, travel text) ;

INSERT INTO a VALUES (1, 'jack'), (2, 'jone');
INSERT INTO b VALUES (1, 'Chengdu'), (1, 'Kunming'), (3, 'Tibet');
```



## ANTI JOIN

```sql

-- slow way

explain  select * from a where id not in (select id from b);
                       QUERY PLAN
---------------------------------------------------------
 Seq Scan on a  (cost=1.05..2.09 rows=2 width=36)
   Filter: (NOT (hashed SubPlan 1))
   SubPlan 1
     ->  Seq Scan on b  (cost=0.00..1.04 rows=4 width=4)
(4 rows)


-- fast way

EXPLAIN SELECT * FROM a LEFT join b on b.id = a.id WHERE b.id IS null;
+--------------------------------------------------------------+
| QUERY PLAN                                                   |
|--------------------------------------------------------------|
| Hash Anti Join  (cost=1.07..2.09 rows=1 width=72)            |
|   Hash Cond: (a.id = b.id)                                   |
|   ->  Seq Scan on a  (cost=0.00..1.02 rows=2 width=36)       |
|   ->  Hash  (cost=1.03..1.03 rows=3 width=36)                |
|         ->  Seq Scan on b  (cost=0.00..1.03 rows=3 width=36) |
+--------------------------------------------------------------+

-- Another fast way

EXPLAIN SELECT * FROM a WHERE not exists (SELECT 1 from b where b.id = a.id) ;
+-------------------------------------------------------------+
| QUERY PLAN                                                  |
|-------------------------------------------------------------|
| Hash Anti Join  (cost=1.07..2.09 rows=1 width=36)           |
|   Hash Cond: (a.id = b.id)                                  |
|   ->  Seq Scan on a  (cost=0.00..1.02 rows=2 width=36)      |
|   ->  Hash  (cost=1.03..1.03 rows=3 width=4)                |
|         ->  Seq Scan on b  (cost=0.00..1.03 rows=3 width=4) |
+-------------------------------------------------------------+
```

[ANTI JOIN](http://blog.montmere.com/2010/12/08/the-anti-join-all-values-from-table1-where-not-in-table2/)



## Use the EXISTS key word for TRUE / FALSE return


```sql
select exists(select 1 from a where id=1);
 exists
--------
 t
(1 row)

```

## Any/All

```sql
EXPLAIN SELECT * FROM a WHERE id in (1,2);
                     QUERY PLAN
----------------------------------------------------
 Seq Scan on a  (cost=0.00..25.88 rows=13 width=36)
   Filter: (id = ANY ('{1,2}'::integer[]))
(2 rows)

EXPLAIN SELECT * FROM a WHERE id = Any (ARRAY[1,2]);
                     QUERY PLAN
----------------------------------------------------
 Seq Scan on a  (cost=0.00..25.88 rows=13 width=36)
   Filter: (id = ANY ('{1,2}'::integer[]))
(2 rows)

EXPLAIN SELECT * FROM a WHERE id not in (1,2);
                      QUERY PLAN
------------------------------------------------------
 Seq Scan on a  (cost=0.00..25.88 rows=1257 width=36)
   Filter: (id <> ALL ('{1,2}'::integer[]))
(2 rows)


EXPLAIN SELECT * FROM a WHERE id <> all (ARRAY[1,2]);
                      QUERY PLAN
------------------------------------------------------
 Seq Scan on a  (cost=0.00..25.88 rows=1257 width=36)
   Filter: (id <> ALL ('{1,2}'::integer[]))
(2 rows)

```


## SQL Performance of Join and Where Exists

```sql
CREATE TABLE p
(
    p_id serial PRIMARY KEY,
    p_name character varying UNIQUE
);

INSERT INTO p (p_name)
    SELECT substr(gen_salt('md5'), 4)
    FROM generate_series(1, 1000000);


CREATE TABLE o
(
    o_id serial PRIMARY KEY,
    p_id integer REFERENCES p (p_id)
);

INSERT INTO o (p_id)
SELECT rnd_val
FROM (SELECT trunc(random() * 249999 + 1)::int AS rnd_val
        FROM generate_series(1, 1000000)) as gen;


explain analyze SELECT p_name FROM p JOIN o USING(p_id);

                                                        QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------
 Hash Join  (cost=32789.00..73662.19 rows=1000050 width=9) (actual time=1872.381..4957.022 rows=1000000 loops=1)
   Hash Cond: (o.p_id = p.p_id)
   ->  Seq Scan on o  (cost=0.00..14425.50 rows=1000050 width=4) (actual time=0.019..906.299 rows=1000000 loops=1)
   ->  Hash  (cost=15406.00..15406.00 rows=1000000 width=13) (actual time=1870.251..1870.251 rows=1000000 loops=1)
         Buckets: 131072  Batches: 16  Memory Usage: 3961kB
         ->  Seq Scan on p  (cost=0.00..15406.00 rows=1000000 width=13) (actual time=0.009..874.207 rows=1000000 loops=1)
 Planning time: 0.309 ms
 Execution time: 5727.273 ms
(8 rows)


explain analyze select p_name
FROM p
where exists (select 1 from o where p_id = p.p_id);

                                                       QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------
 Hash Semi Join  (cost=30832.00..75484.40 rows=199590 width=9) (actual time=1841.239..4168.940 rows=245381 loops=1)
   Hash Cond: (p.p_id = o.p_id)
   ->  Seq Scan on p  (cost=0.00..15406.00 rows=1000000 width=13) (actual time=0.011..872.211 rows=1000000 loops=1)
   ->  Hash  (cost=14425.00..14425.00 rows=1000000 width=4) (actual time=1838.461..1838.461 rows=1000000 loops=1)
         Buckets: 131072  Batches: 16  Memory Usage: 3235kB
         ->  Seq Scan on o  (cost=0.00..14425.00 rows=1000000 width=4) (actual time=0.009..875.683 rows=1000000 loops=1)
 Planning time: 0.362 ms
 Execution time: 4358.823 ms
(8 rows)

-- With the inner join,  
-- any record with more than one foreign key in orders referring to a primary key in products creates a  
-- undesired duplicate in the result set.

/*
The reduced costs of this query plan are more than obvious - and lower costs mean fewer I/O accesses.
So, in future a more detailed analysis of such queries is worth a look
*/

explain analyze SELECT DISTINCT p_name FROM p JOIN o USING(p_id);
                                                              QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------------------
 Unique  (cost=190409.34..195409.34 rows=1000000 width=9) (actual time=8655.028..11980.461 rows=245381 loops=1)
   ->  Sort  (cost=190409.34..192909.34 rows=1000000 width=9) (actual time=8655.025..10927.739 rows=1000000 loops=1)
         Sort Key: p.p_name
         Sort Method: external merge  Disk: 18536kB
         ->  Hash Join  (cost=32789.00..73661.00 rows=1000000 width=9) (actual time=1877.609..5008.308 rows=1000000 loops=1)
               Hash Cond: (o.p_id = p.p_id)
               ->  Seq Scan on o  (cost=0.00..14425.00 rows=1000000 width=4) (actual time=0.013..870.486 rows=1000000 loops=1)
               ->  Hash  (cost=15406.00..15406.00 rows=1000000 width=13) (actual time=1875.477..1875.477 rows=1000000 loops=1)
                     Buckets: 131072  Batches: 16  Memory Usage: 3961kB
                     ->  Seq Scan on p  (cost=0.00..15406.00 rows=1000000 width=13) (actual time=0.008..874.881 rows=1000000 loops=1)
 Planning time: 0.221 ms
 Execution time: 12177.703 ms
(12 rows)


explain analyze SELECT p_name FROM p JOIN o USING(p_id) group by p.p_id;
                                                               QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------------------
 Group  (cost=127758.26..156331.04 rows=1000000 width=13) (actual time=2065.673..7960.982 rows=245381 loops=1)
   Group Key: p.p_id
   ->  Merge Join  (cost=127758.26..153831.04 rows=1000000 width=13) (actual time=2065.669..6921.160 rows=1000000 loops=1)
         Merge Cond: (p.p_id = o.p_id)
         ->  Index Scan using p_pkey on p  (cost=0.42..31389.42 rows=1000000 width=13) (actual time=0.008..260.385 rows=250000 loops=1)
         ->  Materialize  (cost=127757.34..132757.34 rows=1000000 width=4) (actual time=2065.651..4746.943 rows=1000000 loops=1)
               ->  Sort  (cost=127757.34..130257.34 rows=1000000 width=4) (actual time=2065.632..3135.293 rows=1000000 loops=1)
                     Sort Key: o.p_id
                     Sort Method: external merge  Disk: 13632kB
                     ->  Seq Scan on o  (cost=0.00..14425.00 rows=1000000 width=4) (actual time=0.011..853.638 rows=1000000 loops=1)
 Planning time: 0.208 ms
 Execution time: 8163.418 ms
(12 rows)

```

[SQL Performance of Join and Where Exists](https://danmartensen.svbtle.com/sql-performance-of-join-and-where-exists)

