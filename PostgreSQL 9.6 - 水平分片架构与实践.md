
# PostgreSQL 9.6 - 水平分片架构与实践

If you have a lot of microservices or different apps then you likely have a lot of different databases backing them.
The default for about anything you want to do is do create some data warehouse and ETL it all together.
This often goes a bit too far to the extreme of aggregating everything together.
For the times you just need to pull something together once or
on rare occasion foreign data wrappers will let you query from one Postgres database to another,
or potentially from Postgres to anything else such as Mongo or Redis.


## DB data 在不同server上的分布

```sql
onion-t01(course)
onion-t02(user + videoStatus router)
onion-t03(videoStatusMathMiddle)
onion-t04(videoStatusMathHigh)
onion-t05(videoStatusPhysicsHigh)

```

## import data through copy command

课程数据导入onion-t01,用户数据导入onion-t02

```shell
PGPASSWORD=xxx \
psql -h xxx.amazonaws.com.cn -p 5432 -U master -d onion \
-c "\copy user(name,target,nickname,type,gender,email,phone,\"from\",role,_id) \
from '/data/users.csv' \
delimiter as ',' csv header"

```


## foreign data wrapper

将onion-t01的课程数据映射到onion-t02

```sql
create extension postgres_fdw ;

create server course foreign data wrapper postgres_fdw options (
  host 'xxx.amazonaws.com.cn',
  port '5432',
  dbname 'onion'
);

onion=> \des
        List of foreign servers
  Name  | Owner  | Foreign-data wrapper
--------+--------+----------------------
 course | master | postgres_fdw
(1 row)

-- user mapping

create user mapping for master server course options (user 'master', password 'xxx');

onion=> \deu
List of user mappings
 Server | User name
--------+-----------
 course | master

-- import foreign schema

import foreign schema public from server course into public ;

onion=> \det
     List of foreign tables
 Schema |     Table     | Server
--------+---------------+--------
 public | practice      | course
 public | problem       | course
 public | video         | course
 ...

onion=> explain  select * from video where id = 111;
                          QUERY PLAN
---------------------------------------------------------------
 Foreign Scan on video  (cost=100.00..113.30 rows=1 width=288)
(1 row)

```

在分片节点上创建各自的表结构

```sql

-- partition videoStatus by (subject,stage)

CREATE TYPE e_finish_state AS ENUM ('unfinished', 'finished');
CREATE TYPE e_stage AS ENUM ('primary', 'middle', 'high');
CREATE TYPE e_subject AS ENUM ('math', 'physics');

-- onion-t03
CREATE TABLE "videoStatusMathMiddle" (
  "userId" uuid NOT NULL,
  "videoId" integer NOT NULL,
  "state" e_finish_state,
  subject e_subject NOT NULL check (subject='math'),
  stage e_stage NOT NULL check (stage='middle'),
  "finishTime" timestamptz,
  "createTime" timestamptz default current_timestamp,
  PRIMARY KEY ("userId", "videoId")
);

CREATE INDEX "video_status_create_time_idx" ON  "videoStatus" ("createTime");

COMMENT ON COLUMN "videoStatusMathMiddle"."videoId" IS 'REFERENCES can not use on foreign table';
COMMENT ON COLUMN "videoStatusMathMiddle"."userId" IS 'REFERENCES can not use on foreign table';

-- onion-t04

CREATE TABLE "videoStatusMathHigh" (
  "userId" uuid NOT NULL,
  "videoId" integer NOT NULL,
  "state" e_finish_state,
  subject e_subject NOT NULL check (subject='math'),
  stage e_stage NOT NULL check (stage='high'),
  "finishTime" timestamptz,
  "createTime" timestamptz default current_timestamp,
  PRIMARY KEY ("userId", "videoId")
);

CREATE INDEX "video_status_create_time_idx" ON  "videoStatusMathHigh" ("createTime");

COMMENT ON COLUMN "videoStatusMathHigh"."videoId" IS 'REFERENCES can not use on foreign table';
COMMENT ON COLUMN "videoStatusMathHigh"."userId" IS 'REFERENCES can not use on foreign table';

-- onion-t05

CREATE TABLE "videoStatusPhysicsHigh" (
  "userId" uuid NOT NULL,
  "videoId" integer NOT NULL,
  "state" e_finish_state,
  subject e_subject NOT NULL check (subject='physics'),
  stage e_stage NOT NULL check (stage='high'),
  "finishTime" timestamptz,
  "createTime" timestamptz default current_timestamp,
  PRIMARY KEY ("userId", "videoId")
);

CREATE INDEX "video_status_create_time_idx" ON  "videoStatusPhysicsHigh" ("createTime");

```


