CREATE DATABASE MadridMetro;
USE MadridMetro;

drop table MultiEntranceCard;
drop table PrepaidCard;
drop table OwnsPrepaidCard;
drop table OwnsMultiEntranceCard;
drop table ClientType_price;
drop table Discount;
drop table CityKey;
drop table ZoneKey;

drop table MetroClient;
CREATE TABLE MetroClient (
id_num VARCHAR(15) NOT NULL,
id_type ENUM('Passport', 'NIF', 'NIE') NOT NULL,
client_type ENUM('Normal', 'Senior', 'Abono Joven'),
first_name VARCHAR(20),
middle_inital VARCHAR(1),
last_name VARCHAR(20),
email VARCHAR(50),
phone VARCHAR(50),
street VARCHAR(40),
city VARCHAR(30),
zipcode VARCHAR(10),
birthday DATE,
age INT,
discount ENUM ('N', 'S', 'D', 'ND', 'SD'),
student_state BOOL DEFAULT FALSE,
PRIMARY KEY (id_num)
);

CREATE TABLE MultiEntranceCard (
card_num VARCHAR(10) NOT NULL,
initial_amount DECIMAL(5,2) NOT NULL,
balance DECIMAL(5,2),
cost_per_ride DECIMAL(5,2) DEFAULT 1.70,
add_money_amount DECIMAL(5,2),
ride_metro BOOLEAN DEFAULT FALSE,
PRIMARY KEY (card_num)
);

drop table PrepaidCard; 
CREATE TABLE PrepaidCard (
card_num VARCHAR(10) NOT NULL,
card_state ENUM('active', 'inactive') DEFAULT 'inactive',
card_fee DECIMAL(5,2),
last_charge DATE,
expiration DATE,
PRIMARY KEY (card_num)
);

drop table ClientType_Price;
CREATE TABLE ClientType_Price (
type ENUM('Senior', 'Abono Joven'),
price DECIMAL (5,2)
);

drop table Discount;
CREATE TABLE Discount (
type ENUM('Big Family Normal', 'Big Family Special', 'Senior/Disability'),
amount DECIMAL(5,2)
);

drop table CityKey;
CREATE TABLE CityKey (
zone_name VARCHAR(255) PRIMARY KEY NOT NULL,
zone ENUM('A', 'B1', 'B2', 'B3', 'C1', 'C2', 'E1', 'E2') NOT NULL
);

drop table ZoneKey;
CREATE TABLE ZoneKey(
zone ENUM('A', 'B1', 'B2', 'B3', 'C1', 'C2', 'E1', 'E2') PRIMARY KEY NOT NULL,
zone_fee DECIMAL(5,2)
);

drop table OwnsPrepaidCard;
CREATE TABLE OwnsPrepaidCard (
    owner_id_num VARCHAR(15),
    card_num VARCHAR(10),
    PRIMARY KEY (owner_id_num, card_num),
    FOREIGN KEY (owner_id_num) REFERENCES MetroClient (id_num) ON DELETE CASCADE ON UPDATE NO ACTION,
    FOREIGN KEY (card_num) REFERENCES PrepaidCard (card_num) ON DELETE CASCADE ON UPDATE NO ACTION
);

drop table OwnsMultiEntranceCard;
CREATE TABLE OwnsMultiEntranceCard (
owner_id_num VARCHAR(15),
card_num VARCHAR(10),
FOREIGN KEY (owner_id_num) REFERENCES MetroClient (id_num) ON DELETE CASCADE ON UPDATE NO ACTION,
FOREIGN KEY (card_num) REFERENCES MultiEntranceCard (card_num) ON DELETE CASCADE ON UPDATE NO ACTION
);

drop trigger set_age;
DELIMITER //
CREATE TRIGGER set_age
BEFORE INSERT ON MetroClient
FOR EACH ROW
BEGIN
	DECLARE curr_year INT;
    DECLARE birth_year INT;
    DECLARE curr_date DATE;
    
    SET curr_date = CURRENT_DATE();
    SET curr_year = YEAR(curr_date);
    SET birth_year = YEAR(NEW.birthday);
    
    SET NEW.age = curr_year - birth_year;
    
    IF (MONTH(curr_date) < MONTH(NEW.birthday)) OR (MONTH(curr_date) = MONTH(NEW.birthday) AND DAY(curr_date) < DAY(NEW.birthday)) THEN
        SET NEW.age = NEW.age - 1;
    END IF;
