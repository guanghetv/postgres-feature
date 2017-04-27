
## tune tricks

#### TABLESAMPLE - get table row count faster

```sql

SELECT 100 * count(*) AS estimate FROM mytable TABLESAMPLE SYSTEM (1);
-- TABLESAMPLE SYSTEM (1) is similiar to "select * from foo where random()<0.01".

```