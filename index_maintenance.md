
## Index Maintenance


-- ```sql

-- Table & index sizes along which indexes are being scanned and how many tuples are fetched.

CREATE OR REPLACE VIEW table_index_statistics AS
    SELECT
        t.tablename,
        indexname,
        c.reltuples AS num_rows,
        pg_size_pretty(pg_relation_size(quote_ident(t.tablename)::text)) AS table_size,
        pg_size_pretty(pg_relation_size(quote_ident(indexrelname)::text)) AS index_size,
        CASE WHEN indisunique THEN 'Y'
           ELSE 'N'
        END AS UNIQUE,
        idx_scan AS number_of_scans,
        idx_tup_read AS tuples_read,
        idx_tup_fetch AS tuples_fetched
    FROM pg_tables t
    LEFT OUTER JOIN pg_class c ON t.tablename=c.relname
    LEFT OUTER JOIN
        ( SELECT c.relname AS ctablename, ipg.relname AS indexname, x.indnatts AS number_of_columns,
              idx_scan, idx_tup_read, idx_tup_fetch, indexrelname, indisunique FROM pg_index x
               JOIN pg_class c ON c.oid = x.indrelid
               JOIN pg_class ipg ON ipg.oid = x.indexrelid
               JOIN pg_stat_all_indexes psai ON x.indexrelid = psai.indexrelid )
        AS foo
        ON t.tablename = foo.ctablename
    WHERE t.schemaname='public'
    ORDER BY 1,2;


CREATE OR REPLACE VIEW duplicate_index AS
    SELECT pg_size_pretty(SUM(pg_relation_size(idx))::BIGINT) AS SIZE,
           (array_agg(idx))[1] AS idx1, (array_agg(idx))[2] AS idx2,
           (array_agg(idx))[3] AS idx3, (array_agg(idx))[4] AS idx4
    FROM (
        SELECT indexrelid::regclass AS idx, (indrelid::text ||E'\n'|| indclass::text ||E'\n'|| indkey::text ||E'\n'||
                                             COALESCE(indexprs::text,'')||E'\n' || COALESCE(indpred::text,'')) AS KEY
        FROM pg_index) sub
    GROUP BY KEY HAVING COUNT(*)>1
    ORDER BY SUM(pg_relation_size(idx)) DESC;


```


