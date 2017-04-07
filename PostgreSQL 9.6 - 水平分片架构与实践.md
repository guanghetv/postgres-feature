
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

总结：

    因为分片数据的("userId", "videoId")是外键，但是该用户表和视频表都分布在不同的数据节点上，无法创建外键约束，  
    因此，数据的一致性就需要在分区表的主表上进行验证，保证数据的一致性  
    对DB User 进行明确的角色分配，避免误操作，造成脏数据


[参考 PostgreSQL 9.5 新特性之 - 水平分片架构与实践](https://yq.aliyun.com/articles/6635)


