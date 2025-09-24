USE ecom_kpi;
GO

-- Orders: 依照日期查詢很常用
CREATE INDEX IX_Orders_OrderDate
    ON dbo.Orders(OrderDate);

-- Orders: 依客戶查訂單
CREATE INDEX IX_Orders_CustomerId
    ON dbo.Orders(CustomerId);

-- OrderItems: 常 join OrderId + ProductId，並且查 Qty/Price/Discount
CREATE INDEX IX_OrderItems_OrderId_ProductId
    ON dbo.OrderItems(OrderId, ProductId)
    INCLUDE (Qty, UnitPrice, Discount);

-- Products: 常依 Category 做報表
CREATE INDEX IX_Products_Category
    ON dbo.Products(Category);

-- InventoryTransactions: 常查某產品的最近交易
CREATE INDEX IX_Inventory_Product_Time
    ON dbo.InventoryTransactions(ProductId, TxnTime DESC);
