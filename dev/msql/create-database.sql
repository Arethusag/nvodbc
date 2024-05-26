CREATE DATABASE testdb;
GO
USE testdb;
GO
CREATE TABLE Products (ID int, ProductName nvarchar(max), UnitPrice money);
GO
INSERT INTO Products VALUES (1, N'Bolo', 18.00);
GO
