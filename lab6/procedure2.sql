-- Процедура предназначена для добавления случайной услуги в выбранный заказ. 
-- Номер заказа передается в процедуры, в процедуре проверяется, что заказ не завершен. 
-- Если заказ завершен, то не добавляется ничего. 
-- В качестве случайной услуги выбирается одна из услуг, 
-- которые могут быть оказаны в данном автомобиле.


CREATE OR REPLACE PROCEDURE
random_facility_insert (IN selected_order_id BIGINT)
LANGUAGE plpgsql
AS $$
DECLARE
    random_id INT;
    order_car_id BIGINT;
    order_driver_id BIGINT;
BEGIN
    IF EXISTS (
        SELECT * FROM "order" o
        WHERE o.order_id = selected_order_id AND NOT o.cancelled AND o.end_time IS NULL
    ) THEN
        SELECT o.driver_id, o.car_id INTO order_driver_id, order_car_id FROM "order" o
        WHERE o.order_id = selected_order_id AND NOT o.cancelled AND o.end_time IS NULL;

        WITH cf AS (
            SELECT facility_id AS fidcf FROM car_facility cf
            WHERE cf.car_id = order_car_id 
        ), 
        -- допы авто + заказанные допы -> берем где null слева
        free_fac AS ( 
            SELECT cf.fidcf AS fac FROM cf
            LEFT JOIN (SELECT * FROM ordered_facility orfa
                WHERE orfa.order_id = selected_order_id AND orfa.driver_id = order_driver_id) orfa
            ON cf.fidcf = orfa.facility_id
            WHERE orfa.facility_id IS NUll
        )
        SELECT fac INTO random_id FROM free_fac
        ORDER BY RANDOM()
        LIMIT 1;

        IF random_id IS NULL 
            THEN RAISE NOTICE 'nothing to add!';
            ELSE
                RAISE NOTICE 'randomly chose facility_id=%', random_id;
                INSERT INTO ordered_facility (facility_id, order_id, driver_id) 
                    VALUES (random_id, selected_order_id, order_driver_id);
        END IF;
    ELSE
        RAISE NOTICE 'order_id=% is not in progress', selected_order_id;
    END IF;
END;
$$;

-- order_id = 88  ordered_facility = car_id = 9    car_facility = 1, 2, 4, 6
-- order_id = 93  ordered_facility = car_id = 60   car_facility = 1, 3, 4, 5, 6

CALL random_facility_insert(88);

-- SELECT * FROM "order"
-- WHERE NOT cancelled AND end_time IS NULL;


