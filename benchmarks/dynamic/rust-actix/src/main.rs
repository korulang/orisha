// TechEmpower-optimized actix-web HTTP server for benchmark comparison
// Build: cargo build --release
// Run: ./target/release/orisha-benchmark-actix
// Serves on port 3004

#[global_allocator]
static ALLOC: snmalloc_rs::SnMalloc = snmalloc_rs::SnMalloc;

use actix_web::{
    http::{
        header::{HeaderValue, CONTENT_TYPE, SERVER},
        StatusCode,
    },
    web::{self, Bytes, BytesMut},
    App, HttpResponse, HttpServer,
};
use simd_json_derive::Serialize;

// Embed files at compile time as static bytes
const INDEX_HTML: &[u8] = include_bytes!("../public/index.html");
const ABOUT_HTML: &[u8] = include_bytes!("../public/about.html");

#[derive(Serialize)]
struct Message {
    message: &'static str,
}

#[derive(Serialize)]
struct HealthResponse {
    status: &'static str,
}

#[derive(Serialize)]
struct UserResponse<'a> {
    id: &'a str,
    name: String,
}

// Writer helper for simd-json
struct Writer<'a>(&'a mut BytesMut);

impl std::io::Write for Writer<'_> {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        self.0.extend_from_slice(buf);
        Ok(buf.len())
    }
    fn flush(&mut self) -> std::io::Result<()> {
        Ok(())
    }
}

async fn index() -> HttpResponse<Bytes> {
    let mut res = HttpResponse::with_body(StatusCode::OK, Bytes::from_static(INDEX_HTML));
    res.headers_mut()
        .insert(SERVER, HeaderValue::from_static("A"));
    res.headers_mut()
        .insert(CONTENT_TYPE, HeaderValue::from_static("text/html; charset=utf-8"));
    res
}

async fn about() -> HttpResponse<Bytes> {
    let mut res = HttpResponse::with_body(StatusCode::OK, Bytes::from_static(ABOUT_HTML));
    res.headers_mut()
        .insert(SERVER, HeaderValue::from_static("A"));
    res.headers_mut()
        .insert(CONTENT_TYPE, HeaderValue::from_static("text/html; charset=utf-8"));
    res
}

async fn plaintext() -> HttpResponse<Bytes> {
    let mut res = HttpResponse::with_body(StatusCode::OK, Bytes::from_static(b"Hello, World!"));
    res.headers_mut()
        .insert(SERVER, HeaderValue::from_static("A"));
    res.headers_mut()
        .insert(CONTENT_TYPE, HeaderValue::from_static("text/plain"));
    res
}

async fn json() -> HttpResponse<Bytes> {
    let message = Message { message: "Hello, World!" };
    let mut body = BytesMut::with_capacity(32);
    message.json_write(&mut Writer(&mut body)).unwrap();

    let mut res = HttpResponse::with_body(StatusCode::OK, body.freeze());
    res.headers_mut()
        .insert(SERVER, HeaderValue::from_static("A"));
    res.headers_mut()
        .insert(CONTENT_TYPE, HeaderValue::from_static("application/json"));
    res
}

async fn health() -> HttpResponse<Bytes> {
    let msg = HealthResponse { status: "ok" };
    let mut body = BytesMut::with_capacity(16);
    msg.json_write(&mut Writer(&mut body)).unwrap();

    let mut res = HttpResponse::with_body(StatusCode::OK, body.freeze());
    res.headers_mut()
        .insert(SERVER, HeaderValue::from_static("A"));
    res.headers_mut()
        .insert(CONTENT_TYPE, HeaderValue::from_static("application/json"));
    res
}

fn user_json_body(id: &str, name: &str) -> Bytes {
    let mut b = BytesMut::with_capacity(64);
    b.extend_from_slice(b"{\"id\":\"");
    b.extend_from_slice(id.as_bytes());
    b.extend_from_slice(b"\",\"name\":\"");
    b.extend_from_slice(name.as_bytes());
    b.extend_from_slice(b"\"}");
    b.freeze()
}

