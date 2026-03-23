import psycopg2
from psycopg2.extras import execute_values
from faker import Faker
import logging
import random
import csv
from datetime import datetime, timedelta
from transliterate import translit

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s'
)

try:
    conn = psycopg2.connect(
        dbname='db26',
        user='postgres',
        password='090301',
        host='localhost',
        port='5432'
    )
    conn.autocommit = False
    cursor = conn.cursor()
    logging.info('Подключение к бд установлено')
except Exception as e:
    logging.error(f'Ошибка подключения к бд: {e}')
    raise

fake = Faker('ru_RU')

# заполнение user_role ->

roles_data = [
    ('Пассажир',),
    ('Водитель',),
    ('Менеджер',),
    ('Управляющий',)
]

execute_values(cursor,
    "INSERT INTO user_role (role_name) VALUES %s",
    roles_data
)
logging.info('Таблица user_role заполнена')
conn.commit()

# заполнение user ->

users_data = []
n_passengers = 10000
n_drivers = 1000
n_managers = 100
n_supervisors = 10

role_id_array = [1 for _ in range(n_passengers)] + \
                [2 for _ in range(n_drivers)] + \
                [3 for _ in range(n_managers)] + \
                [4 for _ in range(n_supervisors)] 

for role_id in role_id_array:
    name = fake.name()
    name_list = name.lower().split()
    login_base = translit(''.join([name_list[0], name_list[1][0], name_list[2][0]]), 'ru', reversed=True)
    login = login_base + str(random.randint(1, 9999))
    birth_date = fake.date_of_birth(minimum_age=18, maximum_age=99)
    passport_full = fake.unique.numerify(text='##########')
    passport_ser = passport_full[:4]
    passport_num = passport_full[4:]
    phone = fake.unique.numerify(text='8##########')
    hash = fake.unique.hexify(text='^'*64)
    gender = random.choice(['male', 'female'])
    users_data.append((login, hash, passport_num, passport_ser, name, phone, birth_date, role_id, gender))

execute_values(cursor,
    '''INSERT INTO "user" (
        user_login, 
        password_hash, 
        passport_number, 
        passport_series, 
        full_name, 
        phone_number, 
        birth_date,
        role_id,
        gender
    ) VALUES %s''',
    users_data
)
logging.info('Таблица users заполнена')
conn.commit()

# заполнение car_brand ->

brands_models = dict()
with open('dbs_for_generating/brands_models.csv') as csvfile:
    reader = csv.reader(csvfile, delimiter=';')
    for row in reader:
        brand, model = row[:2]
        if brand in brands_models.keys():
           brands_models[brand] += [model]
        else:
            brands_models[brand] = [model]

execute_values(cursor,
    "INSERT INTO car_brand (brand_name) VALUES %s", [(brand,) for brand in brands_models])

logging.info('Таблица car_brand заполнена')
conn.commit()

# заплнение car_model ->

all_brands = list(brands_models.keys())
all_models = []
for models in brands_models.values():
    all_models += list(models)

for brand_id, brand_name in enumerate(all_brands, start=1):
    brand_models = brands_models[brand_name] # вытаскиваем из словаря все модели бренда
    models = [(brand_models[j], brand_id) for j in range(len(brand_models))]
    execute_values(cursor,
        "INSERT INTO car_model (model_name, brand_id) VALUES %s",
        models
    )
logging.info('Таблица car_model заполнена')
conn.commit()

# заполнение car_class ->

car_classes_data = [('Эконом', 10), ('Стандарт', 12.5), ('Комфорт', 15), ('Бизнес', 20), ('Премиум', 30)]
execute_values(cursor,
    "INSERT INTO car_class (class_name, class_fare) VALUES %s",
    car_classes_data
)
logging.info('Таблица car_class заполнены')
conn.commit()

# заполнение car ->

n_cars = 5000
cars_data = []
for _ in range(n_cars):
    reg_num = fake.unique.bothify(letters='ABEKMOPCTYX', text='?###??##')
    year = random.randint(1950, 2026)
    rent = random.triangular(1000, 5000, 150000) # за день
    maintenance = random.triangular(5000, 10000, 100000) # за месяц
    class_id = random.randint(1, len(car_classes_data))
    brand_id = random.randint(1, len(all_brands))
    model_id = all_models.index(random.choice(brands_models[all_brands[brand_id - 1]])) + 1
    property = random.choice([True, False])
    cars_data.append((
        reg_num, class_id, year, rent, maintenance, property, brand_id, model_id 
    ))

