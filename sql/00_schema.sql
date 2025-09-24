-- Database
IF DB_ID('ecom_kpi') IS NULL CREATE DATABASE ecom_kpi;
GO
USE ecom_kpi;
GO


-- Customers
CREATE TABLE dbo.Customers (
CustomerId INT IDENTITY(1,1) PRIMARY KEY,
Email VARCHAR(255) NOT NULL UNIQUE,
FullName NVARCHAR(100) NOT NULL,
Gender CHAR(1) NULL CHECK (Gender IN ('M','F')),
CreatedAt DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
IsActive BIT NOT NULL DEFAULT 1
);


-- Products
CREATE TABLE dbo.Products (
ProductId INT IDENTITY(1,1) PRIMARY KEY,
Sku VARCHAR(50) NOT NULL UNIQUE,
Name NVARCHAR(150) NOT NULL,
Category NVARCHAR(80) NOT NULL,
Price DECIMAL(10,2) NOT NULL CHECK (Price >= 0),
Cost DECIMAL(10,2) NOT NULL CHECK (Cost >= 0),
CreatedAt DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
IsActive BIT NOT NULL DEFAULT 1
);
CREATE INDEX IX_Products_Category ON dbo.Products(Category);


-- Orders
CREATE TABLE dbo.Orders (
OrderId BIGINT IDENTITY(1,1) PRIMARY KEY,
CustomerId INT NOT NULL FOREIGN KEY REFERENCES dbo.Customers(CustomerId),
OrderStatus VARCHAR(20) NOT NULL CHECK (OrderStatus IN ('PAID','CANCELLED','REFUNDED','PENDING')),
OrderDate DATETIME2(0) NOT NULL,
ShippedDate DATETIME2(0) NULL,
PaymentMethod VARCHAR(20) NOT NULL CHECK (PaymentMethod IN ('CARD','CASH','WALLET','BANK')),
CreatedAt DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()
);
CREATE INDEX IX_Orders_OrderDate ON dbo.Orders(OrderDate);
CREATE INDEX IX_Orders_CustomerId ON dbo.Orders(CustomerId);


-- OrderItems
CREATE TABLE dbo.OrderItems (
OrderItemId BIGINT IDENTITY(1,1) PRIMARY KEY,
OrderId BIGINT NOT NULL FOREIGN KEY REFERENCES dbo.Orders(OrderId),
ProductId INT NOT NULL FOREIGN KEY REFERENCES dbo.Products(ProductId),
Qty INT NOT NULL CHECK (Qty > 0),
UnitPrice DECIMAL(10,2) NOT NULL CHECK (UnitPrice >= 0),
Discount DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (Discount >= 0)
);
CREATE INDEX IX_OrderItems_OrderId ON dbo.OrderItems(OrderId);
CREATE INDEX IX_OrderItems_ProductId ON dbo.OrderItems(ProductId);


-- InventoryTransactions (進出貨/校正)
CREATE TABLE dbo.InventoryTransactions (
InventoryTxnId BIGINT IDENTITY(1,1) PRIMARY KEY,
ProductId INT NOT NULL FOREIGN KEY REFERENCES dbo.Products(ProductId),
TxnType VARCHAR(20) NOT NULL CHECK (TxnType IN ('PURCHASE','SALE','ADJUSTMENT')),
QtyChange INT NOT NULL, -- +補貨/-銷售
TxnTime DATETIME2(0) NOT NULL,
Note NVARCHAR(200) NULL
);
CREATE INDEX IX_Inventory_Product_Time ON dbo.InventoryTransactions(ProductId, TxnTime DESC);


-- Indexed View：每日銷售彙總（近似 materialized view）
-- 注意：要 SCHEMABINDING 且引用兩部份名稱。
GO
CREATE OR ALTER VIEW dbo.v_DailySales WITH SCHEMABINDING AS
SELECT
CAST(o.OrderDate AS DATE) AS SalesDate,
COUNT_BIG(*) AS Orders,
SUM(oi.Qty) AS Units,
SUM(oi.Qty * oi.UnitPrice - oi.Discount) AS Revenue
FROM dbo.Orders AS o
JOIN dbo.OrderItems AS oi ON o.OrderId = oi.OrderId
WHERE o.OrderStatus = 'PAID'
GROUP BY CAST(o.OrderDate AS DATE);
GO
-- 建索引讓 View 物化
CREATE UNIQUE CLUSTERED INDEX CIX_v_DailySales
ON dbo.v_DailySales(SalesDate);