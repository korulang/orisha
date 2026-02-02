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

Console.WriteLine("ASP.NET Core server listening on :3005");
app.Run();
