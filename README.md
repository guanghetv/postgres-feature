


# Prepare
https://www.postgresql.org/docs/9.0/static/sql-prepare.html



# data OP

```sql
-- table copy
select * into newtable from oldtable

```



# CPU IO waiting - load average




## tune tricks

#### TABLESAMPLE - get table row count faster

```sql

SELECT 100 * count(*) AS estimate FROM mytable TABLESAMPLE SYSTEM (1);
-- TABLESAMPLE SYSTEM (1) is similiar to "select * from foo where random()<0.01".

```





## MVCC

[参考 MVCC PostgreSQL实现事务和多版本并发控制的精华](http://www.jasongj.com/sql/mvcc/)



## PostgreSQL中文全文检索

[参考 PostgreSQL + SCWS + zhparser + Rails4 + pg_search 实现中文全文检索](http://www.racksam.com/2016/05/03/chinese-full-text-searching-with-postgresql-zhparser-and-rails/)




## Block-range indexes

uuid

[参考 BRIN Indexes](https://www.postgresql.org/docs/9.5/static/brin-intro.html)


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




## Phrase search
[参考 WAITING FOR 9.6 – PHRASE FULL TEXT SEARCH.](https://www.depesz.com/2016/04/22/waiting-for-9-6-phrase-full-text-search/)


## Materialized views

Use materialized views cautiously
If you’re not familiar with materialized view they’re a query that has been actually created as a table. So it’s a materialized or basically snapshotted version of some query or “view”. In their initial version materialized versions, which were long requested in Postgres, were entirely unusuable because when you it was a locking transaction which could hold up other reads and acticities avainst that view.
They’ve since gotten much better, but there’s no tooling for refreshing them out of the box. This means you have to setup some scheduler job or cron job to regularly refresh your materialized views. If you’re building some reporting or BI app you may undoubtedly need them, but their usability could still be advanced so that Postgres knew how to more automatically refresh them.


## A simpler method for pivot tables

Table_func is often referenced as the way to compute a pivot table in Postgres. Sadly though it’s pretty difficult to use, and the more basic method would be to just do it with raw SQL. This will get much better with Postgres 9.5, but until then something where you sum up each condition where it’s true or false and then totals is much simpler to reason about:


select date,
       sum(case when type = 'OSX' then val end) as osx,
       sum(case when type = 'Windows' then val end) as windows,
       sum(case when type = 'Linux' then val end) as linux
from daily_visits_per_os
group by date
order by date
limit 4;

http://www.craigkerstiens.com/2014/02/26/Tracking-MoM-growth-in-SQL/


## PostGIS

earth_distance extension

GiST indexes





