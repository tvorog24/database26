-- 3.	Получить отчет по клиентам таксопарка в виде:
-- Имя клиента; номер телефона клиента; дата регистрации; количество заказов; сумма всех выполненных заказов; 
-- сумма всех платежей от клиента; есть ли задолженность у клиента; выполняется ли сейчас заказ с этим клиентом (да/нет); 
-- дата последнего заказ клиента; количество заказов от клиента в текущем году.

-- все пассажиры и их поездки и платежи (если есть)
WITH pass_ext AS (
    SELECT o.order_id, DATE(o.order_time) AS order_date, o.cancelled, o.end_time, u.user_id AS passenger_id, pa.payment_id
    FROM "order" o
    LEFT JOIN payment pa ON pa.order_id = o.order_id AND pa.driver_id = o.driver_id AND pa.type_id = 3
    RIGHT JOIN "user" u ON o.passenger_id = u.user_id AND u.role_id = 1
),
-- сколько у пассажира заказов
order_amount AS (
    SELECT passenger_id, COUNT(DISTINCT order_id) AS amount 
    FROM pass_ext
    GROUP BY passenger_id
),
-- сколько у пассажира завершенных заказов
completed_amount AS (
    SELECT passenger_id, COUNT(order_id) AS amount 
    FROM pass_ext
    WHERE NOT cancelled AND end_time IS NOT NULL
    GROUP BY passenger_id
),
-- есть ли у пассажира завершенная неоплаченная поездка 
has_dept AS (
    SELECT passenger_id, 
    (CASE 
        WHEN EXISTS(
            SELECT 1 FROM pass_ext pe2
            WHERE NOT pe2.cancelled AND pe2.end_time IS NOT NULL AND pe2.passenger_id = pe.passenger_id AND pe2.payment_id IS NULL
        ) THEN 'yes'
        ELSE 'no'
        END
    ) AS has_dept 
    FROM pass_ext pe
    WHERE NOT cancelled and end_time IS NOT NULL
    GROUP BY passenger_id
),
-- самый последний заказ
latest_orders AS (
    SELECT passenger_id, MAX(order_date) AS latest_order
    FROM pass_ext
    GROUP BY passenger_id
),
-- сколько заказов в этом году
curr_year_orders AS (
    SELECT passenger_id, COUNT(DISTINCT order_date) AS amount
    FROM pass_ext
    WHERE EXTRACT(YEAR FROM order_date) = EXTRACT(YEAR FROM NOW())
    GROUP BY passenger_id
),
-- сколько выплат
payment_amount AS (
    SELECT passenger_id, COUNT(payment_id) AS amount
    FROM pass_ext
    GROUP BY passenger_id
)
SELECT u.full_name AS passenger_fio, u.phone_number, COALESCE(oa.amount, 0) AS all_orders, 
    COALESCE(ca.amount, 0) AS completed_orders, hd.has_dept, pa.amount AS payment_amount,

    -- создание таблицы со столбцами о заказах, рейтинге (на момент заказа), кол-ве оценок (на момент заказа) 
    -- где заказ выполнен, пассажир текущий чел и оплачен (есть выплата)
    (SELECT
        COALESCE(
            ROUND(
                SUM(
                    (((EXTRACT(EPOCH FROM (o_ext.end_time - o_ext.start_time)) / 60)::INTEGER * cc.class_fare)
                        + COALESCE(fs.facility_sum, 0)) 
                    * 
                    (CASE 
                        WHEN o_ext.reviews_count > 5 THEN 
                        1 - 
                            CASE FLOOR(COALESCE(o_ext.rating, 1))
                            WHEN 1 THEN 0
                            WHEN 2 THEN 0.02
                            WHEN 3 THEN 0.04
                            WHEN 4 THEN 0.06
                            WHEN 5 THEN 0.08
                            END
                        ELSE 1
                        END
                    )
                )::NUMERIC, 2
            ), 0 
        )
        FROM (SELECT o.*,
                -- подтягивание отзывов на заказы, которые были совершены ранее
                -- расчет среднего значения рейтинга по ним
                COALESCE((SELECT AVG(r.rate) FROM "order" oo
                    JOIN review r ON r.order_id = oo.order_id AND r.user_id <> oo.passenger_id
                    WHERE oo.passenger_id = o.passenger_id AND NOT oo.cancelled AND oo.end_time < o.end_time
                ), 0) AS rating,
                -- расчет числа оценок
                COALESCE((SELECT COUNT(r.rate) FROM "order" oo
                    JOIN review r ON r.order_id = oo.order_id AND r.user_id <> oo.passenger_id
                    WHERE oo.passenger_id = o.passenger_id AND NOT oo.cancelled AND oo.end_time < o.end_time
                ), 0) AS reviews_count
                FROM "order" o
                WHERE NOT o.cancelled AND o.end_time IS NOT NULL AND o.passenger_id = u.user_id 
        ) o_ext
        JOIN car ON car.car_id = o_ext.car_id
        JOIN car_class cc ON car.class_id = cc.class_id
        JOIN payment pa ON pa.order_id = o_ext.order_id AND pa.driver_id = o_ext.driver_id AND pa.type_id = 3
        LEFT JOIN (
            SELECT orf.order_id, orf.driver_id, SUM(f.facility_cost) AS facility_sum FROM ordered_facility orf
            JOIN facility f ON f.facility_id = orf.facility_id
            GROUP BY orf.order_id, orf.driver_id
        ) fs ON fs.order_id = o_ext.order_id AND fs.driver_id = o_ext.driver_id
    ) AS spent_money,

    lo.latest_order, COALESCE(cyo.amount, 0) AS current_year_orders

FROM "user" u
LEFT JOIN order_amount oa ON u.user_id = oa.passenger_id
LEFT JOIN completed_amount ca ON u.user_id = ca.passenger_id 
JOIN has_dept hd ON u.user_id = hd.passenger_id 
LEFT JOIN latest_orders lo ON u.user_id = lo.passenger_id 
LEFT JOIN curr_year_orders cyo ON cyo.passenger_id = u.user_id
LEFT JOIN payment_amount pa ON pa.passenger_id = u.user_id

ORDER BY u.user_id



