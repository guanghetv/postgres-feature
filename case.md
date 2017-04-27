# CASE

```sql
select date,
       sum(case when type = 'OSX' then val end) as osx,
       sum(case when type = 'Windows' then val end) as windows,
       sum(case when type = 'Linux' then val end) as linux
from daily_visits_per_os
group by date
order by date
limit 4;
```

multiple order dimension in one dataset

```sql
select * from batting order by case when player = 'A' then year end desc, case when player = 'B' then homeruns end, case when player = 'C' then team end;
 player | year |  team   | homeruns
--------+------+---------+----------
 B      | 2004 | Yankees |       29
 B      | 2002 | Yankees |       39
 B      | 2001 | Yankees |       42
 B      | 2003 | Yankees |       42
 C      | 2005 | Red Sox |        9
 C      | 2004 | Red Sox |        6
 C      | 2002 | Yankees |        2
 C      | 2003 | Yankees |        3
 A      | 2005 | Red Sox |       11
 A      | 2004 | Red Sox |       14
 A      | 2003 | Red Sox |       19
 A      | 2002 | Red Sox |       23
 A      | 2001 | Red Sox |       13
(13 rows)
```