# VACUUM

```sql
update test_bloat set a = 1;

\watch 1

-- 过不多久，查看表的大小就会发现它不断增大：

\dt+ test_bloat

```

```sql
begin ;
insert into test_bloat values(1);

-- 查看事务状态如下

select * from pg_stat_activity;

```

可以发现，它有两个特点：

它的状态为“idle in transaction”，这是因为它未提交，又没有正在进行的查询；
它的backend_xid不为空，即它有事务号，这是因为它执行了更新操作，插入了一条数据。注意，PG只在发生更新的时候才分配事务ID，没有执行更新操作的事务（即只读事务）是没有backend_xid的


[表膨胀](http://mysql.taobao.org/monthly/2015/12/07/)