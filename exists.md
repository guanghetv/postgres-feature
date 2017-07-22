
## Semi Join

A “semi-join” between two tables returns rows from the first table
where one or more matches are found in the second table.
The difference between a semi-join and a conventional join is that rows in the first table 
will be returned at most once. 
Even if the second table contains two matches for a row in the first table, 
only one copy of the row will be returned.


获取下过订单的产品列表

```sql
CREATE TABLE product
(
    id serial PRIMARY KEY,
    name character varying UNIQUE
);

INSERT INTO product (name)
    SELECT substr(gen_salt('md5'), 4)
    FROM generate_series(1, 1000000);


CREATE TABLE "order"
(
    id serial PRIMARY KEY,
    product_id integer REFERENCES product (id)
);

INSERT INTO "order" (product_id)
select (random() * 249999 + 1) rnd_val from generate_series(1, 1000000);


-- exists
explain analyze select name
FROM product
where exists (select 1 from "order" where product_id = product.id);
                                                          QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------------
 Hash Semi Join  (cost=30835.00..77063.93 rows=211193 width=9) (actual time=375.388..1177.357 rows=245541 loops=1)
   Hash Cond: (product.id = "order".product_id)
   ->  Seq Scan on product  (cost=0.00..15406.00 rows=1000000 width=13) (actual time=0.007..145.095 rows=1000000 loops=1)
   ->  Hash  (cost=14428.00..14428.00 rows=1000000 width=4) (actual time=375.268..375.268 rows=1000000 loops=1)
         Buckets: 16384  Batches: 16  Memory Usage: 2233kB
         ->  Seq Scan on "order"  (cost=0.00..14428.00 rows=1000000 width=4) (actual time=0.006..137.877 rows=1000000 loops=1)
 Planning time: 0.220 ms
 Execution time: 1188.738 ms


-- DISTINCT
explain analyze SELECT DISTINCT name FROM product JOIN "order" on "order".product_id = product.id;
                                                                 QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------------------------
 Unique  (cost=194162.34..199162.34 rows=1000000 width=9) (actual time=3578.059..4393.204 rows=245541 loops=1)
   ->  Sort  (cost=194162.34..196662.34 rows=1000000 width=9) (actual time=3578.056..4235.666 rows=1000000 loops=1)
         Sort Key: product.name
         Sort Method: external merge  Disk: 18520kB
         ->  Hash Join  (cost=32789.00..77414.00 rows=1000000 width=9) (actual time=402.306..1498.182 rows=1000000 loops=1)
               Hash Cond: ("order".product_id = product.id)
               ->  Seq Scan on "order"  (cost=0.00..14428.00 rows=1000000 width=4) (actual time=0.008..144.660 rows=1000000 loops=1)
               ->  Hash  (cost=15406.00..15406.00 rows=1000000 width=13) (actual time=402.165..402.165 rows=1000000 loops=1)
                     Buckets: 16384  Batches: 16  Memory Usage: 2949kB
                     ->  Seq Scan on product  (cost=0.00..15406.00 rows=1000000 width=13) (actual time=0.005..150.024 rows=1000000 loops=1)
 Planning time: 0.222 ms
 Execution time: 4412.932 ms


-- group by
explain analyze SELECT name FROM product JOIN "order" on "order".product_id = product.id group by product.id;
                                                                    QUERY PLAN
---------------------------------------------------------------------------------------------------------------------------------------------------
 Group  (cost=127762.16..156126.71 rows=1000000 width=13) (actual time=860.851..1812.730 rows=245541 loops=1)
   Group Key: product.id
   ->  Merge Join  (cost=127762.16..153626.71 rows=1000000 width=13) (actual time=860.849..1669.415 rows=1000000 loops=1)
         Merge Cond: (product.id = "order".product_id)
         ->  Index Scan using product_pkey on product  (cost=0.42..31389.42 rows=1000000 width=13) (actual time=0.011..78.954 rows=250000 loops=1)
         ->  Materialize  (cost=127760.34..132760.34 rows=1000000 width=4) (actual time=860.831..1323.222 rows=1000000 loops=1)
               ->  Sort  (cost=127760.34..130260.34 rows=1000000 width=4) (actual time=860.826..1179.622 rows=1000000 loops=1)
                     Sort Key: "order".product_id
                     Sort Method: external merge  Disk: 13616kB
                     ->  Seq Scan on "order"  (cost=0.00..14428.00 rows=1000000 width=4) (actual time=0.011..167.008 rows=1000000 loops=1)
 Planning time: 0.217 ms
 Execution time: 1832.902 ms


```



