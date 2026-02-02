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
    })
    .backlog(1024)
    .bind("0.0.0.0:3004")?
    .run()
    .await
}
