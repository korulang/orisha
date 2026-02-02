// Minimal ASP.NET Core HTTP server for benchmark comparison
// Build: dotnet publish -c Release
// Run: ./bin/Release/net8.0/publish/dotnet-benchmark
// Serves on port 3005

var builder = WebApplication.CreateSlimBuilder(args);
builder.WebHost.UseUrls("http://127.0.0.1:3005");

var app = builder.Build();

// Embed files at compile time (like Orisha)
var indexHtml = File.ReadAllText("public/index.html");
var aboutHtml = File.ReadAllText("public/about.html");

// Pre-compute byte arrays for zero-allocation serving
var indexBytes = System.Text.Encoding.UTF8.GetBytes(indexHtml);
var aboutBytes = System.Text.Encoding.UTF8.GetBytes(aboutHtml);
var healthBytes = System.Text.Encoding.UTF8.GetBytes("{\"status\":\"ok\"}");

app.MapGet("/", () => Results.Text(indexHtml, "text/html; charset=utf-8"));

app.MapGet("/about", () => Results.Text(aboutHtml, "text/html; charset=utf-8"));

app.MapGet("/api/health", () => Results.Text("{\"status\":\"ok\"}", "application/json"));

app.MapGet("/api/users/{id}", (string id) =>
    Results.Text($"{{\"id\":\"{id}\",\"name\":\"User {id}\"}}", "application/json"));

Console.WriteLine("ASP.NET Core server listening on :3005");
app.Run();
