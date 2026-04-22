-- При выборе автомобиля для выполнения заказа необходимо убедиться, 
-- что все услуги в заказе могут быть выполнены выбранным автомобилем. 
-- Если невозможно, то добавление автомобиля в заказ отменяется 
-- и выводится соответствующее сообщение.

CREATE OR REPLACE FUNCTION check_car_facilities()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE 
    absense_cnt INT;
BEGIN
    WITH cf AS (
        SELECT facility_id AS fidcf FROM car_facility cf
        WHERE cf.car_id = NEW.car_id 
    ), 
    glued_fac AS (
        SELECT facility_id AS fidorfa, cf.fidcf FROM ordered_facility orfa
        LEFT JOIN cf ON cf.fidcf = orfa.facility_id
        WHERE orfa.order_id = OLD.order_id AND orfa.driver_id = OLD.driver_id
    )
    SELECT COUNT(*) INTO absense_cnt FROM glued_fac
    WHERE glued_fac.fidcf IS NULL;
    
    IF absense_cnt = 0 THEN RETURN NEW; 
    ELSE RAISE EXCEPTION 'car does not support enough facilities (car_id = %, order_id = %, absense_cnt = %)', NEW.car_id, OLD.order_id, absense_cnt;
    END IF;

END;
$$;

CREATE OR REPLACE TRIGGER car_to_order
BEFORE UPDATE ON "order"
FOR EACH ROW
-- WHEN (OLD.car_id IS DISTINCT FROM NEW.car_id)
EXECUTE FUNCTION check_car_facilities();

-- car_id = 1 : facility_id = 5
-- car_id = 3 : facility_id = 1, 2, 3, 4, 5, 6
-- car_id = 4 : facility_id = 2, 4, 6
-- car_id = 5 : facility_id = 
-- car_id = 11 : facility_id = 1
-- car_id = 61 : facility_id = 1, 2, 3, 4, 5, 6
-- car_id = 97 : facility_id = 1, 6
-- car_id = 125 : facility_id = 3, 5

-- order_id = 7   : driver_id = 10493 : facility_id = 3, 5
-- order_id = 22  : driver_id = 10301 : facility_id = 1, 2, 3, 5
-- order_id = 54  : driver_id = 10705 : facility_id = 1
-- order_id = 55  : driver_id = 10766 : facility_id = 
-- order_id = 149 : driver_id = 10611 : facility_id = 1, 2, 3, 4, 5
-- order_id = 1743 : driver_id = 10656 : facility_id = 1, 3, 4, 6


UPDATE "order" SET car_id = 61
WHERE order_id = 149 AND driver_id = 10611
