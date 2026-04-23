-- 1.	Получить распределения заказов по дням недели и времени с шагом в 3 часа. 
-- Статистика рассчитывается только по тем дням, в которых был хотя бы один заказ. 
-- Результат представить в виде 56 строк:
-- День недели; период времени (например, 09:00 – 12:00). 
-- Все следующие параметры рассчитываются для данного дня недели и периода времени: 
-- общее число заказов за все время работы таксопарка; общая сумма заказов; 
-- среднее число заказов в день в этот период времени; 
-- является ли этот промежуток времени самым нагруженным в данный день недели (да/нет); 
-- является ли этот промежуток времени самым нагруженным в неделе (да/нет).

-- дата + начало вр. промежутка + кол-во заказов 
WITH per_date_and_span AS (
    SELECT DATE(order_time) AS order_date, (EXTRACT(HOUR FROM order_time)::INTEGER / 3 * 3) AS span_start,
    COUNT(DISTINCT order_id) AS order_amount 
    FROM "order"
    GROUP BY order_date, span_start
),
-- вместо даты день недели + начало вр. промежутка + кол-во заказов
per_day_and_span AS (
    SELECT EXTRACT (DOW FROM order_date) AS week_day, 
    span_start, order_amount
    FROM per_date_and_span
),
-- день недели + начало вр. промежутка + среднее заказов + сумма заказов 
order_stats AS (
    SELECT week_day, span_start, AVG(order_amount) AS average, SUM(order_amount) AS all_in_all
    FROM per_day_and_span
    GROUP BY week_day, span_start
),
-- добавление ранков по загруженности (среднему числу заказов)
day_load AS (
    SELECT os.*, RANK() OVER (PARTITION BY week_day ORDER BY average DESC) AS day_pos,
    RANK() OVER (ORDER BY average DESC) AS week_pos
    FROM order_stats os
)
SELECT (CASE os.week_day
            WHEN 0 THEN 'вс'
            WHEN 1 THEN 'пн'
            WHEN 2 THEN 'вт'
            WHEN 3 THEN 'ср'
            WHEN 4 THEN 'чт'
            WHEN 5 THEN 'пт'
            WHEN 6 THEN 'сб'
            END
        ) as week_day,
        
        CONCAT(
            TO_CHAR(MAKE_TIME(os.span_start, 0, 0), 'HH24:MI'),
            ' - ',
            TO_CHAR(MAKE_TIME(os.span_start + 3, 0, 0), 'HH24:MI')
        ) AS time_span,

        ROUND(dl.average, 1) AS average, dl.all_in_all, 
        (CASE WHEN day_pos = 1 THEN 'yes' ELSE 'no' END) AS max_day_load,
        (CASE WHEN week_pos = 1 THEN 'yes' ELSE 'no' END) AS max_week_load,
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
            -- создание таблицы со столбцами о заказах, рейтинге (на момент заказа), кол-ве оценок (на момент заказа) 
            -- где заказ выполнен и попадает во временной промежуток и день недели
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
                    WHERE NOT o.cancelled AND MAKE_TIME(EXTRACT(HOUR FROM o.order_time)::INTEGER, 0, 0) BETWEEN 
                    MAKE_TIME(os.span_start, 0, 0) AND MAKE_TIME(os.span_start + 2, 59, 59) 
                    AND EXTRACT(DOW FROM o.order_time) = os.week_day
            ) o_ext
            JOIN car ON car.car_id = o_ext.car_id
            JOIN car_class cc ON car.class_id = cc.class_id
            -- проверка что есть выплата по заказу
            JOIN payment pa ON pa.order_id = o_ext.order_id AND pa.driver_id = o_ext.driver_id AND pa.type_id = 3
            -- подтягивание стоимости заказанных доп. услуг
            LEFT JOIN (
                SELECT orf.order_id, orf.driver_id, SUM(f.facility_cost) AS facility_sum FROM ordered_facility orf
                JOIN facility f ON f.facility_id = orf.facility_id
                GROUP BY orf.order_id, orf.driver_id
            ) fas ON fas.order_id = o_ext.order_id AND fas.driver_id = o_ext.driver_id
        ) AS "money"

FROM order_stats os
JOIN day_load dl ON dl.week_day = os.week_day AND dl.span_start = os.span_start
ORDER BY os.week_day, os.span_start


        