END; //
DELIMITER ;

drop trigger set_client_type;
DELIMITER //
CREATE TRIGGER set_client_type
BEFORE INSERT ON MetroClient
FOR EACH ROW
BEGIN
    IF NEW.age < 26 OR NEW.student_state = TRUE THEN
        SET NEW.client_type = 'Abono Joven';
    ELSEIF NEW.age > 65 THEN
        SET NEW.client_type = 'Senior';
    ELSE
        SET NEW.client_type = 'Normal';
    END IF;
END; //
DELIMITER ;

drop trigger set_expiration;
DELIMITER //
CREATE TRIGGER set_expiration
BEFORE INSERT ON PrepaidCard
FOR EACH ROW
BEGIN
	SET NEW.expiration = DATE_ADD(NEW.last_charge, INTERVAL 30 DAY);
END; //
DELIMITER ;

drop trigger update_expiration;
DELIMITER //
CREATE TRIGGER update_expiration
BEFORE UPDATE ON PrepaidCard
FOR EACH ROW
BEGIN
	SET NEW.expiration = DATE_ADD(NEW.last_charge, INTERVAL 30 DAY);
END; //
DELIMITER ;

drop trigger set_card_state;
DELIMITER //
CREATE TRIGGER set_card_state
BEFORE INSERT ON PrepaidCard
FOR EACH ROW
BEGIN
	IF NEW.expiration IS NOT NULL THEN
		IF NEW.expiration < CURDATE() THEN
			SET NEW.card_state = 'inactive';
		ELSE
			SET NEW.card_state = 'active';
		END IF;
	END IF;
END; //
DELIMITER ;

drop trigger update_card_state;
DELIMITER //
CREATE TRIGGER update_card_state
BEFORE UPDATE ON PrepaidCard
FOR EACH ROW
BEGIN
	IF NEW.expiration < CURDATE() THEN
		SET NEW.card_state = 'inactive';
	ELSE
		SET NEW.card_state = 'active';
	END IF;
END; //
DELIMITER ;

create table debug(
log_id INT auto_increment primary key,
message TEXT
);

drop trigger set_card_price;
DELIMITER //
CREATE TRIGGER set_card_price
BEFORE INSERT ON OwnsPrepaidCard
FOR EACH ROW
BEGIN
	DECLARE owner_type ENUM('Normal', 'Senior', 'Abono Joven');
    DECLARE base_price DECIMAL (5,2);
    DECLARE owner_city VARCHAR(30);
    DECLARE owner_zone ENUM('A', 'B1', 'B2', 'B3', 'C1', 'C2', 'E1', 'E2');
        
    SELECT client_type INTO owner_type
    FROM MetroClient WHERE NEW.owner_id_num = id_num;
    
	IF owner_type = 'Abono Joven' OR owner_type = 'Senior' THEN
		SELECT price INTO base_price
		FROM ClientType_Price WHERE owner_type = type;
    ELSE 
		SELECT city INTO owner_city
		FROM MetroClient WHERE NEW.owner_id_num = id_num;
        
        SELECT zone INTO owner_zone
		FROM CityKey WHERE owner_city = zone_name;
        
		SELECT zone_fee INTO base_price
		FROM Zonekey WHERE zone = owner_zone;
    END IF;
    
    UPDATE PrepaidCard
    SET card_fee = base_price
    WHERE card_num = NEW.card_num;
END; //
DELIMITER ;

