using System.Data;
using Microsoft.Data.SqlClient;
using Bogus;
using Dapper;


var connStr = "Server=localhost;Database=ecom_kpi;Trusted_Connection=True;TrustServerCertificate=True;"; // 或使用 SQL 登入
using var conn = new SqlConnection(connStr);
await conn.OpenAsync();


var rnd = new Random();
int customers = 5000, products = 300, days = 180;


// 產客戶
var f = new Faker("zh_TW");
var custs = Enumerable.Range(1, customers).Select(_ => new {
    Email = f.Internet.Email(),
    FullName = f.Name.FullName(),
    Gender = f.PickRandom(new[] { "M", "F" }),
});
await conn.ExecuteAsync("INSERT INTO dbo.Customers(Email,FullName,Gender) VALUES (@Email,@FullName,@Gender)", custs);


// 產商品
var cats = new[] { "Coffee", "Kitchen", "Accessory", "Gift" };
var prods = Enumerable.Range(1, products).Select(i => new {
    Sku = $"SKU-{i:00000}",
    Name = f.Commerce.ProductName(),
    Category = f.PickRandom(cats),
    Price = f.Random.Decimal(50, 1500),
    Cost = f.Random.Decimal(20, 900),
});
await conn.ExecuteAsync("INSERT INTO dbo.Products(Sku,Name,Category,Price,Cost) VALUES (@Sku,@Name,@Category,@Price,@Cost)", prods);


// 產訂單 + 明細
var start = DateTime.UtcNow.AddDays(-days);
var orderIns = "INSERT INTO dbo.Orders(CustomerId,OrderStatus,OrderDate,PaymentMethod) VALUES (@CustomerId,@OrderStatus,@OrderDate,@PaymentMethod); SELECT CAST(SCOPE_IDENTITY() as bigint);";
var itemIns = "INSERT INTO dbo.OrderItems(OrderId,ProductId,Qty,UnitPrice,Discount) VALUES (@OrderId,@ProductId,@Qty,@UnitPrice,@Discount)";


for (int d = 0; d < days; d++)
{
    var day = start.AddDays(d);
    int ordersToday = f.Random.Int(100, 600); // 調整流量
    for (int k = 0; k < ordersToday; k++)
    {
        var status = f.Random.WeightedRandom(new[] { "PAID", "CANCELLED", "REFUNDED" }, new[] { 0.86f, 0.10f, 0.04f });
        var orderId = await conn.ExecuteScalarAsync<long>(orderIns, new
        {
            CustomerId = f.Random.Int(1, customers),
            OrderStatus = status,
            OrderDate = day.AddMinutes(f.Random.Int(0, 1440)),
            PaymentMethod = f.PickRandom(new[] { "CARD", "CASH", "WALLET", "BANK" })
        });
        int items = f.Random.Int(1, 4);
        for (int i = 0; i < items; i++)
        {
            int pid = f.Random.Int(1, products);
            decimal price = await conn.ExecuteScalarAsync<decimal>("SELECT Price FROM dbo.Products WHERE ProductId=@pid", new { pid });
            await conn.ExecuteAsync(itemIns, new
            {
                OrderId = orderId,
                ProductId = pid,
                Qty = f.Random.Int(1, 3),
                UnitPrice = price,
                Discount = f.Random.Bool(0.15f) ? f.Random.Decimal(5, 50) : 0
            });
        }
    }
}