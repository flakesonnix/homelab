package httpapi

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func testServer(t *testing.T) *Server {
	t.Helper()
	s, err := New(
		[]byte(`{"hosts":{"x270":{"hostname":"x270"}},"vms":{}}`),
		[]byte(`{"navigation":[{"label":"Dashboard","path":"/"}]}`),
	)
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	return s
}

func TestHealth(t *testing.T) {
	rec := httptest.NewRecorder()
	testServer(t).Handler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/v1/health", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d", rec.Code)
	}
	var body map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if body["ok"] != true {
		t.Fatalf("ok = %v", body["ok"])
	}
}

func TestMeta(t *testing.T) {
	rec := httptest.NewRecorder()
	testServer(t).Handler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/v1/meta", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d", rec.Code)
	}
	var meta Meta
	if err := json.Unmarshal(rec.Body.Bytes(), &meta); err != nil {
		t.Fatalf("decode: %v", err)
	}
	manifest, ok := meta.Manifest.(map[string]any)
	if !ok || manifest["hosts"] == nil {
		t.Fatalf("manifest not forwarded verbatim: %+v", meta.Manifest)
	}
	ui, ok := meta.UI.(map[string]any)
	if !ok || ui["navigation"] == nil {
		t.Fatalf("ui not forwarded verbatim: %+v", meta.UI)
	}
}

func TestMetaVerbatim(t *testing.T) {
	rec := httptest.NewRecorder()
	testServer(t).Handler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/v1/meta", nil))
	body := rec.Body.String()
	if !strings.Contains(body, `"hosts"`) || !strings.Contains(body, `"navigation"`) {
		t.Fatalf("meta must contain artifact keys, got: %s", body)
	}
}

func TestServeWeb(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "index.html"), []byte("<html>home</html>"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "app.js"), []byte("console.log(1)"), 0o644); err != nil {
		t.Fatal(err)
	}

	s := testServer(t)
	s.ServeWeb(dir)
	h := s.Handler()

	index := httptest.NewRecorder()
	h.ServeHTTP(index, httptest.NewRequest(http.MethodGet, "/", nil))
	if index.Code != http.StatusOK || index.Body.String() != "<html>home</html>" {
		t.Fatalf("index: %d %q", index.Code, index.Body.String())
	}

	asset := httptest.NewRecorder()
	h.ServeHTTP(asset, httptest.NewRequest(http.MethodGet, "/app.js", nil))
	if asset.Code != http.StatusOK || asset.Body.String() != "console.log(1)" {
		t.Fatalf("asset: %d %q", asset.Code, asset.Body.String())
	}

	spa := httptest.NewRecorder()
	h.ServeHTTP(spa, httptest.NewRequest(http.MethodGet, "/hosts", nil))
	if spa.Code != http.StatusOK || spa.Body.String() != "<html>home</html>" {
		t.Fatalf("spa fallback: %d %q", spa.Code, spa.Body.String())
	}

	api := httptest.NewRecorder()
	h.ServeHTTP(api, httptest.NewRequest(http.MethodGet, "/api/v1/health", nil))
	if api.Code != http.StatusOK {
		t.Fatalf("api still reachable: %d", api.Code)
	}
}
