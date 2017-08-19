
# Performance Monitoring

Total number of connections
This will tell you how close you are to hitting your max_connections limit, and show up any clients which are leaking database connections.

SELECT count(*) FROM pg_stat_activity;
Number of connections by state
This query breaks down connections by state:

```sql
SELECT state, count(*) FROM pg_stat_activity GROUP BY state;

```

The possible states of interest are:

active
Connections currently executing queries. A large number tends to indicate DB slowness.
idle
Idle connections, not in a transaction.
idle in transaction
Connections with an open transaction, not executing a query. Lots of these can indicate long-running transactions.
idle in transaction (aborted)
Connection is in a transaction, but an error has occurred and the transaction hasn’t been rolled back.
Connections waiting for a lock
The number of connections blocked waiting for a lock can be an indicator of a slow transaction with an exclusive lock.

```sql
SELECT count(distinct pid) FROM pg_locks WHERE granted = false;
```

Maximum transaction age
Long-running transactions are bad because they prevent Postgres from vacuuming old data. 
This causes database bloat and, in extreme circumstances, shutdown due to transaction ID (xid) wraparound. 
Transactions should be kept as short as possible, ideally less than a minute.

Alert if this number gets greater than an hour or so.

```sql
SELECT max(now() - xact_start) FROM pg_stat_activity
                               WHERE state IN ('idle in transaction', 'active');

SELECT
    pg_size_pretty(pg_database_size(pg_database.datname)) AS size,
    pg_database.datname
    FROM pg_database;

-- view

CREATE OR REPLACE VIEW disk_usage AS
 SELECT pg_namespace.nspname AS schema, pg_class.relname AS relation,
    pg_size_pretty(pg_total_relation_size(pg_class.oid::regclass)) AS size,
    COALESCE(pg_stat_user_tables.seq_scan + pg_stat_user_tables.idx_scan, 0) AS scans
   FROM pg_class
   LEFT JOIN pg_stat_user_tables ON pg_stat_user_tables.relid = pg_class.oid
   LEFT JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
  WHERE pg_class.relkind = 'r'::"char"
  AND pg_namespace.nspname NOT IN ('pg_catalog', 'information_schema')
  ORDER BY pg_total_relation_size(pg_class.oid::regclass) DESC;

onion=> select * from disk_usage ;
 schema |         relation          | size  | scans
--------+---------------------------+-------+-------
 public | videoStatusMathHigh       | 14 GB |   163
 public | videoStatusMathHigh_noidx | 16 kB |     0

```

## pg_stat_statements
The pg_stat_statements module provides a means for tracking execution statistics of all 
SQL statements executed by a server

```sql
SELECT total_time/calls as time, *
FROM pg_stat_statements ORDER BY time DESC LIMIT 10;

```

[pg_stat_statements](https://www.postgresql.org/docs/9.3/static/pgstatstatements.html)




pg_buffercache - (版本 9.4.5 和更高版本) 提供一种实时检查共享缓冲区缓存中发生的情况的方法。
每台 PostgreSQL 服务器都使用一定数量的缓冲区。缓冲区数量由 shared_buffer_space 参数（可以进行配置）
和缓冲区数据块大小参数（客户无法配置）决定。例如，如果服务器具有 128MB 的 shared_buffer_space，
并且每个数据块的大小是 8 KB，则系统中总共有 16384 个缓冲区。借助此扩展，您可以查看服务器上缓存了哪些表/关系。
通过服务器上缓存的数据可以更快执行查询或其他操作，因为数据在内存中进行缓存，无需从磁盘加载

[pg_buffercache](https://www.postgresql.org/docs/9.1/static/pgbuffercache.html)


## Lock Check

```sql
SELECT blocked_locks.pid     AS blocked_pid,
         blocked_activity.usename  AS blocked_user,
         blocking_locks.pid     AS blocking_pid,
         blocking_activity.usename AS blocking_user,
         blocked_activity.query    AS blocked_statement,
         blocking_activity.query   AS current_statement_in_blocking_process
   FROM  pg_catalog.pg_locks         blocked_locks
    JOIN pg_catalog.pg_stat_activity blocked_activity  ON blocked_activity.pid = blocked_locks.pid
    JOIN pg_catalog.pg_locks         blocking_locks
        ON blocking_locks.locktype = blocked_locks.locktype
        AND blocking_locks.DATABASE IS NOT DISTINCT FROM blocked_locks.DATABASE
        AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
        AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
        AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
        AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
        AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
        AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
        AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
        AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
        AND blocking_locks.pid != blocked_locks.pid
    JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
   WHERE NOT blocked_locks.GRANTED;

 ```



