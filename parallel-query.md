
# Parallel JOIN, aggregate

set max_parallel_workers_per_gather to 8 ;
show max_parallel_workers_per_gather ;

```sql
explain analyze select count(*) from "user" u inner join "dailySignin" d on d.name = u.name;

                                                                          QUERY PLAN
---------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize Aggregate  (cost=1214278.97..1214278.98 rows=1 width=8) (actual time=60989.651..60989.652 rows=1 loops=1)
   ->  Gather  (cost=1214278.25..1214278.96 rows=7 width=8) (actual time=60962.915..60989.628 rows=8 loops=1)
         Workers Planned: 7
         Workers Launched: 7
         ->  Partial Aggregate  (cost=1213278.25..1213278.26 rows=1 width=8) (actual time=60741.495..60741.497 rows=1 loops=8)
               ->  Hash Join  (cost=320257.10..1210927.94 rows=940122 width=0) (actual time=39614.448..59028.595 rows=780059 loops=8)
                     Hash Cond: ((d.name)::text = (u.name)::text)
                     ->  Parallel Seq Scan on "dailySignin" d  (cost=0.00..797923.31 rows=2716331 width=11) (actual time=0.128..9681.567 rows=2376975 loops=8)
                     ->  Hash  (cost=214686.49..214686.49 rows=6073249 width=11) (actual time=36794.569..36794.569 rows=3395758 loops=8)
                           Buckets: 131072  Batches: 128  Memory Usage: 2138kB
                           ->  Seq Scan on "user" u  (cost=0.00..214686.49 rows=6073249 width=11) (actual time=0.065..19564.054 rows=6075295 loops=8)
 Planning time: 0.373 ms
 Execution time: 61076.038 ms
(13 rows)

set max_parallel_workers_per_gather to 0 ;

explain analyze  select count(*) from "user" u inner join "dailySignin" d on d.nickname = u.nickname;

30m+

```

[参考 WAITING FOR 9.6 – SUPPORT PARALLEL AGGREGATION.](https://www.depesz.com/2016/03/23/waiting-for-9-6-support-parallel-aggregation/)
