package manifest

import (
	"testing"
)

func TestParse(t *testing.T) {
	data := []byte(`{"version":1,"hosts":{"mireo":{"hostname":"mireo","roles":[],"bundles":[],"presets":[],"moduleFlags":{},"packageTags":[],"packages":{}}},"vms":{"grafana":{"host":"mireo","ip":"10.8.0.2","mem":768,"vcpu":2,"autostart":true,"tcpPorts":[22,3000],"udpPorts":[],"volumes":[]}},"deployNodes":{"mireo":{"hostname":"10.8.0.1","sshUser":"root"}},"proxy":{},"plugins":{},"catalog":{}}`)
	m, err := Parse(data)
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if !m.HasHost("mireo") {
		t.Fatal("HasHost mireo")
	}
	if m.HasHost("unknown") {
		t.Fatal("unknown should not have host")
	}
	if !m.HasVM("grafana") {
		t.Fatal("HasVM grafana")
	}
	vms := m.VMsForHost("mireo")
	if len(vms) != 1 {
		t.Fatalf("VMsForHost %d", len(vms))
	}
	if _, ok := vms["grafana"]; !ok {
		t.Fatal("grafana not in VMsForHost")
	}
	empty := m.VMsForHost("x270")
	if len(empty) != 0 {
		t.Fatalf("x270 should have 0 vms")
	}
}

func TestParseInvalid(t *testing.T) {
	if _, err := Parse([]byte(`{invalid`)); err == nil {
		t.Fatal("should fail on invalid json")
	}
}
