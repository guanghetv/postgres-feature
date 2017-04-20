
# Calling Functions

## named/positional notation
```sql
CREATE FUNCTION concat_lower_or_upper(a text, b text, uppercase boolean DEFAULT false)
RETURNS text
AS
$$
 SELECT CASE
        WHEN $3 THEN UPPER($1 || ' ' || $2)
        ELSE LOWER($1 || ' ' || $2)
        END;
$$
LANGUAGE SQL IMMUTABLE STRICT;

SELECT concat_lower_or_upper('Hello', 'World', true);
SELECT concat_lower_or_upper(a => 'Hello', b => 'World', uppercase => true);
+-------------------------+
| concat_lower_or_upper   |
|-------------------------|
| HELLO WORLD             |
+-------------------------+
```