```sql

/*
 onion-t03(videoStatusMathMiddle)
 onion-t04(videoStatusMathHigh)
 onion-t05(videoStatusPhysicsHigh)
 map to onion-t02
*/

create server "videoStatusMathMiddle" foreign data wrapper postgres_fdw options (
  host 'xxx.amazonaws.com.cn',
  port '5432',
  dbname 'onion'
);

create server "videoStatusMathHigh" foreign data wrapper postgres_fdw options (
  host 'xxx.amazonaws.com.cn',
  port '5432',
  dbname 'onion'
);

create server "videoStatusPhysicsHigh" foreign data wrapper postgres_fdw options (
  host 'xxx.amazonaws.com.cn',
  port '5432',
  dbname 'onion'
);

-- user mapping

create user mapping for master server "videoStatusMathMiddle" options (user 'master', password 'xxx');
create user mapping for master server "videoStatusMathHigh" options (user 'master', password 'xxx');
create user mapping for master server "videoStatusPhysicsHigh" options (user 'master', password 'xxx');
CREATE USER MAPPING

-- import foreign schema

import foreign schema public from server "videoStatusMathMiddle" into public ;
import foreign schema public from server "videoStatusMathHigh" into public ;
import foreign schema public from server "videoStatusPhysicsHigh" into public ;

```


## Partition table with foreign tables

```sql

-- master table(onion-t02)

CREATE TYPE e_finish_state AS ENUM ('unfinished', 'finished');
CREATE TYPE e_stage AS ENUM ('primary', 'middle', 'high');

CREATE TABLE "videoStatus" (
  "userId" uuid REFERENCES "user" (id),
  "videoId" integer NOT NULL,
  "state" e_finish_state,
  subject e_subject NOT NULL,
  stage e_stage NOT NULL,
  "finishTime" timestamptz,
  "createTime" timestamptz default current_timestamp,
  PRIMARY KEY ("userId", "videoId")
);

CREATE INDEX "video_status_create_time_idx" ON  "videoStatus" ("createTime");

COMMENT ON COLUMN "videoStatus"."videoId" IS 'REFERENCES can not use on foreign table';

```

创建分区表

```sql

-- add constraint on foreign table

alter foreign table "videoStatusMathMiddle" add check (subject='math');
alter foreign table "videoStatusMathMiddle" add check (stage='middle');

alter foreign table "videoStatusMathHigh" add check (subject='math');
alter foreign table "videoStatusMathHigh" add check (stage='high');

alter foreign table "videoStatusPhysicsHigh" add check (subject='physics');
alter foreign table "videoStatusPhysicsHigh" add check (stage='high');

-- inherit

alter foreign table "videoStatusMathMiddle" inherit "videoStatus" ;
alter foreign table "videoStatusMathHigh" inherit "videoStatus" ;
alter foreign table "videoStatusPhysicsHigh" inherit "videoStatus" ;
ALTER FOREIGN TABLE

onion=> \d+ "videoStatusMathMiddle"
                                     Foreign table "public.videoStatusMathMiddle"
   Column   |           Type           | Modifiers |        FDW Options         | Storage | Stats target | Description
------------+--------------------------+-----------+----------------------------+---------+--------------+-------------
 userId     | uuid                     | not null  | (column_name 'userId')     | plain   |              |
 videoId    | integer                  | not null  | (column_name 'videoId')    | plain   |              |
 state      | e_finish_state           |           | (column_name 'state')      | plain   |              |
 subject    | e_subject                | not null  | (column_name 'subject')    | plain   |              |
 stage      | e_stage                  | not null  | (column_name 'stage')      | plain   |              |
 finishTime | timestamp with time zone |           | (column_name 'finishTime') | plain   |              |
 createTime | timestamp with time zone |           | (column_name 'createTime') | plain   |              |
Check constraints:
    "videoStatusMathMiddle_stage_check" CHECK (stage = 'middle'::e_stage)
    "videoStatusMathMiddle_subject_check" CHECK (subject = 'math'::e_subject)
Server: videoStatusMathMiddle
FDW Options: (schema_name 'public', table_name 'videoStatusMathMiddle')
Inherits: "videoStatus"

```