drop trigger change_address;
DELIMITER //
CREATE TRIGGER change_address
AFTER UPDATE ON MetroClient
FOR EACH ROW
BEGIN
	DECLARE base_price DECIMAL(5,2);
    DECLARE card_no VARCHAR(10);
    DECLARE owner_zone ENUM('A', 'B1', 'B2', 'B3', 'C1', 'C2', 'E1', 'E2');
	IF NEW.city != OLD.city THEN
		IF NEW.client_type = 'Abono Joven' OR NEW.client_type = 'Senior' THEN
			SELECT price INTO base_price
            FROM ClientType_Price WHERE NEW.client_type = type;
		ELSE
			SELECT zone INTO owner_zone
			FROM CityKey WHERE NEW.city = zone_name;
        
			SELECT zone_fee INTO base_price
			FROM Zonekey WHERE owner_zone = zone_fee;
		END IF;
        
        SELECT card_num INTO card_no
        FROM OwnsPrepaidCard WHERE NEW.id_num = owner_id_num;
        
        IF card_no IS NOT NULL THEN
			UPDATE PrepaidCard
            SET card_fee = base_price
            WHERE card_no = card_num;
        END IF;
	END IF;
END; //
DELIMITER ;

drop trigger add_discount;
DELIMITER //
CREATE TRIGGER add_discount
AFTER INSERT ON OwnsPrepaidCard
FOR EACH ROW
BEGIN
    DECLARE discount_list ENUM ('N', 'S', 'D', 'ND', 'SD');
    DECLARE discount_amount DECIMAL(4,2);
    DECLARE calculated_value DECIMAL(5,2);
    DECLARE base_price DECIMAL(5,2);

    SELECT discount INTO discount_list
    FROM MetroClient WHERE NEW.owner_id_num = id_num;
    
    SELECT card_fee INTO base_price
    FROM PrepaidCard WHERE NEW.card_num = card_num;
    
    SET calculated_value = base_price;
    
    IF discount_list = 'N' THEN
        SELECT amount INTO discount_amount 
        FROM Discount WHERE type = 'Big Family Normal';
        SET calculated_value = calculated_value * (1 - discount_amount);
    ELSEIF discount_list = 'S' THEN
        SELECT amount INTO discount_amount 
        FROM Discount WHERE type = 'Big Family Special';
        SET calculated_value = calculated_value * (1 - discount_amount);
    ELSEIF discount_list = 'D' THEN
        SELECT amount INTO discount_amount 
        FROM Discount WHERE type = 'Senior/Disability';
        SET calculated_value = calculated_value * (1 - discount_amount);
	ELSEIF discount_list = 'ND' THEN
		SELECT amount INTO discount_amount 
        FROM Discount WHERE type = 'Big Family Normal';
        SET calculated_value = calculated_value * (1 - discount_amount);
        SELECT amount INTO discount_amount 
        FROM Discount WHERE type = 'Senior/Disability';
        SET calculated_value = calculated_value * (1 - discount_amount);
    ELSEIF discount_list = 'SD' THEN
		SELECT amount INTO discount_amount 
        FROM Discount WHERE type = 'Big Family Special';
        SET calculated_value = calculated_value * (1 - discount_amount);
		SELECT amount INTO discount_amount 
        FROM Discount WHERE type = 'Senior/Disability';
        SET calculated_value = calculated_value * (1 - discount_amount);
    END IF;
    UPDATE PrepaidCard
	SET card_fee = calculated_value
    WHERE NEW.card_num = card_num;
END; //
DELIMITER ;

drop trigger update_discount;
DELIMITER //
CREATE TRIGGER update_discount
AFTER UPDATE ON MetroClient
FOR EACH ROW
BEGIN
    DECLARE discount_amount DECIMAL(4,2);
    DECLARE calculated_value DECIMAL(5,2);
    DECLARE base_price DECIMAL(5,2);
    DECLARE card_no VARCHAR(10);
    
    SELECT card_num INTO card_no
    FROM OwnsPrepaidCard WHERE NEW.id_num = owner_id_num;
    
    SELECT card_fee INTO base_price
    FROM PrepaidCard WHERE card_no = card_num;
    
    SET calculated_value = base_price;
    
    IF NEW.discount = 'N' THEN
        SELECT amount INTO discount_amount 
        FROM Discount WHERE type = 'Big Family Normal';
        SET calculated_value = calculated_value * (1 - discount_amount);
    ELSEIF NEW.discount = 'S' THEN
        SELECT amount INTO discount_amount 
        FROM Discount WHERE type = 'Big Family Special';
        SET calculated_value = calculated_value * (1 - discount_amount);
    ELSEIF NEW.discount = 'D' THEN
        SELECT amount INTO discount_amount 
        FROM Discount WHERE type = 'Senior/Disability';
        SET calculated_value = calculated_value * (1 - discount_amount);
	ELSEIF NEW.discount = 'ND' THEN
		SELECT amount INTO discount_amount 
        FROM Discount WHERE type = 'Big Family Normal';
        SET calculated_value = calculated_value * (1 - discount_amount);
        SELECT amount INTO discount_amount 
        FROM Discount WHERE type = 'Senior/Disability';
        SET calculated_value = calculated_value * (1 - discount_amount);
    ELSEIF NEW.discount = 'SD' THEN
		SELECT amount INTO discount_amount 
        FROM Discount WHERE type = 'Big Family Special';
        SET calculated_value = calculated_value * (1 - discount_amount);
		SELECT amount INTO discount_amount 
        FROM Discount WHERE type = 'Senior/Disability';
        SET calculated_value = calculated_value * (1 - discount_amount);
    END IF;
    UPDATE PrepaidCard
	SET card_fee = calculated_value
    WHERE card_no = card_num;
