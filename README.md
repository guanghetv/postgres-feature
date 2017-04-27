


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






## PostgreSQL中文全文检索

[参考 PostgreSQL + SCWS + zhparser + Rails4 + pg_search 实现中文全文检索](http://www.racksam.com/2016/05/03/chinese-full-text-searching-with-postgresql-zhparser-and-rails/)




## Block-range indexes

uuid



##
diverse set of indexes

使用 tmp table 优化 分布式 join查询



## Phrase search
[参考 WAITING FOR 9.6 – PHRASE FULL TEXT SEARCH.](https://www.depesz.com/2016/04/22/waiting-for-9-6-phrase-full-text-search/)



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





