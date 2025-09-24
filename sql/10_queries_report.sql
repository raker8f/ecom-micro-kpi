-- 1) 月度 KPI：訂單數、營收、客單價
SELECT c.CustomerId, c.Email,
DATEDIFF(DAY, recent, SYSUTCDATETIME()) AS recency_days,
freq, money,
NTILE(5) OVER(ORDER BY -freq) AS F_bucket,
NTILE(5) OVER(ORDER BY -money) AS M_bucket
FROM paid JOIN dbo.Customers c ON c.CustomerId=paid.CustomerId;


-- 4) 滾動 7 天營收移動平均（使用 Indexed View 加速）
SELECT SalesDate,
Revenue,
AVG(Revenue) OVER(ORDER BY SalesDate ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS MA7
FROM dbo.v_DailySales
ORDER BY SalesDate;


-- 5) 客戶 LTV（總金額/客戶）
SELECT c.CustomerId, c.Email,
SUM(oi.Qty*oi.UnitPrice - oi.Discount) AS LTV
FROM dbo.Customers c
LEFT JOIN dbo.Orders o ON o.CustomerId=c.CustomerId AND o.OrderStatus='PAID'
LEFT JOIN dbo.OrderItems oi ON oi.OrderId=o.OrderId
GROUP BY c.CustomerId, c.Email
ORDER BY LTV DESC;


-- 6) 庫存日覆蓋（近 30 日日均銷量）
WITH sales AS (
SELECT p.ProductId,
SUM(oi.Qty) AS qty30
FROM dbo.Orders o
JOIN dbo.OrderItems oi ON oi.OrderId=o.OrderId
JOIN dbo.Products p ON p.ProductId=oi.ProductId
WHERE o.OrderStatus='PAID' AND o.OrderDate >= DATEADD(DAY,-30,SYSUTCDATETIME())
GROUP BY p.ProductId
), stock AS (
SELECT ProductId, SUM(QtyChange) AS onhand FROM dbo.InventoryTransactions GROUP BY ProductId
)
SELECT p.ProductId, p.Name,
ISNULL(onhand,0) AS onhand,
CAST(ISNULL(qty30,0)/NULLIF(30,0) AS DECIMAL(10,2)) AS avg_day,
CASE WHEN ISNULL(qty30,0)=0 THEN NULL ELSE CAST(ISNULL(onhand,0)/(qty30/30.0) AS DECIMAL(10,1)) END AS days_of_cover
FROM dbo.Products p
LEFT JOIN sales s ON s.ProductId=p.ProductId
LEFT JOIN stock k ON k.ProductId=p.ProductId
ORDER BY days_of_cover;


-- 7) 每類別毛利率
SELECT Category,
SUM(oi.Qty*oi.UnitPrice - oi.Discount) AS revenue,
SUM(oi.Qty*p.Cost) AS cost,
CAST((SUM(oi.Qty*oi.UnitPrice - oi.Discount) - SUM(oi.Qty*p.Cost)) / NULLIF(SUM(oi.Qty*oi.UnitPrice - oi.Discount),0) AS DECIMAL(5,2)) AS margin
FROM dbo.OrderItems oi
JOIN dbo.Orders o ON o.OrderId=oi.OrderId AND o.OrderStatus='PAID'
JOIN dbo.Products p ON p.ProductId=oi.ProductId
GROUP BY Category
ORDER BY margin DESC;


-- 8) 每客每月的留存（是否在次月有下單）
WITH paid AS (
SELECT CustomerId, FORMAT(OrderDate,'yyyy-MM') ym, COUNT(*) cnt
FROM dbo.Orders WHERE OrderStatus='PAID'
GROUP BY CustomerId, FORMAT(OrderDate,'yyyy-MM')
), nextm AS (
SELECT a.CustomerId, a.ym, CASE WHEN b.cnt IS NULL THEN 0 ELSE 1 END AS retained
FROM paid a
LEFT JOIN paid b ON b.CustomerId=a.CustomerId AND b.ym = FORMAT(DATEADD(MONTH,1,CONVERT(date,a.ym+'-01')),'yyyy-MM')
)
SELECT ym, AVG(CAST(retained AS FLOAT)) AS retention_rate
FROM nextm GROUP BY ym ORDER BY ym;


-- 9) 慢查詢觀察（範例）
SET STATISTICS IO ON; SET STATISTICS TIME ON;
SELECT TOP 100 *
FROM dbo.Orders o
JOIN dbo.OrderItems oi ON oi.OrderId=o.OrderId
ORDER BY o.OrderDate DESC;


-- 10) 建議索引（示例）
CREATE INDEX IX_OrderItems_OrderId_ProductId ON dbo.OrderItems(OrderId, ProductId) INCLUDE (Qty, UnitPrice, Discount);