add trigger for insert

```sql

create or replace function "videoStatusInsert"() returns trigger as
$$
declare
begin
  if (NEW.subject = 'math' and NEW.stage = 'middle') then
    insert into "videoStatusMathMiddle" values (NEW.*);
  elsif (NEW.subject = 'math' and NEW.stage = 'high') then
    insert into "videoStatusMathHigh" values (NEW.*);
  elsif (NEW.subject = 'physics' and NEW.stage = 'high') then
    insert into "videoStatusPhysicsHigh" values (NEW.*);
  else
    raise exception 'invalid subject & stage';
  end if;

  return null;
end;
$$ language plpgsql;

-- event trigger

create trigger "onVideoStatusInsert"
  before insert on "videoStatus"
  for each row execute procedure "videoStatusInsert"();

-- query

explain select * from "videoStatus" where stage = 'high' ;
                                     QUERY PLAN
------------------------------------------------------------------------------------
 Append  (cost=0.00..146.95 rows=7 width=48)
   ->  Seq Scan on "videoStatus"  (cost=0.00..0.00 rows=1 width=48)
         Filter: (stage = 'high'::e_stage)
   ->  Foreign Scan on "videoStatusMathHigh"  (cost=100.00..146.95 rows=6 width=48)
         Filter: (stage = 'high'::e_stage)

explain select * from "videoStatus" where  subject = 'math' ;
                                      QUERY PLAN
--------------------------------------------------------------------------------------
 Append  (cost=0.00..293.91 rows=13 width=48)
   ->  Seq Scan on "videoStatus"  (cost=0.00..0.00 rows=1 width=48)
         Filter: (subject = 'math'::e_subject)
   ->  Foreign Scan on "videoStatusMathMiddle"  (cost=100.00..146.95 rows=6 width=48)
         Filter: (subject = 'math'::e_subject)
   ->  Foreign Scan on "videoStatusMathHigh"  (cost=100.00..146.95 rows=6 width=48)
         Filter: (subject = 'math'::e_subject)

```

完成状态查询

