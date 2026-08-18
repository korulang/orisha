// The hybrid Orisha adapter.
//
// Two surfaces, one function:
//
//   - Static pages (the /blog, /docs, /tutorials, /platform … surface plus the
//     root pages) are answered by the Orisha WebAssembly module — the fast
//     path, zero-copy, microseconds. This is the whole point.
//
//   - The genuinely live paths — /api/*, /learn, /admin, /feedback, /present,
//     /ratings, /studio, /worldmodel, /share, /hyperframe-demo — are NOT in the
//     static build. They are reverse-proxied to the existing korulang.org
//     backend, so nothing the live site does today goes dark.
//
// The module is instantiated at module scope, once per cold start.
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));

// Backend that still owns the dynamic surface. Reads at runtime so the proxy
// target isn't baked in.
const BACKEND = process.env.ORISHA_BACKEND ?? "https://korulang-org.vercel.app";

// Paths the wasm module cannot serve — they live in the backend, not the build.
// Anything else (a real static file OR the SPA fallback) stays on Orisha.
const DYNAMIC_PREFIXES = [
  "/api/",
  "/blog/drafts",
  "/learn",
  "/admin",
  "/feedback",
  "/present",
  "/ratings",
  "/studio",
  "/worldmodel",
  "/share",
  "/hyperframe-demo",
];

const env = { time: () => Math.floor(Date.now() / 1000) };

const ready = (async () => {
  const bytes = await readFile(join(here, "..", "wasm", "handler.wasm"));
  const { instance } = await WebAssembly.instantiate(bytes, { env });
  return instance.exports;
})();

const encoder = new TextEncoder();

function parseRawResponse(buffer) {
  const separator = buffer.indexOf("\r\n\r\n");
  const head = buffer.subarray(0, separator).toString("latin1").split("\r\n");
  const body = buffer.subarray(separator + 4);
  const status = Number(head[0].split(" ")[1]);
  const headers = {};
  for (const line of head.slice(1)) {
    const at = line.indexOf(":");
    headers[line.slice(0, at).trim()] = line.slice(at + 1).trim();
  }
  return { status, headers, body };
}

export default async function handler(req, res) {
  const { pathname, search } = new URL(req.url, "http://localhost");
  const path = pathname + (req.method === "GET" ? "" : "");

  const isDynamic = DYNAMIC_PREFIXES.some((p) => pathname.startsWith(p));

  // Dynamic surface → ask the backend, the same way it would be asked today.
  if (isDynamic) {
    const url = new URL(pathname + search, BACKEND);
    const upstream = await fetch(url, {
      method: req.method,
      headers: {
        // Forward the important bits; let the backend own cookies/auth.
        "user-agent": req.headers["user-agent"] ?? "orisha-hybrid",
        cookie: req.headers["cookie"] ?? "",
        "content-type": req.headers["content-type"] ?? "",
      },
      body: ["GET", "HEAD"].includes(req.method) ? undefined : req,
    });
    const body = Buffer.from(await upstream.arrayBuffer());
    res.statusCode = upstream.status;
    for (const [name, value] of upstream.headers) {
      // hop-by-hop headers the proxy must not forward
      if (["transfer-encoding", "connection", "keep-alive"].includes(name.toLowerCase())) continue;
      res.setHeader(name, value);
    }
    return res.end(body);
  }

  // Static surface → the Orisha wasm module.
  const wasm = await ready;
  const rawRequest = encoder.encode(
    `GET ${pathname} HTTP/1.1\r\nHost: korulang.org\r\n\r\n`,
  );
  if (rawRequest.length > wasm.request_cap()) {
    res.statusCode = 414;
    return res.end();
  }
  new Uint8Array(wasm.memory.buffer).set(rawRequest, wasm.request_ptr());
  const written = wasm.handle(rawRequest.length);
  if (written === 0) {
    res.statusCode = 500;
    return res.end();
  }
  const start = wasm.response_ptr();
  const raw = Buffer.from(wasm.memory.buffer.slice(start, start + written));
  const { status, headers, body } = parseRawResponse(raw);
  res.statusCode = status;
  for (const [name, value] of Object.entries(headers)) res.setHeader(name, value);
  res.end(body);
}