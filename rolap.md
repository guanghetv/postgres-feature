
# ROLAP

https://en.wikipedia.org/wiki/Online_analytical_processing#Relational_.28ROLAP.29

Each CREATE MATERIALIZED VIEW and REFRESH MATERIALIZED VIEW required a sequential table scan for quite a large fact table and many other, sometimes also large, dimension tables. 
This made my cube refresh process quite lengthy.

With the recent addition to PostgreSQL the task of creating aggregate tables becomes easy. Thanks to GROUPING SETS, ROLLUP and CUBE it is possible not only to create a set of aggregates in one go, but more important, using only one sequential scan. 

https://lwn.net/Articles/653411/

