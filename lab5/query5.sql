-- 5.	Получить статистику по отказам в виде:
-- Причина отказа; число отказов; дата последнего отказа; число разных водителей, 
-- указавших этот отказ; имя водитель и количество раз, для водителя, чаще всего указывавшего эту причину отказа;
-- имя клиента и число раз для клиента, чаще всего получавшего эту причину отказа.

-- так как в тз нет причин отказов, то
-- отказ -> доп. услуга

-- доп. услуги + неотмененные заказы, где они были указаны + водитель + пассажир 
WITH order_stats AS (
    SELECT
        f.facility_id, f.facility_name, ofc.order_id, o.driver_id, o.passenger_id, u1.full_name AS driver_fio,
        u2.full_name AS passenger_fio, o.order_time, o.cancelled
    FROM facility f
    LEFT JOIN ordered_facility ofc ON ofc.facility_id = f.facility_id
    JOIN "order" o ON o.order_id = ofc.order_id AND o.driver_id = ofc.driver_id
    JOIN "user" u1 ON u1.user_id = o.driver_id
    JOIN "user" u2 ON u2.user_id = o.passenger_id
    WHERE NOT o.cancelled
), 
-- для каждой доп. услуги: сколько раз заказывалась, когда в последний раз, сколько разных водителей выполняли
facility_stats AS (
    SELECT
        facility_id, facility_name, COUNT(order_id) AS times_ordered, 
        MAX(DATE(order_time)) AS latest_order, COUNT(DISTINCT driver_id) AS driver_amount
    FROM order_stats
    GROUP BY facility_id, facility_name
),
-- для каждой услуги и водителя: сколько раз он выполнял услугу и каков ранк водителя по выполнению услуги
driver_stats AS (
    SELECT
        facility_id, driver_id, driver_fio, COUNT(*) AS driver_orders,
        -- нумерует строки в пределах одной доп. услуги по кол-ву заказов, где она есть
        ROW_NUMBER() OVER (PARTITION BY facility_id ORDER BY COUNT(*) DESC) AS pos
    FROM order_stats
    GROUP BY facility_id, driver_id, driver_fio
),
-- для каждой услуги и пассажира: сколько раз он пользовался услугой 
-- и каков ранк пассажира по пользованию услугой
passenger_stats AS (
    SELECT
        facility_id, passenger_id, passenger_fio, COUNT(*) AS passenger_orders,
        ROW_NUMBER() OVER (PARTITION BY facility_id ORDER BY COUNT(*) DESC) AS pos
    FROM order_stats
    GROUP BY facility_id, passenger_id, passenger_fio
)
SELECT
    fst.facility_name,
    fst.times_ordered,
    fst.latest_order,
    fst.driver_amount,
    dst.driver_fio AS most_driver_fio,
    dst.driver_orders AS most_driver_orders,
    pst.passenger_fio AS most_passenger_fio,
    pst.passenger_orders AS most_passenger_orders

FROM facility_stats fst

LEFT JOIN driver_stats dst ON dst.facility_id = fst.facility_id AND dst.pos = 1
LEFT JOIN passenger_stats pst ON pst.facility_id = fst.facility_id AND pst.pos = 1

ORDER BY fst.facility_id
