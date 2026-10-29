// TechEmpower route bundle — pure Koru. Every route is a real handler: the
// static tests answer with wire-baked responses (TFB permits precomputation
// for static content); the database tests mint obligations — a response
// carrying pending_kind is not a response yet, it is a debt the pump's
// discharger settles through the suspend/resume machinery (pgPark). There is
// no response caching anywhere: every minted obligation costs a real Postgres
// round trip the TFB audit can count.
//
// Server + Date headers are mandatory for every TFB response. Orisha emits
// Date itself; Server rides on extra_headers.

import orisha
import std/json
import std/string

pub tor plaintext { req: *orisha:Request } -> orisha:Response
pub tor json { req: *orisha:Request } -> orisha:Response
pub tor db { req: *orisha:Request } -> orisha:Response
pub tor queries { req: *orisha:Request } -> orisha:Response
pub tor fortunes { req: *orisha:Request } -> orisha:Response
pub tor updates { req: *orisha:Request } -> orisha:Response
pub tor cached-worlds { req: *orisha:Request } -> orisha:Response

plaintext -> { status: 200, body: "HTTP/1.1 200 OK\r\nContent-Length: 13\r\nContent-Type: text/plain\r\nServer: koru-orisha\r\n\r\nHello, World!", content_type: "text/plain", body_static: true, wire: true, wire_date_hole: 63 }

json -> { status: 200, body: "HTTP/1.1 200 OK\r\nContent-Length: 27\r\nContent-Type: application/json\r\nServer: koru-orisha\r\n\r\n{\"message\":\"Hello, World!\"}", content_type: "application/json", body_static: true, wire: true, wire_date_hole: 69 }

// DB routes — each mints the obligation the discharger parks on. Kind 1: one
// world row; kind 2: N world rows; kind 3: N select+update pairs; kind 4:
// the fortune stream. The response the client sees is produced when the
// obligation is settled — the handler owes the row, it does not fake it.
db -> { status: 200, body: "", content_type: "application/json", pending_kind: 1 }
queries -> { status: 200, body: "", content_type: "application/json", pending_kind: 2 }
cached-worlds -> { status: 200, body: "", content_type: "application/json", pending_kind: 2 }
updates -> { status: 200, body: "", content_type: "application/json", pending_kind: 3 }
fortunes -> { status: 200, body: "", content_type: "text/html", pending_kind: 4 }
