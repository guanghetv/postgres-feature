
# Returning Hierarchical Data in a Single SQL Query

```sql
CREATE TABLE employee (
  employee_id INT PRIMARY KEY,
  name TEXT NOT NULL
);

CREATE TABLE project (
  project_id INT PRIMARY KEY,
  employee_id INT NOT NULL REFERENCES employee(employee_id),
  name text NOT NULL
);

INSERT INTO employee VALUES
    (1, 'Jon Snow'),
    (2, 'Thoren Smallwood'),
    (3, 'Samwell Tarley')

INSERT INTO project VALUES
    (1, 1, $$Infiltrate Mance Rayder's Camp$$),
    (2, 3, $$Research the Wights$$)
    
```

row_to_json provides the ability to turn a database row into a json object, which is the key:

```sql
SELECT
  p.*,
  row_to_json(e.*) as employee
FROM project p
INNER JOIN employee e USING(employee_id)
```

Sometimes it is necessary to return additional fields along with a given object that may not be directly included in the database table

```sql
ALTER TABLE project ADD COLUMN dateassigned DATE;

UPDATE project SET dateassigned = '2013/09/10' WHERE project_id = 1;
UPDATE project SET dateassigned = '2013/09/16' WHERE project_id = 2;

INSERT INTO project (project_id, employee_id, name, dateassigned)
VALUES (3, 3, 'Send a raven to Kings Landing', '2013/09/21');
INSERT INTO project (project_id, employee_id, name, dateassigned)
VALUES (4, 2, 'Scout wildling movement', '2013/09/01');

-- CTE
WITH project AS (
  SELECT
    p.*,
    date_part('epoch', age(now(), dateassigned::timestamp)) as time
  FROM project p
)

SELECT
  e.employee_id,
  e.name,
  json_agg(p.*) as projects
FROM employee e
INNER JOIN project p USING (employee_id)
WHERE employee_id = 3
GROUP BY e.employee_id, e.name
```

## Recursive Common Table Expressions

```sql
ALTER TABLE employee ADD COLUMN superior_id INT REFERENCES employee(employee_id);

INSERT INTO employee (employee_id, name, superior_id)
VALUES (4, 'Jeor Mormont', null);
UPDATE employee SET superior_id = 4 WHERE employee_id <> 4;

INSERT INTO employee (employee_id, name, superior_id)
VALUES (5, 'Ghost', 1);
INSERT INTO employee (employee_id, name, superior_id)
VALUES (6, 'Iron Emmett', 1);
INSERT INTO employee (employee_id, name, superior_id)
VALUES (7, 'Hareth', 6);
```
We can now use a recursive CTE (common table expression) to return this tree of data in a single query along with the depth of each node. Recursive CTEs allow you to reference the virtual table within its own definition. They take the form of two queries joined by a union, where one query acts as the terminating condition of the recursion and the other joins to it. Technically they are implemented iteratively in the underlying engine, but it can be useful to think recursively when composing the queries.

```sql
WITH RECURSIVE employeetree AS (
  SELECT e.*, 0 as depth
  FROM employee e
  WHERE e.employee_id = 1

  UNION ALL

  SELECT e.*, t.depth + 1 as depth
  FROM employee e
  INNER JOIN employeetree t
    ON t.employee_id = e.superior_id
)

SELECT * FROM employeetree

 employee_id |    name     | superior_id | depth
-------------+-------------+-------------+-------
           1 | Jon Snow    |           4 |     0
           5 | Ghost       |           1 |     1
           6 | Iron Emmett |           1 |     1
           7 | Hareth      |           6 |     2
```

Combining Everything

```sql
WITH RECURSIVE employeetree AS (
  WITH employeeprojects AS (
    SELECT
      p.employee_id,
      json_agg(p.*) as projects
    FROM (
      SELECT
        p.*,
        date_part('day', age(now(), dateassigned::timestamp)) as age
      FROM project p
    ) AS p
    GROUP BY p.employee_id
  )

  SELECT
    e.*,
    null::json as superior,
    COALESCE(ep.projects, '[]') as projects
  FROM employee e
  LEFT JOIN employeeprojects ep
    USING(employee_id)
  WHERE superior_id IS NULL

  UNION ALL

  SELECT
    e.*,
    row_to_json(sup.*) as superior,
    COALESCE(ep.projects, '[]') as projects
  FROM employee e
  INNER JOIN employeetree sup
    ON sup.employee_id = e.superior_id
  LEFT JOIN employeeprojects ep
    ON ep.employee_id = e.employee_id
)

SELECT *
FROM employeetree
WHERE employee_id = 7
```

[参考 Returning Hierarchical Data in a Single SQL Query](http://bender.io/2013/09/22/returning-hierarchical-data-in-a-single-sql-query/)
