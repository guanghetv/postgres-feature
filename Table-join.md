# Table Join



## left join

```sql
CREATE TABLE a (id int, name text);
CREATE TABLE b (id int, city text) ;

INSERT INTO a VALUES (1, 'jack'), (2, 'jone');
INSERT INTO b VALUES (1, 'cd');

SELECT * FROM a LEFT join b on a.id = b.id;
+------+--------+--------+--------+
|   id | name   |     id | city   |
|------+--------+--------+--------|
|    1 | jack   |      1 | cd     |
|    2 | jone   | <null> | <null> |
+------+--------+--------+--------+

INSERT INTO b VALUES (1, 'kunmin');
SELECT * FROM a LEFT join b on a.id = b.id;
+------+--------+--------+--------+
|   id | name   |     id | city   |
|------+--------+--------+--------|
|    1 | jack   |      1 | cd     |
|    1 | jack   |      1 | kunmin |
|    2 | jone   | <null> | <null> |
+------+--------+--------+--------+

INSERT INTO b VALUES (3, 'tibet');

SELECT * FROM a LEFT join b on a.id = b.id;
+------+--------+--------+--------+
|   id | name   |     id | city   |
|------+--------+--------+--------|
|    1 | jack   |      1 | cd     |
|    1 | jack   |      1 | kunmin |
|    2 | jone   | <null> | <null> |
+------+--------+--------+--------+

-- 不会显示所有表a的数据

SELECT * FROM a LEFT join b on a.id = b.id
WHERE b.city = 'kunmin';
+------+--------+------+--------+
|   id | name   |   id | city   |
|------+--------+------+--------|
|    1 | jack   |    1 | kunmin |
+------+--------+------+--------+

-- 会显示所有表a的数据

SELECT * FROM a LEFT join b on a.id = b.id
WHERE a.name like 'j%';
+------+--------+--------+--------+
|   id | name   |     id | city   |
|------+--------+--------+--------|
|    1 | jack   |      1 | cd     |
|    1 | jack   |      1 | kunmin |
|    2 | jone   | <null> | <null> |
+------+--------+--------+--------+

```


## SEMI JOIN
