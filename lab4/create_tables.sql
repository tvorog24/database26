CREATE TABLE car_class (
    class_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    class_name TEXT NOT NULL UNIQUE,
    class_fare FLOAT NOT NULL CHECK (class_fare > 0)
);

CREATE TABLE facility (
    facility_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    facility_name TEXT NOT NULL UNIQUE,
    facility_cost FLOAT NOT NULL CHECK (facility_cost > 0)
);

CREATE TABLE payment_type (
    type_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    type_name TEXT NOT NULL UNIQUE
);

CREATE TABLE user_role (
    role_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role_name TEXT NOT NULL UNIQUE
);

CREATE TYPE gender_type AS ENUM ('male', 'female');

CREATE TABLE "user" (
    user_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_login TEXT NOT NULL UNIQUE,
    password_hash CHAR(64) NOT NULL,
    passport_number CHAR(6) NOT NULL CHECK (passport_number ~ '^[0-9]{6}$'),
    passport_series CHAR(4) NOT NULL CHECK (passport_series ~ '^[0-9]{4}$'),
    full_name TEXT NOT NULL,
    phone_number CHAR(11) NOT NULL CHECK (phone_number ~ '^8[0-9]{10}$'),
    birth_date DATE NOT NULL CHECK (
        birth_date <= CURRENT_DATE - INTERVAL '18 years' 
        AND birth_date >= CURRENT_DATE - INTERVAL '100 years' 
    ),
    role_id INT NOT NULL REFERENCES user_role (role_id) ON DELETE RESTRICT,
    gender gender_type NOT NULL,
    CONSTRAINT uq_passport UNIQUE (passport_number, passport_series)
);

CREATE TABLE car_brand (
    brand_id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    brand_name TEXT NOT NULL UNIQUE
);

CREATE TABLE car_model (
    model_id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    model_name TEXT NOT NULL UNIQUE,
    brand_id BIGINT NOT NULL REFERENCES car_brand (brand_id) ON DELETE RESTRICT
);

CREATE TABLE car (
    car_id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    car_number VARCHAR(9) NOT NULL,
    class_id INT NOT NULL REFERENCES car_class (class_id) ON DELETE RESTRICT,
    release_year INT NOT NULL CHECK (release_year > 1900 AND release_year < 2100),
    rent_cost_per_day FLOAT NOT NULL CHECK (rent_cost_per_day > 0),
    maintenance_cost_per_month FLOAT NOT NULL CHECK (maintenance_cost_per_month > 0),
    property BOOLEAN NOT NULL,
    brand_id INT NOT NULL REFERENCES car_brand (brand_id) ON DELETE RESTRICT,
    model_id INT NOT NULL REFERENCES car_model (model_id) ON DELETE RESTRICT
);

CREATE TABLE contract (
    cotract_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "start_date" DATE NOT NULL,
    end_date DATE NOT NULL CHECK ("start_date" < end_date),
    manager_id BIGINT NOT NULL REFERENCES "user" (user_id) ON DELETE RESTRICT,
    driver_id BIGINT NOT NULL REFERENCES "user" (user_id) ON DELETE RESTRICT,
    car_id BIGINT NOT NULL REFERENCES car (car_id) ON DELETE RESTRICT
);

CREATE TABLE car_facility (
    facility_id INT NOT NULL REFERENCES facility (facility_id) ON DELETE RESTRICT,
    car_id BIGINT NOT NULL REFERENCES car (car_id) ON DELETE RESTRICT,
    CONSTRAINT pk_facility_car PRIMARY KEY (facility_id, car_id)
);

CREATE TABLE "order" (
    order_id BIGINT NOT NULL,
    driver_id BIGINT NOT NULL REFERENCES "user" (user_id) ON DELETE RESTRICT,
    location_from TEXT NOT NULL,
    location_to TEXT NOT NULL,
    order_time TIMESTAMP NOT NULL,
    completed BOOLEAN NOT NULL,
    start_time TIMESTAMP CHECK (
        NOT completed AND start_time IS NULL 
        OR 
        completed AND start_time IS NOT NULL
    ), 
    end_time TIMESTAMP CHECK (
        NOT completed AND end_time IS NULL 
        OR 
        completed AND end_time IS NOT NULL AND start_time < end_time AND order_time < start_time
    ),
    passenger_id BIGINT NOT NULL REFERENCES "user" (user_id) ON DELETE RESTRICT,
    car_id BIGINT NOT NULL REFERENCES car (car_id) ON DELETE RESTRICT,
    CONSTRAINT pk_order_driver PRIMARY KEY (order_id, driver_id)
);

CREATE TABLE review (
    order_id BIGINT NOT NULL,
    driver_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL, 
    "content" TEXT,
    rate INT NOT NULL CHECK (rate >= 1 AND rate <= 5),
    FOREIGN KEY (order_id, driver_id) REFERENCES "order" (order_id, driver_id) ON DELETE RESTRICT,
    CONSTRAINT pk_order_user PRIMARY KEY (order_id, user_id)
);

CREATE TABLE payment (
    payment_id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    type_id INT NOT NULL REFERENCES payment_type (type_id) ON DELETE RESTRICT,
    payment_time TIMESTAMP NOT NULL,
    car_id BIGINT REFERENCES car (car_id) ON DELETE RESTRICT,
    order_id BIGINT,
    driver_id BIGINT,
    FOREIGN KEY (order_id, driver_id) REFERENCES "order" (order_id, driver_id) ON DELETE RESTRICT,
    CONSTRAINT chk_car_order_elimination CHECK (
        car_id IS NULL AND order_id IS NOT NULL AND driver_id IS NOT NULL
        OR car_id IS NOT NULL AND order_id IS NULL AND driver_id IS NULL
    ) 
);

CREATE TABLE ordered_facility (
    facility_id INT NOT NULL REFERENCES facility (facility_id) ON DELETE RESTRICT,
    order_id BIGINT NOT NULL,
    driver_id BIGINT NOT NULL,
    FOREIGN KEY (order_id, driver_id) REFERENCES "order" (order_id, driver_id) ON DELETE RESTRICT
);