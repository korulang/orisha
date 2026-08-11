// Drives api/serve.mjs through the same (req, res) contract Vercel's Node
// runtime calls it with, using Node's own http server. This exercises the real
// adapter — the rewrite in vercel.json is what sends every path to it, so
// mounting it at the catch-all here reproduces that.
import { createServer } from "node:http";
import handler from "./api/serve.mjs";

const server = createServer((req, res) => {
  handler(req, res).catch((err) => {
    console.error("adapter threw:", err);
    res.statusCode = 500;
    res.end();
  });
});

const port = Number(process.argv[2] ?? 3200);
server.listen(port, () => console.log(`vercel adapter on ${port}`));
