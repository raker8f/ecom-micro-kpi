USE ecom_kpi;


INSERT INTO dbo.Customers(Email, FullName, Gender)
VALUES ('a@example.com','Alice','F'),('b@example.com','Bob','M'),('c@example.com','Carol','F');


INSERT INTO dbo.Products(Sku, Name, Category, Price, Cost)
VALUES ('SKU-001','Coffee Beans 250g','Grocery',350,180),
('SKU-002','Dripper V60','Kitchen',520,260),
('SKU-003','Mug 300ml','Kitchen',199,80);


DECLARE @d DATETIME2(0) = DATEADD(DAY,-10,SYSUTCDATETIME());
INSERT INTO dbo.Orders(CustomerId, OrderStatus, OrderDate, PaymentMethod)
VALUES (1,'PAID',DATEADD(DAY,0,@d),'CARD'),
(2,'PAID',DATEADD(DAY,1,@d),'CASH'),
(3,'CANCELLED',DATEADD(DAY,2,@d),'CARD');


INSERT INTO dbo.OrderItems(OrderId, ProductId, Qty, UnitPrice, Discount)
VALUES (1,1,2,350,0),(1,3,1,199,10),(2,2,1,520,0);