END; //
DELIMITER ;

drop trigger update_age;
DELIMITER //
CREATE TRIGGER update_age
BEFORE UPDATE ON PrepaidCard
FOR EACH ROW
BEGIN
    DECLARE current_year INT;
    DECLARE birth_year INT;
    DECLARE curr_date DATE;
    DECLARE bday DATE;
    DECLARE new_age INT;
    DECLARE owner_id VARCHAR(15);
    DECLARE curr_age INT;
    DECLARE stu_state BOOL;
    DECLARE base_price DECIMAL(5,2);
    DECLARE owner_type VARCHAR(10);
    DECLARE owner_city VARCHAR(30);
    DECLARE new_client_type ENUM('Normal', 'Senior', 'Abono Joven');
    DECLARE owner_zone ENUM('A', 'B1', 'B2', 'B3', 'C1', 'C2', 'E1', 'E2');

    SELECT owner_id_num INTO owner_id
    FROM OwnsprepaidCard WHERE NEW.card_num = card_num;
    
    SELECT age INTO curr_age
    FROM MetroClient WHERE owner_id = id_num;
    
    SELECT student_state INTO stu_state
    FROM MetroClient WHERE owner_id = id_num;
    
    SET curr_date = CURRENT_DATE();
    SET current_year = YEAR(curr_date);
    
    SELECT birthday INTO bday
    FROM MetroClient WHERE owner_id = id_num;
    
    SET birth_year = YEAR(bday);
    SET new_age = current_year - birth_year;
    
    IF MONTH(bday) > MONTH(curr_date) OR (MONTH(bday) = MONTH(curr_date) AND DAY(bday) > DAY(curr_date)) THEN
		SET new_age = new_age - 1;
	END IF;
    
    IF curr_age != new_age THEN
		UPDATE MetroClient
		SET age = new_age
		WHERE owner_id = id_num;
        
        IF new_age < 26 OR stu_state = TRUE THEN
			UPDATE MetroClient
            SET client_type = 'Abono Joven'
            WHERE owner_id = id_num;
            SET new_client_type = 'Abono Joven';
		ELSEIF new_age > 65 THEN
			UPDATE MetroClient
            SET client_type = 'Senior'
            WHERE owner_id = id_num;
            SET new_client_type = 'Senior';
		ELSE
			UPDATE MetroClient
            SET client_type = 'Normal'
            WHERE owner_id = id_num;
            SET new_client_type = 'Normal';
		END IF;
        
        IF new_client_type = 'Abono Joven' OR new_client_type = 'Senior' THEN
			SELECT price INTO base_price
            FROM ClientType_Price WHERE new_client_type = type;
		ELSE
			SELECT city INTO owner_city
            FROM MetroClient WHERE owner_id = id_num;
            
            SELECT zone INTO owner_zone
            FROM CityKey WHERE owner_city = zone_name;
            
			SELECT zone_fee INTO base_price
            FROM ZoneKey WHERE owner_zone = zone;
		END IF;
        
		SET NEW.card_fee = base_price;
	END IF;
END //
DELIMITER ;

