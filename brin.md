
# BRIN

BRIN Indexing: This new type of index supports creating tiny, but effective indexes for very large, "naturally ordered" tables. For example, tables containing logging data with billions of rows could be indexed and searched in 5% of the time required by standard BTree indexes.

[参考 BRIN Indexes](https://www.postgresql.org/docs/9.5/static/brin-intro.html)


## 微观查询（行为、轨迹明细）的痛点

为了提升数据的入库速度，通常我们会使用堆表存储，堆表存储的最大特点是写入极其之快，通常一台普通服务器能做到GB/s的写入速度，但是，如果你要频繁根据用户ID查询他产生的轨迹数据的话，会涉及大量的离散IO。查询性能也许就不如写入性能了。

PostgreSQL 的表使用的是堆存储，插入时根据FSM和空间搜索算法寻找合适的数据块，记录插入到哪个数据块是不受控制的。

FSM算法参考

src/backend/storage/freespace/README

这种方法是一次性的，并不是实时的

Command:     CLUSTER  
Description: cluster a table according to an index  
Syntax:  
CLUSTER [VERBOSE] table_name [ USING index_name ]  
CLUSTER [VERBOSE] 

每个小时对前一个小时的数据使用cluster，对堆表按被跟踪对象的唯一标识进行聚集处理




3. 通过查询物理行号、记录，确认离散度

select ctid,* from test where id=1;

explain (analyze,verbose,timing,costs,buffers) select * from cluster_test_brin where id=1;

\di+ idx_cluster_test_brin_id 

bitmapscan 隐含了ctid (离散度)sort，所以启动时间就耗费了7.4毫秒