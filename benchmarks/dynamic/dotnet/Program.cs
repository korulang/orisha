// Minimal ASP.NET Core HTTP server for benchmark comparison
// Based on TechEmpower FrameworkBenchmarks optimizations
// Build: dotnet publish -c Release -o bin/publish
// Run: ./bin/publish/dotnet-benchmark
// Serves on port 3005

var builder = WebApplication.CreateBuilder(args);

// Disable logging (TechEmpower optimization)
builder.Logging.ClearProviders();

// Configure Kestrel for maximum performance
builder.WebHost.ConfigureKestrel(options =>
{
    options.AllowSynchronousIO = true;
    options.Limits.MaxConcurrentConnections = null;
    options.Limits.MaxConcurrentUpgradedConnections = null;
});

builder.WebHost.UseUrls("http://0.0.0.0:3005");

var app = builder.Build();

// Pre-load static content (like Orisha's compile-time embedding)
var indexHtml = File.ReadAllText("public/index.html");
var aboutHtml = File.ReadAllText("public/about.html");

// TechEmpower-style plaintext endpoint for comparison
app.MapGet("/plaintext", () => "Hello, World!");

// Static HTML endpoints
app.MapGet("/", () => Results.Content(indexHtml, "text/html; charset=utf-8"));
app.MapGet("/about", () => Results.Content(aboutHtml, "text/html; charset=utf-8"));

// JSON endpoints
app.MapGet("/json", () => new { message = "Hello, World!" });
app.MapGet("/api/health", () => new { status = "ok" });

// Dynamic user endpoint
app.MapGet("/api/users/{id}", (string id) => new { id, name = $"User {id}" });

// DB leg: full driver path per request — open, bind, scalar, close.
app.MapGet("/api/db/users/{id}", (string id) =>
{
    using var conn = new Microsoft.Data.Sqlite.SqliteConnection("Data Source=../bench.db;Pooling=false");
    conn.Open();
    using var cmd = conn.CreateCommand();
    cmd.CommandText = "SELECT name FROM users WHERE id = $id";
    cmd.Parameters.AddWithValue("$id", id);
    var name = cmd.ExecuteScalar() as string;
    return name is null ? Results.Json(new { }) : Results.Json(new { id, name });
});

// Pool leg: what an idiomatic .NET service actually does — the driver pools
// connections by default. Command is still built per request.
app.MapGet("/api/db/pool/users/{id}", (string id) =>
{
    using var conn = new Microsoft.Data.Sqlite.SqliteConnection("Data Source=../bench.db");
    conn.Open();
    using var cmd = conn.CreateCommand();
    cmd.CommandText = "SELECT name FROM users WHERE id = $id";
    cmd.Parameters.AddWithValue("$id", id);
    var name = cmd.ExecuteScalar() as string;
    return name is null ? Results.Json(new { }) : Results.Json(new { id, name });
});

// Persistent leg: one connection + one prepared command per thread — the
// shape a real service takes, matched to Orisha's per-worker model.
app.MapGet("/api/db/hot/users/{id}", (string id) =>
{
    if (HotDb.Conn is null)
    {
        HotDb.Conn = new Microsoft.Data.Sqlite.SqliteConnection("Data Source=../bench.db;Pooling=false");
        HotDb.Conn.Open();
    }
    if (HotDb.Cmd is null)
    {
        HotDb.Cmd = HotDb.Conn.CreateCommand();
        HotDb.Cmd.CommandText = "SELECT name FROM users WHERE id = $id";
        HotDb.Cmd.Parameters.Add("$id", Microsoft.Data.Sqlite.SqliteType.Text);
        HotDb.Cmd.Prepare();
    }
    HotDb.Cmd.Parameters["$id"].Value = id;
    var name = HotDb.Cmd.ExecuteScalar() as string;
    return name is null ? Results.Json(new { }) : Results.Json(new { id, name });
});

Console.WriteLine("ASP.NET Core server listening on :3005");
app.Run();

static class HotDb
{
    [ThreadStatic] public static Microsoft.Data.Sqlite.SqliteConnection? Conn;
    [ThreadStatic] public static Microsoft.Data.Sqlite.SqliteCommand? Cmd;
}
