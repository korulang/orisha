// Minimal Bun HTTP server for benchmark comparison
// Run: bun run server.ts
// Serves on port 3003

// Read files at startup (simulating compile-time embedding)
const indexHtml = await Bun.file("./public/index.html").text();
const aboutHtml = await Bun.file("./public/about.html").text();

const server = Bun.serve({
  port: 3003,
  fetch(req) {
    const url = new URL(req.url);
    const path = url.pathname;

    // Static files
    if (path === "/") {
      return new Response(indexHtml, {
        headers: { "Content-Type": "text/html; charset=utf-8" },
      });
    }

    if (path === "/about") {
      return new Response(aboutHtml, {
        headers: { "Content-Type": "text/html; charset=utf-8" },
      });
    }

    // Health check
    if (path === "/api/health") {
      return Response.json({ status: "ok" });
    }

    // Dynamic user endpoint: /api/users/:id
    const userMatch = path.match(/^\/api\/users\/(\d+)$/);
    if (userMatch) {
      const id = userMatch[1];
      return Response.json({ id, name: `User ${id}` });
    }

    return new Response("Not Found", { status: 404 });
  },
});

console.log(`Bun server listening on :${server.port}`);
