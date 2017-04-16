
# CREATE TABLE

```sql
CREATE TEMPORARY TABLE tt  (namex text)

\dt
+-----------+---------------+--------+----------+
| Schema    | Name          | Type   | Owner    |
|-----------+---------------+--------+----------|
| pg_temp_3 | tt            | table  | postgres |

INSERT INTO tt VALUES ('xx') ;

SELECT * from tt;
+---------+
| namex   |
|---------|
| xx      |
+---------+

\q
Goodbye!

➜  ~ pgcli

SELECT  * from tt;
relation "tt" does not exist


```