drop trigger set_initial_balance;
DELIMITER //
CREATE TRIGGER set_initial_balance
BEFORE INSERT ON MultiEntranceCard
FOR EACH ROW
BEGIN
	IF NEW.initial_amount < 12 THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Initial amount must be €12.00 or more';
    ELSE
		SET NEW.balance = NEW.initial_amount;
	END IF;
END; //
DELIMITER ;

drop trigger ride_metro;
DELIMITER //
CREATE TRIGGER ride_metro
BEFORE UPDATE ON MultiEntranceCard
FOR EACH ROW
BEGIN
	DECLARE old_balance DECIMAL(5,2);
    DECLARE new_balance DECIMAL(5,2);
    
    SELECT balance INTO old_balance
	FROM MultiEntranceCard WHERE OLD.card_num = card_num;
    
	IF NEW.ride_metro = TRUE THEN
		IF (old_balance - cost_per_ride) >= 0 THEN
			SET new_balance = new_balance - cost_per_ride;
			UPDATE MultiEntranceCard
			SET balance = new_balance
			WHERE NEW.card_num = card_num;
		ELSE
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid balance, add money';
            
		UPDATE MultiEntranceCard
        SET ride_metro = FALSE
        WHERE NEW.card_num = card_num;
        
		END IF;
	END IF;
END; //
DELIMITER ;

drop trigger add_money_multicard;
DELIMITER //
CREATE TRIGGER add_money_multicard
BEFORE UPDATE ON MultiEntranceCard
FOR EACH ROW
BEGIN
	IF NEW.add_money_amount < 1.70 THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid amount, must be at least €1.70';
	ELSE
		SET NEW.balance = OLD.balance + NEW.add_money_amount;
        SET NEW.add_money_amount = 0;
	END IF;
END; //
DELIMITER ;

drop trigger replacePrepaid;
DELIMITER //
CREATE TRIGGER replacePrepaid
BEFORE INSERT ON OwnsPrepaidCard
FOR EACH ROW
BEGIN
	DECLARE old_card_no VARCHAR(10);
    DECLARE old_card_status ENUM('active', 'inactive');
    DECLARE old_card_date DATE;
    DECLARE new_card_num VARCHAR(10);
        
    SELECT card_num INTO old_card_no
    FROM OwnsPrepaidCard WHERE owner_id_num = NEW.owner_id_num AND card_num != NEW.card_num;
    
    IF old_card_no IS NOT NULL THEN
		SELECT card_state, last_charge INTO old_card_status, old_card_date
		FROM PrepaidCard WHERE old_card_no = card_num;
		
        UPDATE PrepaidCard
        SET card_state = old_card_status,
			last_charge = old_card_date
        WHERE NEW.card_num = card_num;
        
        DELETE FROM PrepaidCard WHERE old_card_no = card_num;
    END IF;
END; //
DELIMITER ;

drop trigger cancel_client;
DELIMITER //
CREATE TRIGGER cancel_client
BEFORE DELETE ON MetroClient
FOR EACH ROW
BEGIN
	DECLARE card_no VARCHAR(10);
    
    SELECT card_num INTO card_no
    FROM OwnsPrepaidCard WHERE OLD.id_num = owner_id_num;
    
    IF card_no IS NOT NULL THEN
        DELETE FROM PrepaidCard
        WHERE card_no = card_num;
    END IF;
    
    SELECT card_num INTO card_no
    FROM OwnsMultiEntranceCard WHERE OLD.id_num = owner_id_num;
    
    IF card_no IS NOT NULL THEN
        DELETE FROM MultiEntranceCard
        WHERE card_no = card_num;
    END IF;
END; //
DELIMITER ;

SET SQL_SAFE_UPDATES = 0;

