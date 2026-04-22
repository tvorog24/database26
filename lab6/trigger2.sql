-- При добавлении нового договора о сотрудничестве между водителем и таксопарком, 
-- необходимо убедиться, что машина и водитель не участвуют ни в каких актуальных договорах. 
-- В случае участия пользователя в каком-нибудь актуальном договоре вывести 
-- соответствующее сообщение об ошибке.   

CREATE OR REPLACE FUNCTION check_contract()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE 
    active_contracts_cnt INT;
    active_contract_id BIGINT;
BEGIN
    -- считает число актуальных контрактов, берет самый первый id
    SELECT COUNT(*), MIN(co.contract_id) INTO active_contracts_cnt, active_contract_id 
    FROM "contract" co
    WHERE co.driver_id = NEW.driver_id AND CURRENT_DATE BETWEEN co.start_date AND co.end_date;
     
    IF active_contracts_cnt > 0 THEN RAISE EXCEPTION 'driver (driver_id = %) already has active contract (contract_id = %)', NEW.driver_id, active_contract_id;
    ELSE 

        SELECT COUNT(*), MIN(co.contract_id) INTO active_contracts_cnt, active_contract_id FROM "contract" co
        WHERE co.car_id = NEW.car_id AND CURRENT_DATE BETWEEN co.start_date AND co.end_date;

        IF active_contracts_cnt > 0 THEN RAISE EXCEPTION 'car (car_id = %) already mentioned in active contract (contract_id = %)', NEW.car_id, active_contract_id;
        ELSE RETURN NEW;
        END IF;
    END IF;

END;
$$;

CREATE OR REPLACE TRIGGER new_contract
BEFORE INSERT ON "contract"
FOR EACH ROW
EXECUTE FUNCTION check_contract();

-- FREE driver_id
-- driver_id = 10656
-- driver_id = 10727
-- driver_id = 10823
-- driver_id = 10219
-- driver_id = 10659
-- driver_id = 10891
-- driver_id = 10856
-- FREE car_id
-- car_id = 115
-- car_id = 131
-- car_id = 203
-- car_id = 210
-- car_id = 213
-- car_id = 213

-- BUSY driver_id
-- driver_id = 10756
-- driver_id = 10997
-- driver_id = 10777
-- BUSY car_id
-- car_id = 26
-- car_id = 30
-- car_id = 78


INSERT INTO "contract" ("start_date", end_date, manager_id, driver_id, car_id) 
                VALUES (CURRENT_DATE, DATE('30-04-26'), 11110, 10997, 115);

-- DELETE FROM "contract" 
-- WHERE contract_id > 750;

