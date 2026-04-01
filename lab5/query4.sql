-- 4.	Получить отчет по выполняемым (в статусе: только создан, водитель найден, поездка начата) заказам в следующем виде:
-- Номер заказа, дата начала, ФИО клиента, статус, выполняющий водитель, автомобиль, число отказов, 
-- текущий тариф, текущая стоимость, пункт отправки, пункт назначения, ответственный диспетчер.

SELECT "order".order_id, DATE("order".start_time) AS "start_date", u.full_name AS passenger_fio,  

    (CASE 
        WHEN "order".completed THEN 'completed'
        ELSE 'cancelled'
        END
    ) AS "status",
    
    "order".driver_id, car.car_number,

    -- сколько отмен было по заказу
    (SELECT COUNT(*) FROM "order" oo
        WHERE oo.order_id = "order".order_id AND NOT oo.completed
    ) AS cancellation_amount,

    -- тариф
    cc.class_name AS fare, 
    
    -- вычисление стоимости данного заказа для пассажира с учетом его рейтинга
    COALESCE(
        ROUND(
            -- время поездки * тариф + стоимость заказанных доп. услуг
            ((EXTRACT(EPOCH FROM ("order".end_time - "order".start_time)) / 60)::INTEGER * cc.class_fare
                + COALESCE(
                    (SELECT SUM(f.facility_cost)
                        FROM ordered_facility orf
                        JOIN facility f ON f.facility_id = orf.facility_id
                        WHERE orf.order_id = "order".order_id and orf.driver_id = "order".driver_id
                    ), 0
                )
            )::NUMERIC
            -- скидка (применяется, если оценок больше 5) 
            * (CASE
                    WHEN (
                        SELECT COUNT(*)
                        FROM "order" o2
                        JOIN review r2 ON r2.order_id = o2.order_id AND r2.user_id <> o2.passenger_id
                        WHERE
                            o2.passenger_id = "order".passenger_id
                            AND o2.completed
                            AND o2.end_time < "order".end_time
                    ) > 5
                    THEN
                        CASE FLOOR(
                                COALESCE(
                                    (SELECT AVG(r3.rate)
                                        FROM "order" o3
                                        JOIN review r3 ON r3.order_id = o3.order_id AND r3.user_id <> o3.passenger_id
                                        WHERE o3.passenger_id = "order".passenger_id
                                            AND o3.completed
                                            AND o3.end_time < "order".end_time
                                    ), 1
                                )
                            )
                            WHEN 1 THEN 1
                            WHEN 2 THEN 0.98
                            WHEN 3 THEN 0.96
                            WHEN 4 THEN 0.94
                            WHEN 5 THEN 0.92
                        END
                    ELSE 1
                END
            )::NUMERIC, 2
        ), 0
    ) AS "cost",

    "order".location_from AS "from", "order".location_to AS "to"

FROM "order" 

JOIN "user" u ON u.user_id = "order".passenger_id
JOIN car ON car.car_id = "order".car_id
JOIN car_class cc ON cc.class_id = car.class_id

ORDER BY "order".order_id
