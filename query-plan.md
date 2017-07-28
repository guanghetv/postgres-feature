# Query Plan


```sql
 SELECT relpages, reltuples FROM pg_class WHERE relname = 'product';
 relpages | reltuples
----------+-----------
     5406 |     1e+06

```


[PG优化器](http://mysql.taobao.org/monthly/2017/02/07/)
      