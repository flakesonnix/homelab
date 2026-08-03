// Package httpapi implements the homectl API HTTP surface (M0: health + meta).
package httpapi

import (
	"encoding/json"
	"net/http"
	"path/filepath"

	"homectl/shared/version"
)

// Meta bundles the Nix-generated artifacts served to the frontend.
type Meta struct {
	Manifest any `json:"manifest"`
	UI       any `json:"ui"`
}

// Server is the homectl API server (M0 subset).
type Server struct {
	meta Meta
	web  http.Handler
}

// New creates a Server with the given artifacts. Artifacts are plain decoded
// JSON (structure is decided by Nix, never by Go).
func New(manifest, ui []byte) (*Server, error) {
	var m, u any
	if err := json.Unmarshal(manifest, &m); err != nil {
		return nil, err
	}
	if err := json.Unmarshal(ui, &u); err != nil {
		return nil, err
	}
	return &Server{meta: Meta{Manifest: m, UI: u}}, nil
}

// ServeWeb enables serving the static frontend (Vite build output) from dir
// below /, with a single-page-app fallback to index.html for unknown paths.
func (s *Server) ServeWeb(dir string) {
	root := http.Dir(dir)
	s.web = http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		p := "." + r.URL.Path
		if f, err := root.Open(p); err == nil {
			f.Close()
			http.ServeFile(w, r, filepath.Join(dir, r.URL.Path))
			return
		}
		http.ServeFile(w, r, filepath.Join(dir, "index.html"))
	})
}

// Handler returns the API HTTP handler.
func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/v1/health", s.handleHealth)
	mux.HandleFunc("GET /api/v1/meta", s.handleMeta)
	if s.web != nil {
		mux.Handle("/", s.web)
	}
	return mux
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "version": version.String()})
}

func (s *Server) handleMeta(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, s.meta)
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
