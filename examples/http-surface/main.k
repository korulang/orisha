// HTTP surface — request headers in, response headers out, urldecoded fields.
//
// The four seams this exercises:
//   req.headers            - the raw header block, scanned lazily
//   orisha:header/cookie   - one header / one Cookie pair, ?string
//   orisha:form/query-param- one urlencoded codec over body and query
//   extra_headers          - handler CRLF block spliced into the response head
//
// Build & run:
//   koruc main.k && ./a.out          (serves on :3199)
//
// Verify:
//   curl -i -H 'Cookie: session=abc123; theme=dark' localhost:3199/whoami
//   curl -i -H 'Cookie: session=abc123; theme=dark' localhost:3199/session
//   curl -i localhost:3199/login
//   curl -i -X POST localhost:3199/form -d 'name=ada+lovelace&city=paris'
//   curl -i 'localhost:3199/search?q=koru+rocks&page=2'

import orisha
import std/fmt
import std/io

// ?string -> string: the fmt:ln {s} spec needs a definite string, and a
// missing field deserves a visible marker rather than an unwrap panic.
pub tor or-empty { s: ?string } -> string

or-empty -> s orelse "(missing)"

orisha:handler = orisha:router(req)
! [GET /whoami] |> orisha:header(req, name: "cookie"): hdr -> { status: 200, body: hdr orelse "(no cookie)", content_type: "text/plain" }
! [GET /session] |> orisha:cookie(req, name: "session"): sess -> { status: 200, body: sess orelse "(no session)", content_type: "text/plain" }
! [GET /h/:name] p |> orisha:header(req, p.name): v -> { status: 200, body: v orelse "(absent)", content_type: "text/plain" }
! [GET /login] -> { status: 302, body: "", content_type: "text/plain", extra_headers: "Location: /whoami\r\nSet-Cookie: session=abc123; Path=/\r\n" }
! [GET /big] -> { status: 200, body: "wide head", content_type: "text/plain", extra_headers: "X-One: 1\r\nX-Two: 2\r\nX-Three: 3\r\nX-Four: 4\r\nX-Five: 5\r\nX-Six: 6\r\nX-Seven: 7\r\nX-Eight: 8\r\nX-Nine: 9\r\nX-Ten: 10\r\nX-Eleven: 11\r\nX-Twelve: 12\r\nX-Thirteen: 13\r\nX-Fourteen: 14\r\nX-Fifteen: 15\r\nX-Sixteen: 16\r\nX-Seventeen: 17\r\nX-Eighteen: 18\r\nX-Nineteen: 19\r\nX-Twenty: 20\r\nX-Twenty-One: 21\r\nX-Twenty-Two: 22\r\nX-Twenty-Three: 23\r\nX-Twenty-Four: 24\r\nX-Twenty-Five: 25\r\nX-Twenty-Six: 26\r\nX-Twenty-Seven: 27\r\nX-Twenty-Eight: 28\r\nX-Twenty-Nine: 29\r\nX-Thirty: 30\r\n" }
! [POST /form] _ |> orisha:form(req, name: "name"): n
    |> or-empty(s: n): name
    |> orisha:form(req, name: "city"): c
    |> or-empty(s: c): city
    |> std/fmt:ln("name={{name:s}} city={{city:s}}")
    | line l -> { status: 200, body: l.text, content_type: "text/plain" }
! [GET /search] |> orisha:query-param(req, name: "q"): q
    |> or-empty(s: q): query
    |> orisha:query-param(req, name: "page"): p
    |> or-empty(s: p): page
    |> std/fmt:ln("q={{query:s}} page={{page:s}}")
    | line l -> { status: 200, body: l.text, content_type: "text/plain" }
! [*] -> { status: 404, body: "Not Found", content_type: "text/plain" }

orisha:serve(port: 3199)
| shutdown s |> std/io:print.ln(s)
| failed f |> std/io:print.ln(f)
