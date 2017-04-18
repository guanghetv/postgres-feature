
# CREATE TABLE with LIKE

```sql
\d test
+----------+---------+-------------+
| Column   | Type    | Modifiers   |
|----------+---------+-------------|
| name     | text    |             |
| point    | integer |  default 0  |
+----------+---------+-------------+

CREATE TABLE t (LIKE test INCLUDING DEFAULTS);

\d t
+----------+---------+-------------+
| Column   | Type    | Modifiers   |
|----------+---------+-------------|
| name     | text    |             |
| point    | integer |  default 0  |
+----------+---------+-------------+

```


# CREATE TABLE AS -- define a new table from the results of a query

```sql
CREATE TABLE t AS
    SELECT * FROM test WHERE point > 0 ;

CREATE TABLE t AS
    TABLE test;

PREPARE test_filter(int) AS
  SELECT * FROM test WHERE point > $1;
CREATE TEMP TABLE t AS
  EXECUTE test_filter(0);

```



## EXCLUSION CONSTRAINTS

```sql
CREATE TABLE test (
    i INT4,
    EXCLUDE (i WITH =)
);

INSERT INTO test (i) VALUES (1);
INSERT INTO test (i) VALUES (2);

INSERT INTO test (i) VALUES (1);
ERROR:  conflicting key value violates exclusion constraint "test_i_excl"

```

```sql
CREATE TABLE test (
    from_ts TIMESTAMPTZ,
    to_ts   TIMESTAMPTZ,
    CHECK ( from_ts < to_ts ),
    CONSTRAINT overlapping_times EXCLUDE USING GIST (
        box(
            point( extract(epoch FROM from_ts at time zone 'UTC'), extract(epoch FROM from_ts at time zone 'UTC') ),
            point( extract(epoch FROM to_ts at time zone 'UTC')  , extract(epoch FROM to_ts at time zone 'UTC') )
        ) WITH &&
    )
);

INSERT INTO test ( from_ts, to_ts ) VALUES ( '2009-01-01 01:23:45 EST', '2009-01-10 23:45:12 EST' );
INSERT INTO test ( from_ts, to_ts ) VALUES ( '2009-02-01 01:23:45 EST', '2009-02-10 23:45:12 EST' );

INSERT INTO test ( from_ts, to_ts ) VALUES ( '2009-01-08 00:00:00 EST', '2009-01-15 23:59:59 EST' );
ERROR:  conflicting key value violates exclusion constraint "overlapping_times"

```

What's more – readability of the code can be dramatically improved by providing a wrapper around calculations, like this:

```sql
CREATE OR REPLACE FUNCTION box_from_ts_range(in_first timestamptz, in_second timestamptz) RETURNS box as $$
DECLARE
    first_float  float8 := extract(epoch FROM in_first  AT TIME ZONE 'UTC');
    second_float float8 := extract(epoch FROM in_second AT TIME ZONE 'UTC');
BEGIN
    RETURN box( point ( first_float, first_float), point( second_float, second_float ) );
END;
$$ language plpgsql IMMUTABLE;

CREATE TABLE test (
    from_ts TIMESTAMPTZ,
    to_ts   TIMESTAMPTZ,
    CHECK ( from_ts < to_ts ),
    CONSTRAINT overlapping_times EXCLUDE USING GIST ( box_from_ts_range( from_ts, to_ts ) WITH && )
);

```

Now, let's try to use the EXCLUDE for something more realistic – room reservations for hotel.

```sql
CREATE TABLE reservations (
    id          SERIAL PRIMARY KEY,
    room_number INT4 NOT NULL,
    from_ts     DATE NOT NULL,
    to_ts       DATE NOT NULL,
    guest_name  TEXT NOT NULL,
    CHECK       ( from_ts <= to_ts ),
    CHECK       ( room_number >= 101 AND room_number <= 700 AND room_number % 100 >= 1 AND room_number % 100 <= 25 )
);

ALTER TABLE public.reservations ADD CONSTRAINT check_overlapping_reservations EXCLUDE USING GIST (
    box (
        point(
            from_ts - '2000-01-01'::date,
            room_number
        ),
        point(
            ( to_ts - '2000-01-01'::date ) + 0.5,
            room_number + 0.5
        )
    )
    WITH &&
);

INSERT INTO reservations (room_number, from_ts, to_ts, guest_name) VALUES (101, '2010-01-05', '2010-01-23', 'test1');
INSERT INTO reservations (room_number, from_ts, to_ts, guest_name) VALUES (102, '2010-01-07', '2010-01-21', 'test2');
INSERT INTO reservations (room_number, from_ts, to_ts, guest_name) VALUES (101, '2010-01-25', '2010-01-30', 'test3');

INSERT INTO reservations (room_number, from_ts, to_ts, guest_name) VALUES (101, '2010-01-07', '2010-01-08', 'test4');
ERROR:  conflicting key value violates exclusion constraint "check_overlapping_reservations"

```

#### 参考
[PostgreSQL Documentation](https://www.postgresql.org/docs/current/static/sql-createtable.html)  
[EXCLUSION CONSTRAINTS](https://www.depesz.com/2010/01/03/waiting-for-8-5-exclusion-constraints/)








