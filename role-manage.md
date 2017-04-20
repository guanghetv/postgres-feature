
# Role Manage

```sql
create user dbuser with password 'abcD1234' createdb connection limit 30;
create user dbuser with password 'abcD1234' valid until '2017-06-10';

GRANT SELECT, INSERT, UPDATE, DELETE
ON ALL TABLES IN SCHEMA public 
TO jack;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO myuser;


```
