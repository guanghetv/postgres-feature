
INSERT INTO distributors (did, dname)
    VALUES (5, 'Gizmo Transglobal'), (6, 'Associated Computing, Inc')
        ON CONFLICT (did) DO UPDATE SET dname = EXCLUDED.dname;


-- Don't update existing distributors based in a certain ZIP code
INSERT INTO distributors AS d (did, dname) VALUES (8, 'Anvil Distribution')
    ON CONFLICT (did) DO UPDATE
        SET dname = EXCLUDED.dname || ' (formerly ' || d.dname || ')'
            WHERE d.zipcode <> '21201';

            -- Name a constraint directly in the statement (uses associated
                                                           -- index to arbitrate taking the DO NOTHING action)
            INSERT INTO distributors (did, dname) VALUES (9, 'Antwerp Design')
                ON CONFLICT ON CONSTRAINT distributors_pkey DO NOTHING;

