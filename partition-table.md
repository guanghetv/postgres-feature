# Partition Table


-- ```sql

CREATE TYPE problem_type AS ENUM (
    'single_choice',
    'single_blank',
    'multi_blank',
    'hybrid', -- 带有多个下拉框的大题
    'exam' -- 举一反三／大题验证的题型
);

CREATE TABLE problem_log (
    "userId" char(24) NOT NULL,
    "videoId" uuid NOT NULL,
    "problemId" uuid NOT NULL,
    "subjectId" smallint NOT NULL,
    "stageId" smallint NOT NULL,
    duration smallint /*NOT NULL*/, -- 部分数据缺失
    -- level smallint NOT NULL,
    answers text[] NOT NULL,
    correct bool NOT NULL,
    "submitTime" timestamptz NOT NULL,
    type problem_type NOT NULL,
    "createTime" timestamptz DEFAULT now()
);


CREATE TABLE problem_log_math_middle (
    CHECK ("subjectId" = 1 AND "stageId" = 2)
) INHERITS (problem_log);

CREATE TABLE problem_log_math_high (
    CHECK ("subjectId" = 1 AND "stageId" = 3)
) INHERITS (problem_log);

CREATE TABLE problem_log_physics_middle (
    CHECK ("subjectId" = 2 AND "stageId" = 2)
) INHERITS (problem_log);


CREATE OR REPLACE FUNCTION problem_log_insert_trigger()
RETURNS TRIGGER AS
$$
BEGIN
    IF (NEW."subjectId" = 1 AND NEW."stageId" = 2) THEN
        INSERT INTO problem_log_math_middle VALUES (NEW.*);
    ELSIF (NEW."subjectId" = 1 AND NEW."stageId" = 3) THEN
        INSERT INTO problem_log_math_high VALUES (NEW.*);
    ELSIF (NEW."subjectId" = 2 AND NEW."stageId" = 2) THEN
        INSERT INTO problem_log_physics_middle VALUES (NEW.*);
    ELSE
        RAISE EXCEPTION 'subjectId&stageId out of range!';
    END IF;
    RETURN NULL;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER insert_problem_log_trigger
    BEFORE INSERT ON problem_log
    FOR EACH ROW EXECUTE PROCEDURE problem_log_insert_trigger();


-- Partition problem_log_math_middle by date

CREATE TABLE problem_log_math_middle_2016 (
    CHECK ("createTime" >= '2016-01-01' AND "createTime" < '2017-01-01')
) INHERITS (problem_log_math_middle);

CREATE TABLE problem_log_math_middle_2017 (
    CHECK ("createTime" >= '2017-01-01' AND "createTime" < '2018-01-01')
) INHERITS (problem_log_math_middle);

-- other
CREATE TABLE problem_log_math_middle_other (
    "userId" char(24) NOT NULL,
    "videoId" uuid NOT NULL,
    "problemId" uuid NOT NULL,
    "subjectId" smallint NOT NULL,
    "stageId" smallint NOT NULL,
    duration smallint /*NOT NULL*/, -- 部分数据缺失
    -- level smallint NOT NULL,
    answers text[] NOT NULL,
    correct bool NOT NULL,
    "submitTime" timestamptz NOT NULL,
    type problem_type NOT NULL,
    "createTime" timestamptz DEFAULT now()
);


CREATE OR REPLACE FUNCTION problem_log_math_middle_insert_trigger()
RETURNS TRIGGER AS
$$
BEGIN
    IF (NEW."createTime" >= '2016-01-01' AND NEW."createTime" < '2017-01-01') THEN
    -- IF (NEW."createTime"::date >= '2016-01-01' AND NEW."createTime"::date <= '2016-12-31') THEN
        INSERT INTO problem_log_math_middle_2016 VALUES (NEW.*);
    ELSIF (NEW."createTime" >= '2017-01-01' AND NEW."createTime" < '2018-01-01') THEN
    -- ELSIF (NEW."createTime"::date >= '2017-01-01' AND NEW."createTime"::date <= '2017-12-31') THEN
        INSERT INTO problem_log_math_middle_2017 VALUES (NEW.*);
    ELSE
        -- RAISE EXCEPTION 'createTime out of range! %s', NEW."createTime";
        INSERT INTO problem_log_math_middle_other VALUES (NEW.*);
    END IF;
    RETURN NULL;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER insert_problem_log_math_middle_trigger
    BEFORE INSERT ON problem_log_math_middle
    FOR EACH ROW EXECUTE PROCEDURE problem_log_math_middle_insert_trigger();



INSERT INTO problem_log VALUES
  (
    '5705cf57eef1497709da9f6b',
    '63d40508-555e-11e7-82cb-47dcd7b2b76a',
    '63d40508-555e-11e7-82cb-47dcd7b2b76a',
    1,
    2,
    30,
    array['aaa'],
    false,
    now(),
    'single_choice',
    now()
  ),
  (
    '5705cf57eef1497709da9f6b',
    '63d40508-555e-11e7-82cb-47dcd7b2b76a',
    '63d40508-555e-11e7-82cb-47dcd7b2b76a',
    1,
    2,
    30,
    array['aaa'],
    false,
    now(),
    'single_choice',
    '2018-07-19T07:56:29.814Z'::timestamptz
  );

```
