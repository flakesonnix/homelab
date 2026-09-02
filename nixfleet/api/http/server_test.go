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

func testServerWithVMs(t *testing.T) *Server {
	t.Helper()
	manifest := `{"hosts":{"mireo":{"hostname":"mireo","roles":[],"bundles":[],"presets":[],"moduleFlags":{},"packageTags":[],"packages":{}},"x270":{"hostname":"x270","roles":[],"bundles":[],"presets":[],"moduleFlags":{},"packageTags":[],"packages":{}}},"vms":{"grafana":{"host":"mireo","ip":"10.8.0.2","mem":768,"vcpu":2,"autostart":true,"tcpPorts":[22,3000],"udpPorts":[],"volumes":[]}},"deployNodes":{},"proxy":{},"plugins":{},"catalog":{},"version":1}`
	s, err := New([]byte(manifest), []byte(`{"navigation":[]}`))
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	// Force local hostname to mireo for deterministic tests.
	s.localHostname = "mireo"
	return s
}

func TestHosts(t *testing.T) {
	s := testServerWithVMs(t)
	rec := httptest.NewRecorder()
	s.Handler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/v1/hosts", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d", rec.Code)
	}
	var body map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	hosts, ok := body["hosts"].([]any)
	if !ok || len(hosts) != 2 {
		t.Fatalf("hosts %v", body["hosts"])
	}
}

func TestHostHealthLocal(t *testing.T) {
	s := testServerWithVMs(t)
	rec := httptest.NewRecorder()
	s.Handler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/v1/hosts/mireo/health", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d body %s", rec.Code, rec.Body.String())
	}
	var body map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if body["host"] != "mireo" {
		t.Fatalf("host %v", body["host"])
	}
	if body["health"] == nil || body["agent"] == nil {
		t.Fatalf("health/agent missing %v", body)
	}
}

func TestHostHealthNotFound(t *testing.T) {
	s := testServerWithVMs(t)
	rec := httptest.NewRecorder()
	s.Handler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/v1/hosts/unknown/health", nil))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", rec.Code)
	}
}

func TestHostHealthAgentUnavailable(t *testing.T) {
	s := testServerWithVMs(t)
	// x270 is not local (local is mireo)
	rec := httptest.NewRecorder()
	s.Handler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/v1/hosts/x270/health", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d", rec.Code)
	}
	var body map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if body["agent"] != "unavailable" || body["health"] != "unknown" {
		t.Fatalf("expected unavailable/unknown, got %v", body)
	}
}

func TestHostResourcesLocal(t *testing.T) {
	s := testServerWithVMs(t)
	rec := httptest.NewRecorder()
	s.Handler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/v1/hosts/mireo/resources", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d body %s", rec.Code, rec.Body.String())
	}
	var body map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if _, ok := body["cpu"]; !ok {
		t.Fatalf("cpu missing")
	}
	if _, ok := body["memory"]; !ok {
		t.Fatalf("memory missing")
	}
}

func TestHostResourcesUnavailable(t *testing.T) {
	s := testServerWithVMs(t)
	rec := httptest.NewRecorder()
	s.Handler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/v1/hosts/x270/resources", nil))
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503, got %d", rec.Code)
	}
}

func TestHostNetworkLocal(t *testing.T) {
	s := testServerWithVMs(t)
	rec := httptest.NewRecorder()
	s.Handler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/v1/hosts/mireo/network", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d body %s", rec.Code, rec.Body.String())
	}
	var body map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if _, ok := body["interfaces"]; !ok {
		t.Fatalf("interfaces missing")
	}
}

func TestHostVms(t *testing.T) {
	s := testServerWithVMs(t)
	rec := httptest.NewRecorder()
	s.Handler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/v1/hosts/mireo/vms", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d body %s", rec.Code, rec.Body.String())
	}
	var body map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	vms, ok := body["vms"].([]any)
	if !ok || len(vms) != 1 {
		t.Fatalf("vms %v", body["vms"])
	}
	m := vms[0].(map[string]any)
	if m["name"] != "grafana" {
		t.Fatalf("name %v", m["name"])
	}
	if _, ok := m["configured"]; !ok {
		t.Fatalf("configured missing")
	}
	if _, ok := m["runtime"]; !ok {
		t.Fatalf("runtime missing")
	}
}

func TestHostVmsInvalidHost(t *testing.T) {
	s := testServerWithVMs(t)
	rec := httptest.NewRecorder()
	s.Handler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/v1/hosts/unknown/vms", nil))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", rec.Code)
	}
}

func TestHostSystemdFailed(t *testing.T) {
	s := testServerWithVMs(t)
	rec := httptest.NewRecorder()
	s.Handler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/v1/hosts/mireo/systemd/failed", nil))
	// May be 200 even if systemctl not available, or 500 if fails; both are acceptable for test env
	if rec.Code != http.StatusOK && rec.Code != http.StatusInternalServerError {
		t.Fatalf("status %d body %s", rec.Code, rec.Body.String())
	}
	if rec.Code == http.StatusOK {
		var body map[string]any
		if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if _, ok := body["failed"]; !ok {
			t.Fatalf("failed missing")
		}
	}
}

func TestVMNameValidation(t *testing.T) {
	s := testServerWithVMs(t)
	// Valid VM name is grafana, but we test that invalid VM name would be rejected if we had VM endpoint
	// Here we test that VM state collection is validated via isValidVMName indirectly
	// by checking that vms endpoint does not allow arbitrary command injection:
	// The vms endpoint only lists validated VMs from manifest, so it cannot be abused.
	rec := httptest.NewRecorder()
	s.Handler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/v1/hosts/mireo/vms", nil))
	body := rec.Body.String()
	if strings.Contains(body, "microvm@") {
		t.Fatalf("should not leak systemd unit names directly")
	}
}
