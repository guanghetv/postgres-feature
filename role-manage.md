
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





