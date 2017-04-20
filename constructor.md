
## Array Constructors
An array constructor is an **expression** that builds an array value using values for its member elements.

```sql
SELECT ARRAY[1,2,3+4];
SELECT ARRAY[1,2,3+4]::int[];
```
Multidimensional array:

```sql
SELECT ARRAY[ARRAY[1,2], ARRAY[3,4]];

CREATE TABLE arr(f1 int[], f2 int[]);

INSERT INTO arr VALUES (ARRAY[[1,2],[3,4]], ARRAY[[5,6],[7,8]]);

SELECT ARRAY[f1, f2, '{{9,10},{11,12}}'::int[]] FROM arr;
```

you must explicitly cast your empty array to the desired type:
```sql
SELECT ARRAY[]::integer[];
```

construct an array from the results of a subquery
```sql
SELECT ARRAY(SELECT oid FROM pg_proc WHERE proname LIKE 'bytea%');
SELECT ARRAY(SELECT ARRAY[i, i*2] FROM generate_series(1,5) AS a(i));
```

## Row Constructors
 row constructor is an expression that builds a row value (also called a composite value) using values for its member fields
 
```sql 
 SELECT ROW(1,2.5,'this is a test');
 
 SELECT ROW(t.*, 42) FROM t;
 SELECT ROW(t.f1, t.f2, 42) FROM t;
 
 SELECT ROW(1,2.5,'this is a test') = ROW(1, 3, 'not the same');
 SELECT ROW(table.*) IS NULL FROM table;  -- detect all-null rows
```
