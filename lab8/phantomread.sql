-- A
BEGIN;

SELECT COUNT(*) FROM car 
WHERE property;

SELECT COUNT(*) FROM car 
WHERE property;

COMMIT;

-- B
INSERT INTO car (car_number, class_id, release_year, rent_cost_per_day, maintenance_cost_per_month, property, brand_id, model_id) 
        VALUES ('B777BB77', 5, 2020, 5000, 30000, true, 11, 1)