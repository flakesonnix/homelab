package httpapi

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func testServer(t *testing.T) *Server {
	t.Helper()
	s, err := New(
		[]byte(`{"hosts":{"omen":{"hostname":"omen"}},"vms":{}}`),
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