execute_values(cursor,
    '''INSERT INTO car (
        car_number,
        class_id,
        release_year, 
        rent_cost_per_day, 
        maintenance_cost_per_month, 
        property, 
        brand_id, 
        model_id
    ) VALUES %s''',
    cars_data
)

logging.info('Таблица car заполнена')
conn.commit()

# заполнение facility ->

facilities_data = [
    ('Детское кресло', 50),
    ('Перевозка животных', 100),
    ('Сочувственное слушание', 199.99),
    ('Побибикать на светофоре', 249.5),
    ('Разговор с водителем о политике', 499.99),
    ('Дать совет водителю', 749.5),
]
all_facilities_id = [i + 1 for i in range(len(facilities_data))]

execute_values(cursor,
    "INSERT INTO facility (facility_name, facility_cost) VALUES %s",
    facilities_data
)
logging.info('Таблица facility заполнена')
conn.commit()

# заполнение car_facility ->

car_facilities_data = []
for car_id in range(1, n_cars + 1):
    for facility_id in random.sample(all_facilities_id, k=random.randint(0, len(all_facilities_id))):
        car_facilities_data.append((facility_id, car_id))

execute_values(cursor,
    "INSERT INTO car_facility (facility_id, car_id) VALUES %s",
    car_facilities_data
)
logging.info('Таблица car_facility заполнена')
conn.commit()

# заполнение contract ->

n_contracts = 20000
contracts_data = []

for _ in range(n_contracts):
    start_date = fake.date_between(start_date='-5y', end_date='today')
    end_date = fake.date_between(start_date=start_date + timedelta(days=1), end_date='+5y')
    car_id = random.randint(1, n_cars)
    driver_id = random.randint(n_passengers + 1, n_passengers + n_drivers)
    manager_id = random.randint(n_passengers + n_drivers + 1, n_passengers + n_drivers + n_managers)
    contracts_data.append((start_date, end_date, manager_id, driver_id, car_id))

execute_values(cursor,
    '''INSERT INTO contract (
        "start_date",
        end_date, 
        manager_id, 
        driver_id, 
        car_id
    ) VALUES %s''',
    contracts_data
)
logging.info('Таблица contract заполнена')
conn.commit()

# заполнение order ->

n_orders = 100000
orders_data = []
all_drivers_ids = set([i for i in range(n_passengers + 1, n_passengers + n_drivers + 1)])

for order_id in range(1, n_orders + 1):
    from_addr = fake.address().replace('\n', ', ')
    to_addr = fake.address().replace('\n', ', ')
    passenger_id = random.randint(1, n_passengers)
    appear_at = fake.date_time_between(start_date='-5y', end_date='now')
    completed = random.choices([True, False], weights=[3, 1])[0]
    used_driver_ids = set()
    while len(used_driver_ids) < n_drivers: 
        if completed:
            start_at = appear_at + timedelta(minutes=random.randint(1, 10))
            finish_at = start_at + timedelta(minutes=random.randint(10, 180))
        else:
            start_at = None
            finish_at = None
        driver_id = random.choice(list(all_drivers_ids.difference(used_driver_ids)))
        used_driver_ids.add(driver_id)
        car_id = random.randint(1, n_cars)
        orders_data.append((
            order_id, driver_id, from_addr, to_addr, appear_at, completed, start_at, finish_at, passenger_id, car_id
        ))
        if completed:
            break
        completed = random.choices([True, False], weights=[3, 1])[0]

execute_values(cursor,
    '''INSERT INTO "order" (
        order_id,
        driver_id,
        location_from,
        location_to,
        order_time,
        completed,
        start_time,
        end_time,
        passenger_id, 
        car_id
    ) VALUES %s''',
    orders_data
)
logging.info('Таблица order заполнена')
conn.commit()

# заполнение ordered_facility ->

