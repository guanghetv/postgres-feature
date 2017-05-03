# Query Plan

order by下推，利用merge join实现更快的连接

postgres=> explain select * from t1,t2 where t1.b1=t2.b2 order by b1;
                            QUERY PLAN
------------------------------------------------------------------
 Merge Join  (cost=126.45..136.22 rows=1 width=16)
   Merge Cond: (t1.b1 = t2.b2)
   ->  Sort  (cost=61.62..64.00 rows=952 width=8)
         Sort Key: t1.b1
         ->  Seq Scan on t1  (cost=0.00..14.52 rows=952 width=8)
   ->  Sort  (cost=64.83..67.33 rows=1000 width=8)
         Sort Key: t2.b2
         ->  Seq Scan on t2  (cost=0.00..15.00 rows=1000 width=8)
(8 rows)



表扫描方式

postgres=> explain select * from t1 ;
                     QUERY PLAN
-----------------------------------------------------
 Seq Scan on t1  (cost=0.00..14.52 rows=952 width=8)

 获取较准确的 count(*)大小 tricky


 Tid scan，通过page号和item号直接定位到物理数据
postgres=> explain select * from t1 where ctid='(1,10)';
                    QUERY PLAN
--------------------------------------------------
 Tid Scan on t1  (cost=0.00..4.01 rows=1 width=8)
   TID Cond: (ctid = '(1,10)'::tid)


选择度计算
全表扫描选择度计算
全表扫描时每条记录都会返回，所以选择度为1，所以rows=10000

EXPLAIN SELECT * FROM tenk1;

                         QUERY PLAN
-------------------------------------------------------------
 Seq Scan on tenk1  (cost=0.00..458.00 rows=10000 width=244)


 SELECT relpages, reltuples FROM pg_class WHERE relname = 'tenk1';

 relpages | reltuples
----------+-----------
      358 |     10000


[PG优化器](http://mysql.taobao.org/monthly/2017/02/07/)
      