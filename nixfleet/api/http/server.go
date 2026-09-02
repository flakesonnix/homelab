// Package httpapi implements the nixfleet API HTTP surface (M1: health + meta + runtime).
package httpapi

import (
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"nixfleet/api/manifest"
	"nixfleet/api/runtime"
	"nixfleet/shared/version"
)

// Meta bundles the Nix-generated artifacts served to the frontend.
type Meta struct {
	Manifest any `json:"manifest"`
	UI       any `json:"ui"`
}

// Server is the nixfleet API server.
type Server struct {
	meta          Meta
	manifestTyped *manifest.Manifest
	localHostname string
	web           http.Handler
}

// New creates a Server with the given artifacts. Artifacts are plain decoded
// JSON (structure is decided by Nix, never by Go).
func New(manifestData, ui []byte) (*Server, error) {
	var m, u any
	if err := json.Unmarshal(manifestData, &m); err != nil {
		return nil, err
	}
	if err := json.Unmarshal(ui, &u); err != nil {
		return nil, err
	}
	typed, err := manifest.Parse(manifestData)
	if err != nil {
		return nil, err
	}
	hostname, _ := os.Hostname()
	// Use short hostname for comparison.
	if idx := strings.Index(hostname, "."); idx != -1 {
		hostname = hostname[:idx]
	}
	return &Server{
		meta:          Meta{Manifest: m, UI: u},
		manifestTyped: typed,
		localHostname: hostname,
	}, nil
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
	mux.HandleFunc("GET /api/v1/hosts", s.handleHosts)
	mux.HandleFunc("GET /api/v1/hosts/{host}/health", s.handleHostHealth)
	mux.HandleFunc("GET /api/v1/hosts/{host}/resources", s.handleHostResources)
	mux.HandleFunc("GET /api/v1/hosts/{host}/network", s.handleHostNetwork)
	mux.HandleFunc("GET /api/v1/hosts/{host}/vms", s.handleHostVms)
	mux.HandleFunc("GET /api/v1/hosts/{host}/systemd/failed", s.handleHostSystemdFailed)
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

func (s *Server) handleHosts(w http.ResponseWriter, r *http.Request) {
	hosts := make([]map[string]any, 0, len(s.manifestTyped.Hosts))
	for name, h := range s.manifestTyped.Hosts {
		hosts = append(hosts, map[string]any{
			"name":     name,
			"hostname": h.Hostname,
			"roles":    h.Roles,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"hosts": hosts})
}

type hostHealthResponse struct {
	Host       string `json:"host"`
	Hostname   string `json:"hostname"`
	Kernel     string `json:"kernel,omitempty"`
	OS         string `json:"os,omitempty"`
	OSPretty   string `json:"osPretty,omitempty"`
	UptimeS    *uint64 `json:"uptimeS,omitempty"`
	Health     string `json:"health"`
	Agent      string `json:"agent"`
	FailedUnits int    `json:"failedUnits"`
	Timestamp  string `json:"timestamp"`
}

func (s *Server) handleHostHealth(w http.ResponseWriter, r *http.Request) {
	host := r.PathValue("host")
	h, ok := s.manifestTyped.Hosts[host]
	if !ok {
		writeError(w, http.StatusNotFound, "NOT_FOUND", "host does not exist")
		return
	}
	local := s.isLocalHost(host)
	var sys runtime.SystemInfo
	var failed []runtime.FailedUnit
	var health, agent string
	var uptime *uint64
	if local {
		if sInfo, err := runtime.CollectSystem(); err == nil {
			sys = sInfo
			u := sInfo.UptimeS
			uptime = &u
		}
		if f, err := runtime.CollectFailedUnits(); err == nil {
			failed = f
		}
		agent = "connected"
		if len(failed) == 0 {
			health = "healthy"
		} else {
			health = "degraded"
		}
	} else {
		agent = "unavailable"
		health = "unknown"
	}
	// Use declared hostname for response, but also include collected if local
	hostname := h.Hostname
	if local && sys.Hostname != "" {
		hostname = sys.Hostname
	}
	resp := hostHealthResponse{
		Host:       host,
		Hostname:   hostname,
		Kernel:     sys.Kernel,
		OS:         sys.OS,
		OSPretty:   sys.OSPretty,
		UptimeS:    uptime,
		Health:     health,
		Agent:      agent,
		FailedUnits: len(failed),
		Timestamp:  time.Now().UTC().Format(time.RFC3339),
	}
	writeJSON(w, http.StatusOK, resp)
}

func (s *Server) handleHostResources(w http.ResponseWriter, r *http.Request) {
	host := r.PathValue("host")
	if _, ok := s.manifestTyped.Hosts[host]; !ok {
		writeError(w, http.StatusNotFound, "NOT_FOUND", "host does not exist")
		return
	}
	if !s.isLocalHost(host) {
		writeError(w, http.StatusServiceUnavailable, "AGENT_UNAVAILABLE", "agent unavailable for host")
		return
	}
	res, err := runtime.CollectResources()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "COLLECT_FAILED", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, res)
}

func (s *Server) handleHostNetwork(w http.ResponseWriter, r *http.Request) {
	host := r.PathValue("host")
	if _, ok := s.manifestTyped.Hosts[host]; !ok {
		writeError(w, http.StatusNotFound, "NOT_FOUND", "host does not exist")
		return
	}
	if !s.isLocalHost(host) {
		writeError(w, http.StatusServiceUnavailable, "AGENT_UNAVAILABLE", "agent unavailable for host")
		return
	}
	net, err := runtime.CollectNetwork()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "COLLECT_FAILED", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, net)
}

