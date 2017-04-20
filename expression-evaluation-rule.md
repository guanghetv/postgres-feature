
## Expression Evaluation Rules
When it is essential to force evaluation order, a CASE construct can be used. For example, this is an untrustworthy way of trying to avoid division by zero in a WHERE clause:

```sql
SELECT ... WHERE x > 0 AND y/x > 1.5;
```

But this is safe:

```sql
SELECT ... WHERE CASE WHEN x > 0 THEN y/x > 1.5 ELSE false END;
```