// DB leg: full driver path per request — open, prepare, bind, step, close.
// A missing row is the spec'd 200 {}; a driver failure is a 500, not a
// success-shaped empty object.
async fn get_db_user(path: web::Path<String>) -> HttpResponse<Bytes> {
    let id = path.into_inner();
    let res_body = (|| -> Result<Option<Bytes>, rusqlite::Error> {
        let conn = rusqlite::Connection::open("../bench.db")?;
        let mut stmt = conn.prepare("SELECT name FROM users WHERE id = ?1")?;
        match stmt.query_row([&id], |r| r.get::<_, String>(0)) {
            Ok(name) => Ok(Some(user_json_body(&id, &name))),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(e),
        }
    })();

    let mut res = match res_body {
        Ok(Some(b)) => HttpResponse::with_body(StatusCode::OK, b),
        Ok(None) => HttpResponse::with_body(StatusCode::OK, Bytes::from_static(b"{}")),
        Err(_) => HttpResponse::with_body(StatusCode::INTERNAL_SERVER_ERROR, Bytes::from_static(b"{\"error\":\"db\"}")),
    };
    res.headers_mut()
        .insert(SERVER, HeaderValue::from_static("A"));
    res.headers_mut()
        .insert(CONTENT_TYPE, HeaderValue::from_static("application/json"));
    res
}

// Persistent leg: one connection + one prepared statement per worker thread —
// the shape a real service takes. The connection is leaked to 'static so the
// Statement can live beside it in TLS; per request: bind, step, reset.
thread_local! {
    static HOT_STMT: std::cell::RefCell<Option<rusqlite::Statement<'static>>> =
        const { std::cell::RefCell::new(None) };
}

async fn get_db_user_hot(path: web::Path<String>) -> HttpResponse<Bytes> {
    let id = path.into_inner();
    // Some(body) = 200 row or miss; None = driver failure -> 500.
    let body = HOT_STMT.with(|cell| -> Option<Bytes> {
        let mut slot = cell.borrow_mut();
        if slot.is_none() {
            let conn: &'static rusqlite::Connection = Box::leak(Box::new(
                rusqlite::Connection::open_with_flags(
                    "../bench.db",
                    rusqlite::OpenFlags::SQLITE_OPEN_READ_WRITE
                        | rusqlite::OpenFlags::SQLITE_OPEN_NO_MUTEX
                        | rusqlite::OpenFlags::SQLITE_OPEN_URI
                        | rusqlite::OpenFlags::SQLITE_OPEN_PRIVATE_CACHE,
                )
                .ok()?,
            ));
            *slot = conn.prepare("SELECT name FROM users WHERE id = ?1").ok();
        }
        let stmt = slot.as_mut()?;
        match stmt.query_row([&id], |r| r.get::<_, String>(0)) {
            Ok(n) => Some(user_json_body(&id, &n)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Some(Bytes::from_static(b"{}")),
            Err(_) => None,
        }
    });

    let mut res = match body {
        Some(b) => HttpResponse::with_body(StatusCode::OK, b),
        None => HttpResponse::with_body(StatusCode::INTERNAL_SERVER_ERROR, Bytes::from_static(b"{\"error\":\"db\"}")),
    };
    res.headers_mut()
        .insert(SERVER, HeaderValue::from_static("A"));
    res.headers_mut()
        .insert(CONTENT_TYPE, HeaderValue::from_static("application/json"));
    res
}

async fn get_user(path: web::Path<String>) -> HttpResponse<Bytes> {
    let id = path.into_inner();
    let user = UserResponse {
        name: format!("User {}", id),
        id: &id,
    };
    let mut body = BytesMut::with_capacity(64);
    user.json_write(&mut Writer(&mut body)).unwrap();

    let mut res = HttpResponse::with_body(StatusCode::OK, body.freeze());
    res.headers_mut()
        .insert(SERVER, HeaderValue::from_static("A"));
    res.headers_mut()
        .insert(CONTENT_TYPE, HeaderValue::from_static("application/json"));
    res
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    println!("actix-web server listening on :3004");

    HttpServer::new(|| {
        App::new()
            .route("/", web::get().to(index))
            .route("/about", web::get().to(about))
            .route("/plaintext", web::get().to(plaintext))
            .route("/json", web::get().to(json))
            .route("/api/health", web::get().to(health))
            .route("/api/users/{id}", web::get().to(get_user))
            .route("/api/db/users/{id}", web::get().to(get_db_user))
            .route("/api/db/hot/users/{id}", web::get().to(get_db_user_hot))
    })
    .backlog(1024)
    .bind("0.0.0.0:3004")?
    .run()
    .await
}
