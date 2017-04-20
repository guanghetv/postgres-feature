
## Use copy command import array of Composite Types data

```sql

CREATE TYPE e_theme_icon_type AS ENUM ('perfect', 'common');

CREATE TYPE theme_icon AS (
  image varchar(200),
  svg varchar(200),
  background varchar(20),
  type e_theme_icon_type,
  goldenBackground varchar(200)
);

CREATE TABLE test (a theme_icon[], b text);

-- import file(t.copy) content
{"(g,#eeeeee,#FBCF00,perfect,#eeeeee)","(g,#678,#FBCF00,common,#123)"},jack

\copy test FROM '/Users/jack/t.copy'
# malformed array literal: "{"(g,#eeeeee,#FBCF00,perfect,#eeeeee)","(g,#678,#FBCF00,common,#123)"},jack"
# DETAIL:  Junk after closing right brace.

-- use '|' instead
{"(g,#eeeeee,#FBCF00,perfect,#eeeeee)","(g,#678,#FBCF00,common,#123)"}|jack

\copy test FROM '/Users/jack/t.copy' DELIMITER '|'

SELECT * FROM test;
+------------------------------------------------------------------------+------+
| a                                                                      | b    |
|------------------------------------------------------------------------+------|
| {"(g,#eeeeee,#FBCF00,perfect,#eeeeee)","(g,#678,#FBCF00,common,#123)"} | jack |
+------------------------------------------------------------------------+------+

```
