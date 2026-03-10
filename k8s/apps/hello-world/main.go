package main

import (
    "embed"
    "fmt"
    "log"
    "net/http"
)

//go:embed index.html
var htmlContent embed.FS

func main() {
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "text/html")
        data, err := htmlContent.ReadFile("index.html")
        if err != nil {
            http.Error(w, "Page not found", http.StatusNotFound)
            return
        }
        fmt.Fprint(w, string(data))
    })

    http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(http.StatusOK)
        w.Write([]byte(`{"status":"ok"}`))
    })

    log.Println("Server starting on :8080")
    if err := http.ListenAndServe(":8080", nil); err != nil {
        log.Fatalf("Server failed: %v", err)
    }
}