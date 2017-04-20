
# Role Manage

For convenience, the programs createuser and dropuser are provided as wrappers around these SQL commands that can be called from the shell command line:

```sql
createuser name
dropuser name
```

To determine the set of existing roles, examine the pg_roles system catalog, for example
```sql
SELECT rolname FROM pg_roles;
```

The psql program's \du meta-command is also useful for listing the existing roles.


## Role Attributes

A database role can have a number of attributes that define its privileges and interact with the client authentication system.

```sql
CREATE ROLE name LOGIN;
CREATE ROLE name SUPERUSER
CREATE ROLE name CREATEDB
CREATE ROLE name CREATEROLE
CREATE ROLE name REPLICATION LOGIN
CREATE ROLE name PASSWORD 'string'

```

A role can also have role-specific defaults for many of the run-time configuration settings described in Chapter 19. For example, if for some reason you want to disable index scans (hint: not a good idea) anytime you connect, you can use:
```sql
ALTER ROLE myname SET enable_indexscan TO off;

-- To remove a role-specific default setting, use 
ALTER ROLE rolename RESET varname

```


## Role Membership
member roles that have the INHERIT attribute automatically have use of the privileges of roles of which they are members, including any privileges inherited by those roles. As an example, suppose we have done:

```sql
CREATE ROLE joe LOGIN INHERIT;
CREATE ROLE admin NOINHERIT;
CREATE ROLE wheel NOINHERIT;
GRANT admin TO joe;
GRANT wheel TO admin;
```

Immediately after connecting as role joe, a database session will have use of privileges granted directly to joe plus any privileges granted to admin, because joe "inherits" admin's privileges. However, privileges granted to wheel are not available, because even though joe is indirectly a member of wheel, the membership is via admin which has the NOINHERIT attribute. 




## GRANT

The privileges applicable to a particular object vary depending on the object's type (table, function, DATABASE, TYPE, etc)

The GRANT command has two basic variants: one that grants privileges on a database object (table, column, view, foreign table, sequence, database, foreign-data wrapper, foreign server, function, procedural language, schema, or tablespace), and one that grants membership in a role. These variants are similar in many ways, but they are different enough to be described separately.


```sql
create user dbuser with password 'abcD1234' createdb connection limit 30;
create user dbuser with password 'abcD1234' valid until '2017-06-10';

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, CREATE, CONNECT, TEMPORARY, EXECUTE, USAGE
ON ALL TABLES IN SCHEMA public 
TO jack;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO myuser;


```

Use psql's \dp command to obtain information about existing privileges for tables and column

```sql
\dp "user"
                              Access privileges
 Schema | Name | Type  |   Access privileges   | Column privileges | Policies
--------+------+-------+-----------------------+-------------------+----------
 public | user | table | master=arwdDxt/master+|                   |
        |      |       | jack=arwd/master     +|                   |
        |      |       | jone=arwdDxt/master  +|                   |
        |      |       | yamaha=arwdDxt/master |                   |
(1 row)

rolename=xxxx -- privileges granted to a role
        =xxxx -- privileges granted to PUBLIC

            r -- SELECT ("read")
            w -- UPDATE ("write")
            a -- INSERT ("append")
            d -- DELETE
            D -- TRUNCATE
            x -- REFERENCES
            t -- TRIGGER
            X -- EXECUTE
            U -- USAGE
            C -- CREATE
            c -- CONNECT
            T -- TEMPORARY
      arwdDxt -- ALL PRIVILEGES (for tables, varies for other objects)
            * -- grant option for preceding privilege

        /yyyy -- role that granted this privilege


GRANT SELECT ON mytable TO PUBLIC;
GRANT SELECT, UPDATE, INSERT ON mytable TO admin;
GRANT SELECT (col1), UPDATE (col1) ON mytable TO miriam_rw;

-- Grant membership in role admins to user joe
GRANT admins TO joe;

```


## ALTER DEFAULT PRIVILEGES

Grant SELECT privilege to everyone for all tables (and views) you subsequently create in schema myschema, and allow role webuser to INSERT into them too:

```sql
ALTER DEFAULT PRIVILEGES IN SCHEMA myschema GRANT SELECT ON TABLES TO PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA myschema GRANT INSERT ON TABLES TO webuser;

```

Undo the above, so that subsequently-created tables won't have any more permissions than normal:

```sql
ALTER DEFAULT PRIVILEGES IN SCHEMA myschema REVOKE SELECT ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA myschema REVOKE INSERT ON TABLES FROM webuser;

REVOKE ALL ON accounts FROM PUBLIC;

```


## Row Security Policies

here is how to create a policy on the account relation to allow only members of the managers role to access rows, and only rows of their accounts:

```sql
CREATE TABLE accounts (manager text, company text, contact_email text);

ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;

CREATE POLICY account_managers ON accounts TO managers
    USING (manager = current_user);

```

