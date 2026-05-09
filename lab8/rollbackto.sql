BEGIN;

INSERT INTO facility (facility_name, facility_cost) VALUES ('Обсудить мировую экономику', 999.99);

SAVEPOINT facility_added;

UPDATE facility SET facility_cost = 1000000 WHERE facility_name = 'Обсудить мировую экономику';

-- нет, слишком дорого, откат
ROLLBACK TO SAVEPOINT facility_added;

COMMIT;

SELECT * FROM facility;