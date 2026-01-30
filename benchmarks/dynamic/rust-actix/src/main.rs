// Minimal actix-web HTTP server for benchmark comparison
// Build: cargo build --release
// Run: ./target/release/orisha-benchmark-actix
// Serves on port 3004

use actix_web::{get, web, App, HttpResponse, HttpServer};
use serde::Serialize;

// Embed files at compile time (like Orisha)
const INDEX_HTML: &str = include_str!("../public/index.html");
const ABOUT_HTML: &str = include_str!("../public/about.html");

#[derive(Serialize)]
struct HealthResponse {
    status: &'static str,
}

#[derive(Serialize)]
struct UserResponse {
    id: String,
    name: String,
}

#[get("/")]
async fn index() -> HttpResponse {
    HttpResponse::Ok()
        .content_type("text/html; charset=utf-8")
        .body(INDEX_HTML)
}

#[get("/about")]
async fn about() -> HttpResponse {
    HttpResponse::Ok()
        .content_type("text/html; charset=utf-8")
        .body(ABOUT_HTML)
}

#[get("/api/health")]
async fn health() -> HttpResponse {
    HttpResponse::Ok().json(HealthResponse { status: "ok" })
}

#[get("/api/users/{id}")]
async fn get_user(path: web::Path<String>) -> HttpResponse {
    let id = path.into_inner();
    HttpResponse::Ok().json(UserResponse {
        name: format!("User {}", id),
        id,
    })
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    println!("actix-web server listening on :3004");
    HttpServer::new(|| {
        App::new()
            .service(index)
            .service(about)
            .service(health)
            .service(get_user)
    })
    .bind("127.0.0.1:3004")?
    .run()
    .await
}
