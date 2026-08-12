// The Vercel adapter. Everything platform-specific about this experiment is in
// this file, and it is deliberately thin: the wasm module answers in real HTTP,
// so all that happens here is a translation from a byte stream into the Response
// shape Vercel wants back.
//
// The module is instantiated at module scope, which means once per cold start
// rather than once per request. Instantiating it per request would re-copy its
// data section (21 MB) every time.
//
// The whole-site module imports exactly one host function — a clock — which the
// four-route demo did not. Everything else is self-contained.
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));

// The only import the module asks for: a time source. Baked responses carry
// their own ETags; this feeds whatever dynamic header work the site does.
const env = { time: () => Math.floor(Date.now() / 1000) };

const ready = (async () => {
  const bytes = await readFile(join(here, "..", "wasm", "handler.wasm"));
  const { instance } = await WebAssembly.instantiate(bytes, { env });
  return instance.exports;
})();

const encoder = new TextEncoder();

// Split a raw HTTP response into the parts Vercel needs. The module owns the
// status line and the headers, so nothing here decides content types or codes —
// this only re-shapes what it already said.
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
  const wasm = await ready;

  const path = new URL(req.url, "http://localhost").pathname;

  // The whole-site router expects a real request head (method, path, host),
  // not a bare path — the four-route demo was the opposite. Kept minimal;
  // the baked responses decide headers, not this.
  const rawRequest = encoder.encode(
    `GET ${path} HTTP/1.1\r\nHost: korulang.org\r\n\r\n`,
  );

  if (rawRequest.length > wasm.request_cap()) {
    res.statusCode = 414;
    return res.end();
  }

  // Re-read memory.buffer per call — growing a wasm memory detaches every view
  // taken before the growth, and a stale view reads zeroes without complaining.
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