```sql
SELECT id, "chapterId", name, "topicStatusList" from theme th left join lateral (

    select "themeId", json_agg(tvs) "topicStatusList" from (
        SELECT id, "themeId", "videoStatusList" from topic tp left join lateral (
            select json_agg(json_build_object('videoId', "videoId", 'state', state)) "videoStatusList" from "videoStatus" vs
            where "userId" = '004e7800-19e1-11e7-ad1b-37c02e864b03'
                and "videoId" = any(select "videoId" from "topicVideo" tv where tv."topicId" = tp.id)
                and vs.subject = 'math' and vs.stage = 'middle'
        ) tmp on true
    ) tvs group by "themeId" having tvs."themeId" = th.id

) t on true
where "chapterId" = 1 ;

 id | chapterId |          name          |                                    topicStatusList
----+-----------+------------------------+----------------------------------------------------------------------------------------
 19 |         1 | 人教三角形章检测B      | [{"id":34,"themeId":19,"videoStatusList":null}]
 18 |         1 | 人教三角形章检测A      | [{"id":33,"themeId":18,"videoStatusList":null}]
 17 |         1 | 三角形总结             | [{"id":32,"themeId":17,"videoStatusList":[{"videoId" : 29, "state" : "unfinished"}]}]
 16 |         1 | 飞镖模型与角平分线     | [{"id":31,"themeId":16,"videoStatusList":[{"videoId" : 28, "state" : "unfinished"}]}]
 15 |         1 | 三角形与多边形综合问题 | [{"id":30,"themeId":15,"videoStatusList":null},                                       +
    |           |                        |  {"id":29,"themeId":15,"videoStatusList":[{"videoId" : 27, "state" : "unfinished"}]}, +
    |           |                        |  {"id":28,"themeId":15,"videoStatusList":[{"videoId" : 26, "state" : "unfinished"}]}]
 14 |         1 | 两同类角等分线求角     | [{"id":27,"themeId":14,"videoStatusList":[{"videoId" : 25, "state" : "unfinished"}]}]
 13 |         1 | 角平分线求角           | [{"id":26,"themeId":13,"videoStatusList":[{"videoId" : 24, "state" : "unfinished"}]}, +
    |           |                        |  {"id":25,"themeId":13,"videoStatusList":[{"videoId" : 23, "state" : "unfinished"}]}]
 12 |         1 | 三角形与角度证明       | [{"id":24,"themeId":12,"videoStatusList":null},                                       +
    |           |                        |  {"id":23,"themeId":12,"videoStatusList":[{"videoId" : 22, "state" : "unfinished"}]}, +
    |           |                        |  {"id":22,"themeId":12,"videoStatusList":[{"videoId" : 21, "state" : "unfinished"}]}]
 11 |         1 | 8字模型                | [{"id":21,"themeId":11,"videoStatusList":[{"videoId" : 20, "state" : "unfinished"}]}, +
    |           |                        |  {"id":20,"themeId":11,"videoStatusList":[{"videoId" : 19, "state" : "unfinished"}]}]
 10 |         1 | 三角形与平行线         | [{"id":19,"themeId":10,"videoStatusList":null},                                       +
    |           |                        |  {"id":18,"themeId":10,"videoStatusList":[{"videoId" : 18, "state" : "unfinished"}]}]
  9 |         1 | 多边形的内外角         | [{"id":17,"themeId":9,"videoStatusList":[{"videoId" : 17, "state" : "unfinished"}]},  +
    |           |                        |  {"id":16,"themeId":9,"videoStatusList":[{"videoId" : 16, "state" : "unfinished"}]}]
  8 |         1 | 多边形的概念           | [{"id":15,"themeId":8,"videoStatusList":[{"videoId" : 15, "state" : "unfinished"}]},  +
    |           |                        |  {"id":14,"themeId":8,"videoStatusList":[{"videoId" : 14, "state" : "unfinished"}]}]
  7 |         1 | 两内角角平分线求角     | [{"id":13,"themeId":7,"videoStatusList":[{"videoId" : 13, "state" : "unfinished"}]}]
  6 |         1 | 三角形的内外角的应用   | [{"id":12,"themeId":6,"videoStatusList":[{"videoId" : 12, "state" : "unfinished"}]},  +
    |           |                        |  {"id":11,"themeId":6,"videoStatusList":[{"videoId" : 11, "state" : "unfinished"}]}]
  5 |         1 | 三角形的内外角         | [{"id":10,"themeId":5,"videoStatusList":[{"videoId" : 10, "state" : "unfinished"}]},  +
    |           |                        |  {"id":9,"themeId":5,"videoStatusList":[{"videoId" : 9, "state" : "unfinished"}]},    +
    |           |                        |  {"id":8,"themeId":5,"videoStatusList":[{"videoId" : 8, "state" : "unfinished"}]}]
  4 |         1 | 三角形的稳定性         | [{"id":7,"themeId":4,"videoStatusList":[{"videoId" : 7, "state" : "unfinished"}]}]
  3 |         1 | 三角形中的线段         | [{"id":6,"themeId":3,"videoStatusList":[{"videoId" : 6, "state" : "unfinished"}]},    +
    |           |                        |  {"id":5,"themeId":3,"videoStatusList":[{"videoId" : 5, "state" : "unfinished"}]},    +
    |           |                        |  {"id":4,"themeId":3,"videoStatusList":[{"videoId" : 4, "state" : "unfinished"}]}]
  2 |         1 | 三角形的三边关系       | [{"id":3,"themeId":2,"videoStatusList":[{"videoId" : 3, "state" : "unfinished"}]}]
  1 |         1 | 三角形的分类           | [{"id":2,"themeId":1,"videoStatusList":[{"videoId" : 2, "state" : "unfinished"}]},    +
    |           |                        |  {"id":1,"themeId":1,"videoStatusList":[{"videoId" : 1, "state" : "unfinished"}]}]
(19 rows)

```

