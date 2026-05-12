-- A
BEGIN;
SELECT class_fare FROM car_class WHERE class_id = 5;
UPDATE car_class SET class_fare = 35 WHERE class_id = 5;
COMMIT;

-- B
BEGIN;
SELECT class_fare FROM car_class WHERE class_id = 5;
UPDATE car_class SET class_fare = 40 WHERE class_id = 5;
COMMIT;

