-- Процедура предназначена для оформления расходов по автомобилям за текущий день. 
-- Процедура может быть вызвана один или несколько раз в день. 
-- В процедуре анализируются все заказы за день и автомобили в них. 
-- Для всех автомобилей, которые выполняли сегодня заказ формируется расходный документ 
-- в соответствии с стоимостью их обслуживания, при условии, что такой документ 
-- сформирован еще не был. Процедура возвращает суммарную стоимость обслуживания всех автомобилей.

CREATE OR REPLACE PROCEDURE
car_expense_evaluate (IN selected_date DATE, OUT summary_day_cost FLOAT)
LANGUAGE plpgsql
AS $$
DECLARE
    car_row RECORD; 
    expense_type INT := 2;
BEGIN
    summary_day_cost := 0;
    FOR car_row IN SELECT car_id, maintenance_cost_per_month 
    -- машины в собственности таксопарка, которые выполняли заказ в указанный день
    FROM (
        SELECT DISTINCT o.car_id, maintenance_cost_per_month FROM "order" o
        JOIN car ON car.car_id = o.car_id
        WHERE NOT cancelled AND start_time::DATE = selected_date AND property
    )
    LOOP
        IF NOT EXISTS (
            SELECT * FROM payment pa
            WHERE pa.car_id = car_row.car_id AND pa.type_id = expense_type AND pa.payment_time = selected_date
        ) THEN 
            INSERT INTO payment (type_id, payment_time, car_id) VALUES (expense_type, selected_date, car_row.car_id);
            RAISE NOTICE 'car_id = %, maintenance_cost = %', 
                car_row.car_id, ROUND((car_row.maintenance_cost_per_month / 30)::NUMERIC, 2);
            -- summary_day_cost := summary_day_cost + car_row.maintenance_cost_per_month / 30;
        ELSE
            RAISE NOTICE 'already exists for car_id = %', car_row.car_id;
        END IF;
        summary_day_cost := summary_day_cost + car_row.maintenance_cost_per_month / 30;
    END LOOP;
END;
$$;

DO $$
DECLARE
    result_cost FLOAT;
BEGIN
    CALL car_expense_evaluate('2026-04-13', result_cost);
    RAISE NOTICE 'summary_day_cost: %', ROUND(result_cost::NUMERIC, 2);
END;
$$;