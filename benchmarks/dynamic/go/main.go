// Minimal Go HTTP server for benchmark comparison
// Build: go build -o server main.go
// Run: ./server
// Serves on port 3002

package main

import (
	"embed"
	"fmt"
	"net/http"
	"strings"
)

//go:embed public/*
var staticFiles embed.FS

func main() {
	// Static files - embedded at compile time (like Orisha)
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/" {
			data, _ := staticFiles.ReadFile("public/index.html")
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			w.Write(data)
			return
		}
		if r.URL.Path == "/about" {
			data, _ := staticFiles.ReadFile("public/about.html")
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			w.Write(data)
			return
		}
		http.NotFound(w, r)
	})

	// Health check
	http.HandleFunc("/api/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"ok"}`))
	})

	// Dynamic user endpoint
	http.HandleFunc("/api/users/", func(w http.ResponseWriter, r *http.Request) {
		// Extract ID from path: /api/users/123 -> 123
		path := r.URL.Path
		id := strings.TrimPrefix(path, "/api/users/")
		if id == "" || strings.Contains(id, "/") {
			http.NotFound(w, r)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		fmt.Fprintf(w, `{"id":"%s","name":"User %s"}`, id, id)
	})

	fmt.Println("Go server listening on :3002")
	http.ListenAndServe(":3002", nil)
}
