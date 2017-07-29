# Query Plan


```sql
 SELECT relpages, reltuples FROM pg_class WHERE relname = 'product';
 relpages | reltuples
----------+-----------
     5406 |     1e+06


explain  select * from product;
                            QUERY PLAN
------------------------------------------------------------------
 Seq Scan on product  (cost=0.00..15406.00 rows=1000000 width=13)

-- The estimated cost is computed as (disk pages read * seq_page_cost) + (rows scanned * cpu_tuple_cost). By default, seq_page_cost is 1.0 and cpu_tuple_cost is 0.01, so the estimated cost is 
(5406 * 1.0) + (1e+06 * 0.01) = 15406.

```

      