INSERT INTO MetroClient (id_num, id_type, first_name, middle_inital, last_name, email, phone, street, city, zipcode, birthday, student_state, discount)
VALUES
('10000000A', 'Passport', 'Juan', 'M', 'Gomez', 'juan.gomez@example.com', '123456789', 'Calle Mayor, 5', 'Madrid', '28001', '1985-06-15', FALSE, NULL),
('11000000B', 'Passport', 'Maria', 'L', 'Fernandez', 'maria.fernandez@example.com', '987654321', 'Calle Alcala, 10', 'Getafe', '28705', '1974-04-22', False, NULL),
('12000000C', 'Passport', 'Jacques', 'G', 'Colon', 'jacques.colon@example.com', '239209120', 'Calle Mayor, 17', 'Pinto', '28121', '1970-09-30', FALSE, 'N'),
('13000000D', 'Passport', 'Carlos', 'J', 'Diaz', 'carlos.diaz@example.com', '654321098', 'Avda. de Europa, 50', 'Campo Real', '28100', '1990-11-05', FALSE, 'SD'),
('14000000E', 'NIE', 'Laura', 'S', 'Lopez', 'laura.lopez@example.com', '345678912', 'Calle Torrejón, 25', 'Torrelodones', '28940', '1995-08-30', TRUE, NULL),
('15000000F', 'NIE', 'Javier', 'R', 'Garcia', 'javier.garcia@example.com', '432109876', 'Calle Princesa, 15', 'Ribatejada', '28300', '2000-04-30', FALSE, NULL),
('16000000G', 'NIE', 'Isabel', 'C', 'Martinez', 'isabel.martinez@example.com', '543219876', 'Avda. de Madrid, 30', 'Coslada', '28701', '2004-09-20', FALSE, 'S'),
('17000000H', 'NIF', 'Maya', 'R', 'Stelzer', 'maya.stelzer@example.com', '243219876', 'Calle Mayor, 5', 'Madrid', '28001', '2008-06-27', FALSE, 'D'),
('18000000I', 'NIF', 'Emma', 'G', 'Smith', 'emma.smith@example.com', '683219876', 'Calle Mayor, 5', 'Madrid', '28065', '1950-02-28', FALSE, NULL),
('19000000J', 'NIF', 'Shawn', 'D', 'Johnson', 'shawn.johnson@example.com', '913219876', 'Calle Mayor, 5', 'San Sebastián de los Reyes', '28065', '1944-12-14', FALSE, 'D'),
('20000000K', 'NIF', 'Steve', 'G', 'Smith', 'steve.smith@example.com', '233219876', 'Calle Mayor, 5', 'Chinchón', '28520', '1949-08-08', FALSE, 'N');

INSERT INTO PrepaidCard(card_num, last_charge)
VALUES
('1000000000', '2024-05-01'),
('1100000000', '2024-05-02'),
('1200000000', '2024-05-03'),
('1300000000', '2024-05-04'),
('1400000000', '2024-05-05'),
('1500000000', '2024-04-06'),
('1600000000', '2024-04-07'),
('1700000000', '2024-04-08'),
('1800000000', '2024-04-09'),
('1900000000', '2024-04-10'),
('2000000000', '2024-04-11');

INSERT INTO OwnsPrepaidCard(owner_id_num, card_num)
VALUES
('10000000A', '1000000000'),
('11000000B', '1100000000'),
('12000000C', '1200000000'),
('13000000D', '1300000000'),
('14000000E', '1400000000'),
('15000000F', '1500000000'),
('16000000G', '1600000000'),
('17000000H', '1700000000'),
('18000000I', '1800000000'),
('19000000J', '1900000000'),
('20000000K', '2000000000');

INSERT INTO MetroClient (id_num, id_type, first_name, last_name)
VALUES
('21000000L', 'Passport', 'Jessica', 'Munoz');

INSERT INTO MultiEntranceCard(card_num, initial_amount)
VALUES
('2100000000', 15);

INSERT INTO OwnsMultiEntranceCard(owner_id_num, card_num)
VALUES
('21000000L', '2100000000');

INSERT INTO CityKey (zone_name, zone)
VALUES
('Madrid', 'A'),

('Alcobendas', 'B1'),
('Alcorcón', 'B1'),
('Cantoblanco', 'B1'),
('Coslada', 'B1'),
('Facultad de Informática', 'B1'),
('Getafe', 'B1'),
('Leganés', 'B1'),
('Paracuellos del Jarama', 'B1'),
('Pozuelo de Alarcón', 'B1'),
('Rivas Vaciamadrid', 'B1'),
('San Fernando de Henares', 'B1'),
('San Sebastián de los Reyes', 'B1'),