type vmResponse struct {
	Name       string         `json:"name"`
	Configured manifest.VM    `json:"configured"`
	Runtime    runtime.VMRuntime `json:"runtime"`
	Health     string         `json:"health"`
}

func (s *Server) handleHostVms(w http.ResponseWriter, r *http.Request) {
	host := r.PathValue("host")
	if _, ok := s.manifestTyped.Hosts[host]; !ok {
		writeError(w, http.StatusNotFound, "NOT_FOUND", "host does not exist")
		return
	}
	vms := s.manifestTyped.VMsForHost(host)
	local := s.isLocalHost(host)
	var out []vmResponse
	for name, cfg := range vms {
		var rt runtime.VMRuntime
		if local {
			if st, err := runtime.CollectVMState(name); err == nil {
				rt = st
			} else {
				rt = runtime.VMRuntime{State: "unknown"}
			}
		} else {
			rt = runtime.VMRuntime{State: "unknown"}
		}
		health := "unknown"
		if rt.State == "running" {
			health = "healthy"
		} else if rt.State == "stopped" {
			if cfg.Autostart {
				health = "degraded"
			} else {
				health = "healthy"
			}
		}
		out = append(out, vmResponse{
			Name:       name,
			Configured: cfg,
			Runtime:    rt,
			Health:     health,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"vms": out})
}

func (s *Server) handleHostSystemdFailed(w http.ResponseWriter, r *http.Request) {
	host := r.PathValue("host")
	if _, ok := s.manifestTyped.Hosts[host]; !ok {
		writeError(w, http.StatusNotFound, "NOT_FOUND", "host does not exist")
		return
	}
	if !s.isLocalHost(host) {
		writeError(w, http.StatusServiceUnavailable, "AGENT_UNAVAILABLE", "agent unavailable for host")
		return
	}
	units, err := runtime.CollectFailedUnits()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "COLLECT_FAILED", err.Error())
		return
	}
	if units == nil {
		units = []runtime.FailedUnit{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"failed": units})
}

func (s *Server) isLocalHost(host string) bool {
	if host == s.localHostname {
		return true
	}
	if h, ok := s.manifestTyped.Hosts[host]; ok {
		if h.Hostname == s.localHostname {
			return true
		}
	}
	// Also consider that API may run on mireo and host param is "mireo" while localHostname is "mireo"
	return false
}

func writeError(w http.ResponseWriter, status int, code, message string) {
	writeJSON(w, status, map[string]any{
		"error": map[string]string{
			"code":    code,
			"message": message,
		},
	})
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
