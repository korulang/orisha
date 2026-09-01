// HttpArena-shaped ASP.NET Core reference for same-machine wrk comparisons.
// Build: dotnet publish -c Release -o bin/publish
// Run:  ./bin/publish/httparena-ref

using System.Text.Json;
using System.Text.Json.Serialization;

var builder = WebApplication.CreateBuilder(args);
builder.Logging.ClearProviders();
builder.WebHost.ConfigureKestrel(options =>
{
    options.AllowSynchronousIO = true;
    options.Limits.MaxConcurrentConnections = null;
    options.Limits.MaxConcurrentUpgradedConnections = null;
});
builder.WebHost.UseUrls("http://0.0.0.0:8091");

var datasetPath = Environment.GetEnvironmentVariable("DATASET_PATH")
    ?? Path.Combine(Directory.GetCurrentDirectory(), "data", "dataset.json");
var source = JsonSerializer.Deserialize<List<DatasetItem>>(File.ReadAllText(datasetPath))
    ?? throw new InvalidOperationException($"dataset missing: {datasetPath}");

var app = builder.Build();

app.MapGet("/pipeline", () => Results.Text("ok", "text/plain"));

app.MapGet("/baseline11", (HttpRequest req) =>
{
    var a = int.TryParse(req.Query["a"], out var av) ? av : 0;
    var b = int.TryParse(req.Query["b"], out var bv) ? bv : 0;
    return Results.Text((a + b).ToString(), "text/plain");
});

app.MapGet("/json/{count:int}", (int count, HttpRequest req) =>
{
    var m = int.TryParse(req.Query["m"], out var mv) ? mv : 1;
    if (count <= 0) count = 0;
    if (count > source.Count) count = source.Count;
    var items = new List<JsonOutItem>(count);
    for (var i = 0; i < count; i++)
    {
        var s = source[i];
        items.Add(new JsonOutItem
        {
            Id = s.Id,
            Name = s.Name,
            Category = s.Category,
            Price = s.Price,
            Quantity = s.Quantity,
            Active = s.Active,
            Tags = s.Tags,
            Rating = s.Rating,
            Total = s.Price * s.Quantity * m,
        });
    }
    return Results.Json(new { count, items });
});

Console.WriteLine("httparena-ref listening on :8091");
app.Run();

sealed class DatasetItem
{
    public long Id { get; set; }
    public string Name { get; set; } = "";
    public string Category { get; set; } = "";
    public long Price { get; set; }
    public long Quantity { get; set; }
    public bool Active { get; set; }
    public List<string> Tags { get; set; } = new();
    public Rating Rating { get; set; } = new();
}

sealed class Rating
{
    public long Score { get; set; }
    public long Count { get; set; }
}

sealed class JsonOutItem
{
    public long Id { get; set; }
    public string Name { get; set; } = "";
    public string Category { get; set; } = "";
    public long Price { get; set; }
    public long Quantity { get; set; }
    public bool Active { get; set; }
    public List<string> Tags { get; set; } = new();
    public Rating Rating { get; set; } = new();
    public long Total { get; set; }
}
