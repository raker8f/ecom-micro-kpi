using Microsoft.Data.SqlClient;
using Dapper;


var builder = WebApplication.CreateBuilder(args);
var connStr = builder.Configuration.GetConnectionString("db")
?? "Server=localhost;Database=ecom_kpi;Trusted_Connection=True;TrustServerCertificate=True;";
var app = builder.Build();


app.MapGet("/kpi/monthly", async () => {
    const string sql = @"
WITH paid AS (
SELECT o.OrderId, o.OrderDate,
SUM(oi.Qty*oi.UnitPrice - oi.Discount) AS amount
FROM dbo.Orders o
JOIN dbo.OrderItems oi ON oi.OrderId=o.OrderId
WHERE o.OrderStatus='PAID'
GROUP BY o.OrderId, o.OrderDate
)
SELECT FORMAT(OrderDate,'yyyy-MM') AS ym,
COUNT(*) AS orders,
SUM(amount) AS revenue,
AVG(amount) AS aov
FROM paid GROUP BY FORMAT(OrderDate,'yyyy-MM') ORDER BY ym;";
    using var conn = new SqlConnection(connStr);
    var rows = await conn.QueryAsync(sql);
    return Results.Ok(rows);
});


app.MapGet("/customer/{id}/ltv", async (int id) => {
    const string sql = @"
SELECT SUM(oi.Qty*oi.UnitPrice - oi.Discount) AS LTV
FROM dbo.Orders o
JOIN dbo.OrderItems oi ON oi.OrderId=o.OrderId
WHERE o.OrderStatus='PAID' AND o.CustomerId=@id;";
    using var conn = new SqlConnection(connStr);
    var ltv = await conn.ExecuteScalarAsync<decimal?>(sql, new { id });
    return Results.Ok(new { CustomerId = id, LTV = ltv ?? 0 });
});


app.Run();