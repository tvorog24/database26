-- A
BEGIN;
SELECT COUNT(user_id) FROM "user" WHERE role_id = 3;
DELETE FROM "user" WHERE  user_id = 11111;
COMMIT;

-- B
BEGIN;
SELECT COUNT(user_id) FROM "user" WHERE role_id = 3;
DELETE FROM "user" WHERE user_id = 11192;
COMMIT;