查询计划

```sql
onion=> explain analyze  SELECT id, "chapterId", name, "topicStatusList" from theme th left join lateral (                                                                                                                                                                                                                                                                                                                  select "themeId", json_agg(tvs) "topicStatusList" from (                                                                                                                                                        SELECT id, "themeId", "videoStatusList" from topic tp left join lateral (                                                                                                                                       select json_agg(json_build_object('videoId', "videoId", 'state', state)) "videoStatusList" from "videoStatus" vs                                                                                            where "userId" = '004e7800-19e1-11e7-ad1b-37c02e864b03'                                                                                                                                                         and "videoId" = any(select "videoId" from "topicVideo" tv where tv."topicId" = tp.id)                                                                                                                       and vs.subject = 'math' and vs.stage = 'middle'                                                                                                                                                     ) tmp on true                                                                                                                                                                                           ) tvs group by "themeId" having tvs."themeId" = th.id                                                                                                                                                   ) t on true                                                                                                                                                                                                 where "chapterId" = 1;
                                                                                 QUERY PLAN
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Nested Loop Left Join  (cost=553.36..28546.83 rows=78 width=72) (actual time=14.364..431.539 rows=19 loops=1)
   ->  Foreign Scan on theme th  (cost=100.00..126.12 rows=6 width=40) (actual time=3.604..3.625 rows=19 loops=1)
   ->  GroupAggregate  (cost=453.36..4736.53 rows=13 width=36) (actual time=22.515..22.516 rows=1 loops=19)
         Group Key: tp."themeId"
         ->  Nested Loop Left Join  (cost=453.36..4736.30 rows=13 width=40) (actual time=13.740..22.500 rows=2 loops=19)
               ->  Foreign Scan on topic tp  (cost=100.00..142.26 rows=13 width=8) (actual time=3.427..3.430 rows=2 loops=19)
               ->  Aggregate  (cost=353.36..353.37 rows=1 width=32) (actual time=9.720..9.721 rows=1 loops=34)
                     ->  Nested Loop Semi Join  (cost=100.00..353.35 rows=1 width=8) (actual time=7.375..9.228 rows=1 loops=34)
                           Join Filter: (vs."videoId" = tv."videoId")
                           Rows Removed by Join Filter: 107
                           ->  Append  (cost=0.00..206.00 rows=2 width=8) (actual time=0.971..2.617 rows=126 loops=34)
                                 ->  Seq Scan on "videoStatus" vs  (cost=0.00..0.00 rows=1 width=8) (actual time=0.001..0.001 rows=0 loops=34)
                                       Filter: (("userId" = '004e7800-19e1-11e7-ad1b-37c02e864b03'::uuid) AND (subject = 'math'::e_subject) AND (stage = 'middle'::e_stage))
                                 ->  Foreign Scan on "videoStatusMathMiddle" vs_1  (cost=100.00..206.00 rows=1 width=8) (actual time=0.966..2.361 rows=126 loops=34)
                                       Filter: ((subject = 'math'::e_subject) AND (stage = 'middle'::e_stage))
                           ->  Materialize  (cost=100.00..146.94 rows=15 width=4) (actual time=0.049..0.049 rows=1 loops=4284)
                                 ->  Foreign Scan on "topicVideo" tv  (cost=100.00..146.86 rows=15 width=4) (actual time=4.409..4.410 rows=1 loops=34)
 Planning time: 0.647 ms
 Execution time: 439.666 ms
(19 rows)
```
痛点：外部数据的网络IO太耗时


总结：

    因为分片数据的("userId", "videoId")是外键，但是该用户表和视频表都分布在不同的数据节点上，无法创建外键约束，  
    因此，数据的一致性就需要在分区表的主表上进行验证，保证数据的一致性  
    对DB User 进行明确的角色分配，避免误操作，造成脏数据


[参考 PostgreSQL 9.5 新特性之 - 水平分片架构与实践](https://yq.aliyun.com/articles/6635)