If no role is specified, or the special user name PUBLIC is used, then the policy applies to all users on the system. To allow all users to access their own row in a users table, a simple policy can be used:
```sql
CREATE POLICY user_policy ON users
    USING (user_name = current_user);
```

To use a different policy for rows that are being added to the table compared to those rows that are visible, the WITH CHECK clause can be used. This policy would allow all users to view all rows in the users table, but only modify their own:
```sql
CREATE POLICY user_policy ON users
    USING (true)
    WITH CHECK (user_name = current_user);
```

Below is a larger example of how this feature can be used in production environments. The table passwd emulates a Unix password file:
```sql
-- Simple passwd-file based example
CREATE TABLE passwd (
  user_name             text UNIQUE NOT NULL,
  pwhash                text,
  uid                   int  PRIMARY KEY,
  gid                   int  NOT NULL,
  real_name             text NOT NULL,
  home_phone            text,
  extra_info            text,
  home_dir              text NOT NULL,
  shell                 text NOT NULL
);

CREATE ROLE admin;  -- Administrator
CREATE ROLE bob;    -- Normal user
CREATE ROLE alice;  -- Normal user

-- Populate the table
INSERT INTO passwd VALUES
  ('admin','xxx',0,0,'Admin','111-222-3333',null,'/root','/bin/dash');
INSERT INTO passwd VALUES
  ('bob','xxx',1,1,'Bob','123-456-7890',null,'/home/bob','/bin/zsh');
INSERT INTO passwd VALUES
  ('alice','xxx',2,1,'Alice','098-765-4321',null,'/home/alice','/bin/zsh');

-- Be sure to enable row level security on the table
ALTER TABLE passwd ENABLE ROW LEVEL SECURITY;

-- Create policies
-- Administrator can see all rows and add any rows
CREATE POLICY admin_all ON passwd TO admin USING (true) WITH CHECK (true);
-- Normal users can view all rows
CREATE POLICY all_view ON passwd FOR SELECT USING (true);
-- Normal users can update their own records, but
-- limit which shells a normal user is allowed to set
CREATE POLICY user_mod ON passwd FOR UPDATE
  USING (current_user = user_name)
  WITH CHECK (
    current_user = user_name AND
    shell IN ('/bin/bash','/bin/sh','/bin/dash','/bin/zsh','/bin/tcsh')
  );

-- Allow admin all normal rights
GRANT SELECT, INSERT, UPDATE, DELETE ON passwd TO admin;
-- Users only get select access on public columns
GRANT SELECT
  (user_name, uid, gid, real_name, home_phone, extra_info, home_dir, shell)
  ON passwd TO public;
-- Allow users to update certain columns
GRANT UPDATE
  (pwhash, real_name, home_phone, extra_info, shell)
  ON passwd TO public;

```

As with any security settings, it's important to test and ensure that the system is behaving as expected. Using the example above, this demonstrates that the permission system is working properly.

```sql
-- admin can view all rows and fields
postgres=> set role admin;
SET
postgres=> table passwd;
 user_name | pwhash | uid | gid | real_name |  home_phone  | extra_info | home_dir    |   shell
-----------+--------+-----+-----+-----------+--------------+------------+-------------+-----------
 admin     | xxx    |   0 |   0 | Admin     | 111-222-3333 |            | /root       | /bin/dash
 bob       | xxx    |   1 |   1 | Bob       | 123-456-7890 |            | /home/bob   | /bin/zsh
 alice     | xxx    |   2 |   1 | Alice     | 098-765-4321 |            | /home/alice | /bin/zsh
(3 rows)

-- Test what Alice is able to do
postgres=> set role alice;
SET
postgres=> table passwd;
ERROR:  permission denied for relation passwd
postgres=> select user_name,real_name,home_phone,extra_info,home_dir,shell from passwd;
 user_name | real_name |  home_phone  | extra_info | home_dir    |   shell
-----------+-----------+--------------+------------+-------------+-----------
 admin     | Admin     | 111-222-3333 |            | /root       | /bin/dash
 bob       | Bob       | 123-456-7890 |            | /home/bob   | /bin/zsh
 alice     | Alice     | 098-765-4321 |            | /home/alice | /bin/zsh
(3 rows)

postgres=> update passwd set user_name = 'joe';
ERROR:  permission denied for relation passwd
-- Alice is allowed to change her own real_name, but no others
postgres=> update passwd set real_name = 'Alice Doe';
UPDATE 1
postgres=> update passwd set real_name = 'John Doe' where user_name = 'admin';
UPDATE 0
postgres=> update passwd set shell = '/bin/xx';
ERROR:  new row violates WITH CHECK OPTION for "passwd"
postgres=> delete from passwd;
ERROR:  permission denied for relation passwd
postgres=> insert into passwd (user_name) values ('xxx');
ERROR:  permission denied for relation passwd
-- Alice can change her own password; RLS silently prevents updating other rows
postgres=> update passwd set pwhash = 'abc';
UPDATE 1

```