('Ajalvir', 'B2'),
('Belvis y Los Berrocales Urb.', 'B2'),
('Boadilla del Monte', 'B2'),
('Fuenlabrada', 'B2'),
('Fuente del Fresno Urb.', 'B2'),
('Las Matas', 'B2'),
('Las Rozas de Madrid', 'B2'),
('Majadahonda', 'B2'),
('Mejorada del Campo', 'B2'),
('Móstoles', 'B2'),
('Parla', 'B2'),
('Pinto', 'B2'),
('Torrejón de Ardoz', 'B2'),
('Tres Cantos', 'B2'),
('Velilla de San Antonio', 'B2'),
('Villaviciosa de Odón', 'B2'),

('Alcalá de Henares', 'B3'),
('Algete', 'B3'),
('Arganda', 'B3'),
('Arroyomolinos', 'B3'),
('Brunete', 'B3'),
('Ciempozuelos', 'B3'),
('Ciudalcampo', 'B3'),
('Cobeña', 'B3'),
('Collado Villalba', 'B3'),
('Colmenar Viejo', 'B3'),
('Colmenarejo', 'B3'),
('Daganzo de Arriba', 'B3'),
('Galapagar', 'B3'),
('Griñón', 'B3'),
('Hoyo de Manzanares', 'B3'),
('Humanes de Madrid', 'B3'),
('Loeches', 'B3'),
('Moraleja de Enmedio', 'B3'),
('Navalcarnero', 'B3'),
('San Agustín de Guadalix', 'B3'),
('San Martín de la Vega', 'B3'),
('Torrejón de la Calzada', 'B3'),
('Torrejón de Velasco', 'B3'),
('Torrelodones', 'B3'),
('Valdemoro', 'B3'),
('Villanueva de la Cañada', 'B3'),
('Villanueva del Pardillo', 'B3'),

('El Álamo', 'C1'),
('Alpedrete', 'C1'),
('Anchuelo', 'C1'),
('Aranjuez', 'C1'),
('Batres', 'C1'),
('Becerril de la Sierra', 'C1'),
('El Boalo y entidades de Mataelpino y Cerceda', 'C1'),
('Camarma de Esteruelas', 'C1'),
('Campo Real', 'C1'),
('Casarrubuelos', 'C1'),
('Collado-Mediano', 'C1'),
('Cubas de la Sagra', 'C1'),
('Chinchón', 'C1'),
('El Escorial', 'C1'),
('Fresno de Torote', 'C1'),
('Fuente el Saz de Jarama', 'C1'),
('Guadarrama', 'C1'),
('Manzanares El Real', 'C1'),
('Meco', 'C1'),
('El Molar', 'C1'),
('Moralzarzal', 'C1'),
('Morata de Tajuña', 'C1'),
('Pedrezuela', 'C1'),
('Perales de Tajuña', 'C1'),
('Pozuelo del Rey', 'C1'),
('Quijorna', 'C1'),
('Ribatejada', 'C1'),
('San Lorenzo de El Escorial', 'C1'),
('Los Santos de la Humosa', 'C1'),
('Serranillos del Valle', 'C1'),
('Sevilla la Nueva', 'C1'),
('Soto del Real', 'C1'),
('Titulcia', 'C1'),
('Torres de la Alameda', 'C1'),
('Valdeavero', 'C1'),
('Valdemorillo', 'C1'),
('Valdeolmos-Alalpardo', 'C1'),
('Valdetorres de Jarama', 'C1'),
('Valverde de Alcalá', 'C1'),
('Villaconejos', 'C1'),
('Villalbilla', 'C1');

INSERT INTO ZoneKey (zone, zone_fee)
VALUES
('A', 54.60),
('B1', 63.70),
('B2', 72.00),
('B3', 82.00),
('C1', 89.50),
('C2', 99.30),
('E1', 110.60),
('E2', 131.80);

INSERT INTO ClientType_Price(type, price)
VALUES 
('Senior', 6.30),
('Abono Joven', 20.00);

INSERT INTO Discount(type, amount)
VALUES
('Big Family Normal', 0.20),
('Big Family Special', 0.40),
('Senior/Disability', 0.65);
