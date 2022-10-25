USE MASTER;
DROP DATABASE BankDb;
GO
CREATE DATABASE BankDb;
GO
USE BankDb;

CREATE TABLE bank(
	id INT PRIMARY KEY IDENTITY,
	bank_name NVARCHAR(255) NOT NULL
);
CREATE TABLE city(
	id INT PRIMARY KEY IDENTITY,
	city_name NVARCHAR(255) NOT NULL
);
CREATE TABLE filial(
	id INT PRIMARY KEY IDENTITY,
	bank_id INT NOT NULL,
	city_id INT NOT NULL,
	adress NVARCHAR(255) NOT NULL,
	FOREIGN KEY (bank_id) REFERENCES bank(id) ON DELETE CASCADE ON UPDATE CASCADE,
	FOREIGN KEY (city_id) REFERENCES city(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE TABLE social_status(
	id INT PRIMARY KEY IDENTITY,
	status_name NVARCHAR(255) NOT NULL
);
CREATE TABLE client(
	id INT PRIMARY KEY IDENTITY,
	client_name NVARCHAR(255) NOT NULL,
	social_status_id INT NOT NULL
	FOREIGN KEY (social_status_id) REFERENCES social_status(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE TABLE account(
	id INT PRIMARY KEY IDENTITY,
	client_id INT NOT NULL,
	bank_id INT NOT NULL,
	currency DECIMAL(19,4),
	FOREIGN KEY (client_id) REFERENCES client(id) ON DELETE CASCADE ON UPDATE CASCADE,
	FOREIGN KEY (bank_id) REFERENCES bank(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE TABLE card(
	id INT PRIMARY KEY IDENTITY,
	account_id INT NOT NULL,
	currency DECIMAL(19,4),
	FOREIGN KEY (account_id) REFERENCES account(id) ON DELETE CASCADE ON UPDATE CASCADE,
);

INSERT INTO bank VALUES 
	('Paritetbank'),
	('Alfa-Bank'),
	('MTBank'),
	('Belarusbank'),
	('BNB-Bank');
INSERT INTO city VALUES
	('Minsk'),
	('Grodno'),
	('Vitebsk'),
	('Brest'),
	('Mogilev'),
	('Gomel');
INSERT INTO filial VALUES
	(1, 1, 'Kisileva 61A'),
	(1, 1, 'Gamarnika 9k4'),
	(1, 3, 'Moscow Prospekt 12'),
	(2, 1, 'Logoiski trakt 10'),
	(2, 4, 'Sovetskaya 56'),
	(2, 5, 'Pervomayskaya 42'),
	(2, 1, 'pr. Nezavisimosti 93'),
	(3, 3, 'Chernyahovskogo 6'),
	(3, 5, 'Leninskaya 56'),
	(4, 2, 'Socialisticheskaya 44'),
	(4, 6, 'Lenina 19'),
	(5, 6, 'Pobedy 12B');
INSERT INTO social_status VALUES
	('employee'),
	('unemployed'),
	('disabled'),
	('pensioner'),
	('child');
INSERT INTO client VALUES 
	('Dmitry', 2),
	('Alexandra', 2),
	('Inessa', 1),
	('Galina', 4),
	('Platon', 5),
	('Vladislav', 1);
INSERT INTO account VALUES
	(1, 5, 84.65),
	(2, 2, 56.44),
	(3, 1, 956.98),
	(3, 3, 1500.00),
	(4, 4, 396.00),
	(5, 5, 1000.00),
	(6, 3, 370.00);
INSERT INTO card VALUES
	(1, 15.65),
	(2, 6.44),
	(3, 98.65),
	(3, 465.55),
	(3, 60.44),
	(5, 396.00);
-- 1. Покажи мне список банков у которых есть филиалы в городе X (выбери один из городов)
SELECT DISTINCT b.bank_name FROM bank AS b 
		JOIN filial AS f ON b.id=f.bank_id 
		JOIN city AS c ON f.city_id = c.id WHERE c.city_name = 'Minsk'; 
-- 2. Получить список карточек с указанием имени владельца, баланса и названия банка
SELECT b.bank_name, cl.client_name, c.currency FROM card AS c
		JOIN account as a ON c.account_id = a.id
		JOIN bank AS b ON a.bank_id = b.id
		JOIN client AS cl ON a.client_id = cl.id;
-- 3. Показать список банковских аккаунтов у которых баланс не совпадает с суммой
-- баланса по карточкам. В отдельной колонке вывести разницу
SELECT a.id, (a.currency-ISNULL(SUM(c.currency),0)) AS difference FROM account AS a
		LEFT JOIN card AS c ON a.id = c.account_id GROUP BY a.id, a.currency HAVING (a.currency-ISNULL(SUM(c.currency),0))!=0; 
-- 4. Вывести кол-во банковских карточек для каждого соц статуса 
-- (2 реализации, GROUP BY и подзапросом)
SELECT s.status_name, COUNT(c.id) AS cards_count FROM social_status AS s 
		LEFT JOIN client AS cl ON s.id = cl.social_status_id
		LEFT JOIN account AS a ON cl.id = a.client_id
		LEFT JOIN card AS c ON c.account_id = a.id
		GROUP BY s.status_name ORDER BY s.status_name;
SELECT s.status_name, (SELECT COUNT(cl.social_status_id) FROM card AS c
							LEFT JOIN account AS a ON c.account_id = a.id
							LEFT JOIN client AS cl ON a.client_id = cl.id 
							WHERE cl.social_status_id = s.id) AS cards_count
							FROM social_status as s ORDER BY s.status_name;
-- 5. Написать stored procedure которая будет добавлять по 10$ на каждый банковский
-- аккаунт для определенного соц статуса (У каждого клиента бывают разные соц. статусы. 
-- Например, пенсионер, инвалид и прочее). Входной параметр процедуры - Id социального 
-- статуса. Обработать исключительные ситуации (например, был введен неверные номер соц. 
-- статуса. Либо когда у этого статуса нет привязанных аккаунтов).
GO
CREATE PROCEDURE usp_Status_Add_Money @social_status_id INT
AS
BEGIN
	IF ((SELECT COUNT(s.id) FROM social_status AS s 
			JOIN client AS cl ON s.id = cl.social_status_id
			JOIN account AS a ON a.client_id = cl.id
			WHERE s.id = @social_status_id)=0)
		BEGIN
			DECLARE @Message NVARCHAR(100);
			SET @Message = 'The social status with id '+CAST(@social_status_id AS NVARCHAR)+' was not found or he has no linked accounts';
			THROW 51000, @Message,1;	
		END
	UPDATE account
	SET account.currency+=10
	FROM account AS a 
	JOIN client AS cl ON cl.id = a.client_id
	WHERE cl.social_status_id = @social_status_id
END;
GO
SELECT * FROM account;
EXEC usp_Status_Add_Money @social_status_id = 2;
SELECT * FROM account;
GO
--6. Получить список доступных средств для каждого клиента.
-- То есть если у клиента на банковском аккаунте 60 рублей, 
--и у него 2 карточки по 15 рублей на каждой, то у него доступно 
--30 рублей для перевода на любую из карт
SELECT cl.client_name, a.id AS account_id, a.bank_id AS bank_id, (a.currency-ISNULL(SUM(c.currency),0)) AS currency_available_for_transfer
		FROM client AS cl
		LEFT JOIN account AS a ON cl.id = a.client_id
		LEFT JOIN card AS c ON a.id = c.account_id 
		GROUP BY a.id, a.currency,cl.client_name, a.bank_id;
--7. Написать процедуру которая будет переводить определённую сумму 
-- со счёта на карту этого аккаунта.  При этом будем считать что деньги 
-- на счёту все равно останутся, просто сумма средств на карте увеличится.
-- Например, у меня есть аккаунт на котором 1000 рублей и две карты по 300 рублей 
-- на каждой. Я могу перевести 200 рублей на одну из карт, при этом баланс аккаунта 
-- останется 1000 рублей, а на картах будут суммы 300 и 500 рублей соответственно. 
-- После этого я уже не смогу перевести 400 рублей с аккаунта ни на одну из карт, 
-- так как останется всего 200 свободных рублей (1000-300-500). 
-- Переводить БЕЗОПАСНО. То есть использовать транзакцию
GO
CREATE PROCEDURE usp_card_transfer_money @card_id INT, @currency DECIMAL(19,4) AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRAN 
			IF (COALESCE((SELECT (a.currency-ISNULL(SUM(c.currency),0)) AS currency_available_for_transfer
				FROM account AS a
				LEFT JOIN card AS c ON a.id = c.account_id 
				WHERE a.id = c.account_id and c.id = @card_id GROUP BY a.currency),-1)<@currency)
					THROW 51000, 'There is no such card or insufficient funds',1;
			UPDATE card
			SET currency +=@currency WHERE id = @card_id;
		COMMIT TRAN;
	END TRY
	BEGIN CATCH 
		ROLLBACK TRANSACTION;
		THROW;
	END CATCH;
END;
GO
SELECT * FROM card;
EXEC usp_card_transfer_money 3,2;
SELECT * FROM card;
-- 8. Написать триггер на таблицы Account/Cards чтобы нельзя была занести 
-- значения в поле баланс если это противоречит условиям  (то есть нельзя
-- изменить значение в Account на меньшее, чем сумма балансов по всем карточкам. 
-- И соответственно нельзя изменить баланс карты если в итоге сумма 
-- на картах будет больше чем баланс аккаунта)
GO
CREATE TRIGGER TR_currency_update_account ON account
AFTER UPDATE
AS 
BEGIN
	DECLARE @sum_card_currency DECIMAL(19,4);
	DECLARE @updated_currency DECIMAL(19,4);
	SELECT @updated_currency = currency FROM INSERTED
	SELECT @sum_card_currency = ISNULL(SUM(c.currency),0)
	FROM account AS a
		LEFT JOIN card AS c ON c.account_id = a.id
	WHERE a.id = (SELECT id FROM inserted)
	GROUP BY a.id;
	IF @sum_card_currency>@updated_currency
	BEGIN
		ROLLBACK TRANSACTION;
		THROW 51000,'The new value is less than the one available in the client''s cards',1;
	END
END
GO
SELECT * FROM account WHERE id =5; 
UPDATE account 
SET currency = 2000 WHERE id=5;
SELECT * FROM account WHERE id = 5;
-- cards trigger
GO
CREATE TRIGGER TR_currency_update_cards ON card
AFTER UPDATE,INSERT
AS 
BEGIN
	DECLARE @sum_card_currency DECIMAL(19,4);
	DECLARE @account_currency DECIMAL(19,4);
	SELECT @account_currency = a.currency FROM account AS a
		WHERE a.id = (SELECT account_id FROM inserted)
	SELECT @sum_card_currency = ISNULL(SUM(c.currency),0)
	FROM account AS a
		LEFT JOIN card AS c ON c.account_id = a.id
	WHERE a.id = (SELECT account_id FROM inserted)
	GROUP BY a.id;
	IF @sum_card_currency>@account_currency
	BEGIN
		ROLLBACK TRANSACTION;
		THROW 51000,'The new value is greater than available in the account wallet',1;
	END
END
GO

-- currency available for transer before create card
SELECT cl.client_name, a.id AS account_id, a.bank_id AS bank_id, (a.currency-ISNULL(SUM(c.currency),0)) AS currency_available_for_transfer
		FROM client AS cl
		LEFT JOIN account AS a ON cl.id = a.client_id
		LEFT JOIN card AS c ON a.id = c.account_id 
		WHERE a.id = 3
		GROUP BY a.id, a.currency,cl.client_name, a.bank_id;
INSERT INTO card VALUES (3,300);
UPDATE card
SET currency+=30 WHERE id=7;
-- after create card
SELECT cl.client_name, a.id AS account_id, a.bank_id AS bank_id, (a.currency-ISNULL(SUM(c.currency),0)) AS currency_available_for_transfer
		FROM client AS cl
		LEFT JOIN account AS a ON cl.id = a.client_id
		LEFT JOIN card AS c ON a.id = c.account_id 
		WHERE a.id = 3
		GROUP BY a.id, a.currency,cl.client_name, a.bank_id;