ordered_facilities = []
for order_id in range(1, n_orders + 1):
    if random.choices([True, False], weights=[1, 9])[0]:
        driver_ids = [o[1] for o in list(filter(lambda x: x[0] == order_id, orders_data))]
        for facility_id in random.sample([i + 1 for i in range(len(facilities_data))], k=random.randint(1, len(facilities_data))):
            for driver_id in driver_ids:
                ordered_facilities.append((facility_id, order_id, driver_id))

execute_values(cursor,
    '''INSERT INTO ordered_facility (facility_id, order_id, driver_id) VALUES %s''',
    ordered_facilities)
logging.info('Таблица ordered_facility заполнена')
conn.commit()

# заполнение review ->

passenger_reviews = dict()
with open('dbs_for_generating/passenger_reviews.csv', encoding='utf-8') as csvfile:
    reader = csv.reader(csvfile, delimiter=';')
    for row in reader:
        rate, content = int(row[0]), row[1]
        if rate in passenger_reviews.keys():
            passenger_reviews[rate] += [content]
        else:
            passenger_reviews[rate] = [content]

driver_reviews = dict()
with open('dbs_for_generating/driver_reviews.csv', encoding='utf-8') as csvfile:
    reader = csv.reader(csvfile, delimiter=';')
    for row in reader:
        rate, content = int(row[0]), row[1]
        if rate in driver_reviews.keys():
            driver_reviews[rate] += [content]
        else:
            driver_reviews[rate] = [content]

reviews_data = []
completed_orders = list(filter(lambda x: x[5], orders_data))
for order in completed_orders:
    # отзыв пасссажира
    if random.choices([True, False], weights=[2, 1])[0]:
        rate = random.randint(1, 5)
        if random.choice([True, False]):
            text = random.choice(passenger_reviews[rate])
        else:
            text = None
        reviews_data.append((order[0], order[1], order[8], text, rate))
    # отзыв водителя
    if random.choices([True, False], weights=[2, 1])[0]:
        rate = random.randint(1, 5)
        if random.choice([True, False]):
            text = random.choice(driver_reviews[rate])
        else:
            text = None
        reviews_data.append((order[0], order[1], order[1], text, rate))

execute_values(cursor, 
    '''INSERT INTO review (order_id, driver_id, user_id, content, rate) VALUES %s''', 
    reviews_data)
logging.info('Таблица review заполнена')
conn.commit()

# заполнение payment_type ->

payment_types = [
    ('Аренда автомобиля',),         # 1
    ('Обслуживание автомобиля',),   # 2
    ('Выполненный заказ',),         # 3
    ('Выплата водителю за заказ',)  # 4
]

execute_values(cursor, 
    '''INSERT INTO payment_type (type_name) VALUES %s''', 
    payment_types)
logging.info('Таблица payment_type заполнена')
conn.commit()

# заполнение payment ->

payments_data = []
for order in completed_orders: # выплаты за заказ (3 и 4)
    order_id = order[0]
    driver_id = order[1] 
    car_id = None
    time = order[7] + timedelta(minutes=random.randint(1, 10))
    for type_id in (3, 4):
        payments_data.append((type_id, time, car_id, order_id, driver_id))

for contract in contracts_data: # выплаты за аренду (1)
    type_id = 1
    order_id = None
    driver_id = None
    car_id = contract[4]
    time = fake.date_time_between(start_date=contract[0], end_date='now')
    car_info = cars_data[car_id - 1]
    if car_info[4] and random.choice([True, False]):
        payments_data.append((type_id, time, car_id, order_id, driver_id))

for car_id, car in enumerate(cars_data, start=1): # выплаты за обслуживание (2)
    type_id = 2
    order_id = None
    driver_id = None
    time = fake.date_time_between(start_date=datetime(car[1], 1, 1), end_date='now')
    car_info = cars_data[car_id - 1]
    if car_info[4] and random.choice([True, False]):
        payments_data.append((type_id, time, car_id, order_id, driver_id))

execute_values(cursor,
    '''INSERT INTO payment (
        type_id, 
        payment_time,
        car_id,
        order_id,
        driver_id) VALUES %s''',
    payments_data)
logging.info('Таблица payment заполнена')
conn.commit()

logging.info('Всё!')

cursor.close()
conn.close()