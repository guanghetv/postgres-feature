# Table Join



## LEFT JOIN

```sql
CREATE TABLE a (id int, name text);
CREATE TABLE b (id int, city text) ;

INSERT INTO a VALUES (1, 'jack'), (2, 'jone');
INSERT INTO b VALUES (1, 'cd');

SELECT * FROM a LEFT join b on a.id = b.id;
+------+--------+--------+--------+
|   id | name   |     id | city   |
|------+--------+--------+--------|
|    1 | jack   |      1 | cd     |
|    2 | jone   | <null> | <null> |
+------+--------+--------+--------+

INSERT INTO b VALUES (1, 'kunmin');
SELECT * FROM a LEFT join b on a.id = b.id;
+------+--------+--------+--------+
|   id | name   |     id | city   |
|------+--------+--------+--------|
|    1 | jack   |      1 | cd     |
|    1 | jack   |      1 | kunmin |
|    2 | jone   | <null> | <null> |
+------+--------+--------+--------+

INSERT INTO b VALUES (3, 'tibet');

SELECT * FROM a LEFT join b on a.id = b.id;
+------+--------+--------+--------+
|   id | name   |     id | city   |
|------+--------+--------+--------|
|    1 | jack   |      1 | cd     |
|    1 | jack   |      1 | kunmin |
|    2 | jone   | <null> | <null> |
+------+--------+--------+--------+

-- 不会显示所有表a的数据

SELECT * FROM a LEFT join b on a.id = b.id
WHERE b.city = 'kunmin';
+------+--------+------+--------+
|   id | name   |   id | city   |
|------+--------+------+--------|
|    1 | jack   |    1 | kunmin |
+------+--------+------+--------+

```


## SEMI JOIN
A Semi Join is a specific form of a join, which only takes the keys of relation a into account if these are also present in the associated table b. An Anti Join is the negative form of a Semi Join: that is, a key picked in table a will be taken into account if it is not present in table b.

```sql
EXPLAIN SELECT * FROM a WHERE exists (SELECT 1 from b where id = a.id);
+-------------------------------------------------------------+
| QUERY PLAN                                                  |
|-------------------------------------------------------------|
| Hash Semi Join  (cost=1.07..2.12 rows=2 width=36)           |
|   Hash Cond: (a.id = b.id)                                  |
|   ->  Seq Scan on a  (cost=0.00..1.02 rows=2 width=36)      |
|   ->  Hash  (cost=1.03..1.03 rows=3 width=4)                |
|         ->  Seq Scan on b  (cost=0.00..1.03 rows=3 width=4) |
+-------------------------------------------------------------+

```

The reduced costs of this query plan are more than obvious - and lower costs mean fewer I/O accesses. So, in future a more detailed analysis of such queries is worth a look


## ANTI JOIN
```sql
EXPLAIN SELECT * FROM a WHERE id not in (select id from b);
+---------------------------------------------------------+
| QUERY PLAN                                              |
|---------------------------------------------------------|
| Seq Scan on a  (cost=1.04..2.06 rows=1 width=36)        |
|   Filter: (NOT (hashed SubPlan 1))                      |
|   SubPlan 1                                             |
|     ->  Seq Scan on b  (cost=0.00..1.03 rows=3 width=4) |
+---------------------------------------------------------+

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


## merge JOIN
```sql
EXPLAIN SELECT count(*) from "user" u JOIN "videoStatusMathMiddleLocal" vs on vs."userId" = u.id ;
+-------------------------------------------------------------------------------------------------------------------------------------------------------+
| QUERY PLAN                                                                                                                                            |
|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| Aggregate  (cost=4691.24..4691.25 rows=1 width=8)                                                                                                     |
|   ->  Merge Join  (cost=184.41..4664.20 rows=10815 width=0)                                                                                           |
|         Merge Cond: (u.id = vs."userId")                                                                                                              |
|         ->  Index Only Scan using user_pkey on "user" u  (cost=0.43..750666.80 rows=6075295 width=16)                                                 |
|         ->  Index Only Scan using "videoStatusMathMiddleLocal_userId_idx" on "videoStatusMathMiddleLocal" vs  (cost=0.29..699.37 rows=10815 width=16) |
+-------------------------------------------------------------------------------------------------------------------------------------------------------+

```

[Sort Merge](http://use-the-index-luke.com/sql/join/sort-merge-join)



## Hash JOIN
```sql
EXPLAIN SELECT count(*) from "user" u LEFT JOIN "videoStatusMathMiddleLocal" vs on vs."userId" = u.id ;
+--------------------------------------------------------------------------------------------------+
| QUERY PLAN                                                                                       |
|--------------------------------------------------------------------------------------------------|
| Aggregate  (cost=365687.83..365687.84 rows=1 width=8)                                            |
|   ->  Hash Right Join  (cost=320313.14..350499.59 rows=6075295 width=0)                          |
|         Hash Cond: (vs."userId" = u.id)                                                          |
|         ->  Seq Scan on "videoStatusMathMiddleLocal" vs  (cost=0.00..199.15 rows=10815 width=16) |
|         ->  Hash  (cost=214706.95..214706.95 rows=6075295 width=16)                              |
|               ->  Seq Scan on "user" u  (cost=0.00..214706.95 rows=6075295 width=16)             |
+--------------------------------------------------------------------------------------------------+

```




