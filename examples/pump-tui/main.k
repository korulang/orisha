// Two pumps, one driver: an interactive vaxis TUI and an Orisha HTTP server
// in the same binary, composed by std/pump. Orisha's `! arrived` arms `init`
// (its workers fire it on their own threads); vaxis's `!` surface rides the
// join's `! step`. `q` in the terminal stops both: vaxis's quit drains its
// live(), orisha's stop() drains its — then `| drained` tears both down.

import std/io
import std/pump
import orisha/pump
import koru/vaxis

// A canned answer: the full `raw→answer→reply` pipeline lives in
// orisha/index.k (always loaded via the `orisha` prefix), which drags std/compiler into the consumer program — an
// ambient toolchain leak unrelated to the pump composition. The pump verbs
// stand alone; reply() with a static response is enough to prove requests
// arrive and get answered from inside a vaxis pump.
orisha/pump:init(port: 3001)
! arrived x |> orisha/pump:reply(x, head: "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 42\r\nConnection: close\r\n\r\nhello from a pump shared with a vaxis TUI\n", body: "")
    | sent |> _
    | broken _ |> _
| failed e |> std/io:print.ln("orisha failed: {{ e:s }}")

koru/vaxis:init(title: "pump-tui")
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")

std/pump:create(app)
| drained |> orisha/pump:deinit() |> koru/vaxis:deinit()

std/pump(app)
! step |> orisha/pump:step()
! live |> orisha/pump:live()
! wait i |> orisha/pump:wait(i)

std/pump(app)
! step |> koru/vaxis:step()
    ! draw _ |> koru/vaxis:write-styled(x: 2, y: 2, text: "vaxis + orisha, one pump — curl :3001, q quits both", style: { bold: false, dim: false, italic: false, strikethrough: false, fg: 0x5A56E0 })
        |> koru/vaxis:render()
    ! char k when k.ch == 'q' |> koru/vaxis:quit() |> orisha/pump:stop()
! live |> koru/vaxis:live()
! wait i |> koru/vaxis:wait(i)

std/pump:run(app)
