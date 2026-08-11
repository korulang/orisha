// Local proof. Raw TCP, not node:http — the wasm module emits a complete HTTP
// response including the status line, so wrapping it in Node's http server
// would prove that Node can serve, not that the module can answer.
//
// This is also the shape Orisha's own pump would drive it with: bytes in,
// bytes out, the loop owned by whoever is holding the socket.
import { createServer } from "node:net";
import { readFile } from "node:fs/promises";

const wasmBytes = await readFile(new URL("./a.out", import.meta.url));
const { instance } = await WebAssembly.instantiate(wasmBytes, {});
const { memory, request_ptr, request_cap, response_ptr, handle } = instance.exports;

const encoder = new TextEncoder();

function answer(path) {
  // memory.buffer is re-read on every call: a wasm memory that grows detaches
  // any view taken before the growth, and a stale view reads zeroes silently.
  const bytes = encoder.encode(path);
  if (bytes.length > request_cap()) return null;

  new Uint8Array(memory.buffer).set(bytes, request_ptr());
  const written = handle(bytes.length);
  if (written === 0) return null;

  const start = response_ptr();
  return Buffer.from(memory.buffer.slice(start, start + written));
}

const server = createServer((socket) => {
  socket.once("data", (chunk) => {
    const requestLine = chunk.toString("latin1").split("\r\n")[0] ?? "";
    const target = requestLine.split(" ")[1] ?? "/";
    const path = target.split("?")[0];

    const response = answer(path);
    if (response === null) {
      socket.end("HTTP/1.1 500 Internal Server Error\r\nContent-Length: 0\r\n\r\n");
      return;
    }
    socket.end(response);
  });
  socket.on("error", () => {});
});

const port = Number(process.argv[2] ?? 3100);
server.listen(port, () => console.log(`koru/wasm listening on ${port}`));
