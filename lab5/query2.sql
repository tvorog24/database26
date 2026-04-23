-- 2.	Получить отчет по работе водителей на автомобилях (отчет по договорам), представить в следую-щем виде:
-- Имя водителя; название автомобиля; номер договора; дата начала договора; дата окончания договора;
-- актуален ли договор (да/нет); число выполненных заказов по договору; число отказов по договору;
-- сумма заказов по договору; сумма платежей водителю.

-- все договоры и заказы по ним (если есть)
WITH cont_ext AS (
    SELECT o.order_id, o.cancelled, o.end_time, co.contract_id, o.order_time, co.start_date, co.end_date 
    FROM "order" o  
    RIGHT JOIN "contract" co ON o.car_id = co.car_id AND o.driver_id = co.driver_id
    AND DATE(o.order_time) >= co.start_date AND DATE(o.order_time) <= co.end_date
),
-- подсчет завершенных заказов по контракту
completed_stats AS (
    SELECT contract_id, COUNT(order_id) AS completed_amount 
    FROM cont_ext
    WHERE NOT cancelled AND end_time IS NOT NULL
    GROUP BY contract_id
),
-- подсчет отмененных заказов по контракту
cancelled_stats AS (
    SELECT contract_id, COUNT(order_id) AS cancelled_amount 
    FROM cont_ext
    WHERE cancelled
    GROUP BY contract_id
),
-- подсчет всех заказов по контракту
all_stats AS (
    SELECT contract_id, COUNT(order_id) AS all_amount FROM cont_ext
    GROUP BY contract_id
)
SELECT DISTINCT u.full_name AS driver_fio, cb.brand_name AS car_name, co.contract_id, co.start_date, co.end_date,

    (CASE 
        WHEN DATE(NOW()) BETWEEN co.start_date AND co.end_date
        THEN 'no'
        ELSE 'yes'
        END
    ) AS expired,

    COALESCE(comst.completed_amount, 0) AS completed_orders,
    COALESCE(canst.cancelled_amount, 0) AS cancelled_orders,
    COALESCE(ast.all_amount, 0) AS all_orders,
    -- вычисление суммы выплат
    (SELECT
        COALESCE( 
            ROUND(
                -- сумма ((время поездки * тариф + стоимость включенных доп. услуг) * скидка) 
                SUM(
                    ((EXTRACT(EPOCH FROM (o_ext.end_time - o_ext.start_time)) / 60)::INTEGER * cc.class_fare
                        + COALESCE(fas.facility_sum, 0)) 
                    * 
                    (CASE 
                        WHEN o_ext.reviews_count > 5 THEN 
                            CASE FLOOR(o_ext.rating)
                            WHEN 1 THEN 0.8
                            WHEN 2 THEN 0.85
                            WHEN 3 THEN 0.9
                            WHEN 4 THEN 0.95
                            WHEN 5 THEN 1
                            END
                        ELSE 0.8
                        END
                    )
                )::NUMERIC, 2
            ), 0 
        ) 
        -- создание таблицы со столбцами о заказах, рейтинге (на момент заказа), кол-ве оценок (на момент заказа) 
        -- где заказ выполнен по контракту (нужный водитель, нужная машина, попадает во временные рамки)
        -- и оплачен (есть выплата)
        FROM (SELECT o.*,
                -- подтягивание отзывов на заказы, которые были совершены ранее
                -- расчет среднего значения рейтинга по ним
                (SELECT AVG(r.rate) FROM "order" oo
                    JOIN review r ON r.order_id = oo.order_id AND r.user_id <> oo.driver_id
                    WHERE oo.driver_id = o.driver_id AND NOT oo.cancelled AND oo.end_time < o.end_time
                ) AS rating,
                -- расчет числа оценок
                COALESCE((SELECT COUNT(r.rate) FROM "order" oo
                    JOIN review r ON r.order_id = oo.order_id AND r.user_id <> oo.driver_id
                    WHERE oo.driver_id = o.driver_id AND NOT oo.cancelled AND oo.end_time < o.end_time
                ), 0) AS reviews_count
                FROM "order" o
                WHERE NOT o.cancelled AND o.driver_id = co.driver_id AND o.car_id = co.car_id AND DATE(o.order_time) >= co.start_date AND DATE(o.order_time) <= co.end_date
        ) o_ext
        JOIN car ON car.car_id = o_ext.car_id
        JOIN car_class cc ON car.class_id = cc.class_id
        -- проверка что есть выплата по заказу
        JOIN payment pa ON pa.order_id = o_ext.order_id AND pa.driver_id = o_ext.driver_id AND pa.type_id = 4
        LEFT JOIN (
            SELECT orf.order_id, orf.driver_id, SUM(f.facility_cost) AS facility_sum FROM ordered_facility orf
            JOIN facility f ON f.facility_id = orf.facility_id
            GROUP BY orf.order_id, orf.driver_id
        ) fas ON fas.order_id = o_ext.order_id AND fas.driver_id = o_ext.driver_id
    ) AS driver_salary
 
FROM "contract" co  
JOIN "user" u ON co.driver_id = u.user_id
JOIN car ON car.car_id = co.car_id
JOIN car_class cc ON cc.class_id = car.class_id
JOIN car_brand cb ON car.brand_id = cb.brand_id
LEFT JOIN completed_stats comst ON comst.contract_id = co.contract_id
LEFT JOIN cancelled_stats canst ON canst.contract_id = co.contract_id
LEFT JOIN all_stats ast ON ast.contract_id = co.contract_id

ORDER BY contract_id

