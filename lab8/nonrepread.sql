-- A
BEGIN;

SELECT phone_number FROM "user"
WHERE user_id = 1;

SELECT phone_number FROM "user"
WHERE user_id = 1;

COMMIT;

-- B
UPDATE "user" SET phone_number = '87776665522' WHERE user_id = 1;
