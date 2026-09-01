// Minimal HttpArena-shaped reference server for same-machine wrk comparisons.
// Not a board entry — deliberately tiny stdlib net/http, no TLS.
package main

import (
	"fmt"
	"net/http"
	"strconv"
	"strings"
)

func baseline11(w http.ResponseWriter, r *http.Request) {
	a, _ := strconv.Atoi(r.URL.Query().Get("a"))
	b, _ := strconv.Atoi(r.URL.Query().Get("b"))
	sum := a + b
	if r.Method == http.MethodPost {
		var body [64]byte
		n, _ := r.Body.Read(body[:])
		if n > 0 {
			if v, err := strconv.Atoi(strings.TrimSpace(string(body[:n]))); err == nil {
				sum += v
			}
		}
	}
	w.Header().Set("Content-Type", "text/plain")
	fmt.Fprint(w, sum)
}

func main() {
	http.HandleFunc("/pipeline", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain")
		w.Write([]byte("ok"))
	})
	http.HandleFunc("/baseline11", baseline11)
	fmt.Println("reference listening on :8090")
	http.ListenAndServe(":8090", nil)
}