## ANTI JOIN

```sql

-- slow way
explain analyze select * from product where id not in (select product_id from "order");


-- fast way
EXPLAIN analyze SELECT * from product WHERE not exists (SELECT 1 from "order" WHERE product_id = product.id);
                                                          QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------------
 Hash Anti Join  (cost=30835.00..82840.07 rows=788807 width=13) (actual time=380.550..1113.016 rows=754459 loops=1)
   Hash Cond: (product.id = "order".product_id)
   ->  Seq Scan on product  (cost=0.00..15406.00 rows=1000000 width=13) (actual time=0.006..102.650 rows=1000000 loops=1)
   ->  Hash  (cost=14428.00..14428.00 rows=1000000 width=4) (actual time=380.202..380.202 rows=1000000 loops=1)
         Buckets: 16384  Batches: 16  Memory Usage: 2233kB
         ->  Seq Scan on "order"  (cost=0.00..14428.00 rows=1000000 width=4) (actual time=0.007..137.120 rows=1000000 loops=1)
 Planning time: 0.200 ms
 Execution time: 1155.439 ms


-- Another fast way
EXPLAIN analyze SELECT * FROM product left join "order" on product_id = product.id WHERE product_id isnull;
                                                          QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------------
 Hash Anti Join  (cost=30835.00..82840.07 rows=788807 width=21) (actual time=303.934..1061.933 rows=754459 loops=1)
   Hash Cond: (product.id = "order".product_id)
   ->  Seq Scan on product  (cost=0.00..15406.00 rows=1000000 width=13) (actual time=0.006..110.138 rows=1000000 loops=1)
   ->  Hash  (cost=14428.00..14428.00 rows=1000000 width=8) (actual time=303.611..303.611 rows=1000000 loops=1)
         Buckets: 16384  Batches: 16  Memory Usage: 2481kB
         ->  Seq Scan on "order"  (cost=0.00..14428.00 rows=1000000 width=8) (actual time=0.006..102.669 rows=1000000 loops=1)
 Planning time: 0.203 ms
 Execution time: 1097.430 ms

```



## Use the EXISTS key word for TRUE / FALSE return


```sql
select exists(select 1 from product where id=1);
 exists
--------
 t
(1 row)

```

## Any/All

```sql
EXPLAIN  SELECT * FROM product WHERE id in (1,2);
                                  QUERY PLAN
------------------------------------------------------------------------------
 Index Scan using product_pkey on product  (cost=0.42..12.88 rows=2 width=13)
   Index Cond: (id = ANY ('{1,2}'::integer[]))


EXPLAIN  SELECT * FROM product WHERE id = any(ARRAY[1,2]);                                                                                                                                                                             QUERY PLAN
------------------------------------------------------------------------------
 Index Scan using product_pkey on product  (cost=0.42..12.88 rows=2 width=13)
   Index Cond: (id = ANY ('{1,2}'::integer[]))


EXPLAIN  SELECT * FROM product WHERE id not in (1,2);
                           QUERY PLAN
-----------------------------------------------------------------
 Seq Scan on product  (cost=0.00..17906.00 rows=999998 width=13)
   Filter: (id <> ALL ('{1,2}'::integer[]))


EXPLAIN  SELECT * FROM product WHERE id <> all(ARRAY[1,2]);
                           QUERY PLAN
-----------------------------------------------------------------
 Seq Scan on product  (cost=0.00..17906.00 rows=999998 width=13)
   Filter: (id <> ALL ('{1,2}'::integer[]))

```


