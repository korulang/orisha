// Two natural run calls, one open pump: an interactive vaxis TUI and an
// Orisha HTTP server written exactly as each would stand alone — the open
// `std/pump` absorbs both. One thread, one kernel poll() over the listener
// fd and the terminal's wake pipe, capped by vaxis's tick.
//
//   koruc run examples/pump-tui/main.k
//   curl localhost:3001   — the counter climbs; q quits both.
//
// Nothing in either run call spells pump vocabulary: `create` opens the
// region, `run` drives it, and each library's own run transform emits the
// join units (`__pump_app_{step,live,wait,retired}_<i>`) that `std/pump:run`
// enumerates. `| stopped`/`| done` ride those retire units — they fire when
// the participant's `live()` first answers 0, which is exactly what `q`
// causes for both. The served count is an atomic in lib/stats: `! arrived`
// fires on orisha's worker threads, where a store write would be a race.
//
// A canned answer: the full `raw->answer->reply` pipeline lives in
// orisha/index.k (always loaded via the `orisha` prefix), which drags
// std/compiler into the consumer program — an ambient toolchain leak
// unrelated to the pump composition. The pump verbs stand alone; reply()
// with a static response is enough to prove requests arrive and get
// answered from inside a compound pump.

import std/io
import std/fmt
import std/pump
import orisha/pump
import koru/vaxis
import lib/stats

std/pump:create(app)
| drained |> std/io:print.ln("pump drained")

orisha/pump:run(port: 3001)
! arrived x |> lib/stats:bump() |> orisha/pump:reply(x, head: "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 42\r\nConnection: close\r\n\r\nhello from a pump shared with a vaxis TUI\n", body: "", date_hole: 0, head_static: true, body_static: false, hang: true)
    | sent |> _
    | broken _ |> _
! frame f |> orisha/pump:ws-frame(f)
! closed fd |> orisha/pump:ws-closed(fd)
| failed e |> std/io:print.ln("orisha failed: {{ e:s }}")
| stopped |> std/io:print.ln("orisha stopped")

koru/vaxis:run(title: "pump-tui", tick_ms: 16)
! draw _ |> lib/stats:count(): n
    |> std/fmt:ln("requests served: {{ n:d }}"): line
    |> koru/vaxis:box(x: 2, y: 1, w: 62, h: 9, border: true): f
    |> koru/vaxis:write-in(win: f, x: 1, y: 0, text: "pump-tui — orisha + vaxis, one std/pump")
    |> koru/vaxis:write-in(win: f, x: 1, y: 2, text: "http   orisha kqueue server — curl localhost:3001")
    |> koru/vaxis:write-in(win: f, x: 1, y: 3, text: "tty    this vaxis dashboard — wake pipe + 16ms tick")
    |> koru/vaxis:write-in(win: f, x: 1, y: 4, text: "wait   one poll() over both interests, nearest deadline")
    |> koru/vaxis:write-in(win: f, x: 1, y: 6, line.text)
    |> koru/vaxis:write-at(x: 2, y: 10, text: "q quits both — retire units tear each down")
    |> koru/vaxis:render()
! char k when k.ch == 'q' |> koru/vaxis:quit() |> orisha/pump:stop()
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
| done |> std/io:print.ln("vaxis done")

std/pump:run(app)
