package runtime

import (
	"strings"
	"testing"
)

func TestParseMeminfo(t *testing.T) {
	sample := `MemTotal:       16384 kB
MemFree:         1024 kB
MemAvailable:    8192 kB
Buffers:          512 kB
Cached:          1024 kB
`
	mem, err := parseMeminfo(sample)
	if err != nil {
		t.Fatalf("parseMeminfo: %v", err)
	}
	if mem.Total != 16384*1024 {
		t.Fatalf("total %d", mem.Total)
	}
	if mem.Available != 8192*1024 {
		t.Fatalf("available %d", mem.Available)
	}
	if mem.Used != 8192*1024 {
		t.Fatalf("used %d", mem.Used)
	}
	if mem.UsedPct < 49 || mem.UsedPct > 51 {
		t.Fatalf("pct %f", mem.UsedPct)
	}
}

func TestParseMeminfoFallback(t *testing.T) {
	// No MemAvailable, fallback to Free+Buffers+Cached
	sample := `MemTotal:       16384 kB
MemFree:         2048 kB
Buffers:          512 kB
Cached:          1024 kB
`
	mem, err := parseMeminfo(sample)
	if err != nil {
		t.Fatalf("parseMeminfo: %v", err)
	}
	// Available = 2048+512+1024 = 3584 kB
	if mem.Available != 3584*1024 {
		t.Fatalf("available fallback %d", mem.Available)
	}
}

func TestParseLoadAvg(t *testing.T) {
	l := parseLoadAvg("0.10 0.20 0.30 1/100 1234")
	if l.Load1 != 0.10 || l.Load5 != 0.20 || l.Load15 != 0.30 {
		t.Fatalf("load %+v", l)
	}
}

func TestParseOSRelease(t *testing.T) {
	data := `ID=nixos
PRETTY_NAME="NixOS 25.11"
`
	id, pretty := parseOSRelease(data)
	if id != "nixos" {
		t.Fatalf("id %q", id)
	}
	if pretty != "NixOS 25.11" {
		t.Fatalf("pretty %q", pretty)
	}
}

func TestParseSystemctlFailed(t *testing.T) {
	sample := `cups.service                loaded failed failed  CUPS Scheduler
monerod.service             loaded failed failed  Monero
`
	units := parseSystemctlFailed(sample)
	if len(units) != 2 {
		t.Fatalf("len %d", len(units))
	}
	if units[0].Unit != "cups.service" || units[0].Active != "failed" {
		t.Fatalf("unit %+v", units[0])
	}
	if units[1].Description != "Monero" {
		t.Fatalf("desc %q", units[1].Description)
	}
	empty := parseSystemctlFailed("")
	if len(empty) != 0 {
		t.Fatalf("empty should be 0")
	}
}

func TestIsValidVMName(t *testing.T) {
	valid := []string{"grafana", "network-services", "aptcache", "yammat", "cups", "sshkeys", "monerod"}
	for _, v := range valid {
		if !isValidVMName(v) {
			t.Fatalf("valid %q rejected", v)
		}
	}
	invalid := []string{"", "Grafana", "grafana;", "microvm@grafana", "../etc/passwd", strings.Repeat("a", 65)}
	for _, v := range invalid {
		if isValidVMName(v) {
			t.Fatalf("invalid %q accepted", v)
		}
	}
}

func TestMergeLinksAddrs(t *testing.T) {
	links := []map[string]any{
		{"ifindex": float64(1), "ifname": "lo", "operstate": "UNKNOWN", "address": "00:00:00:00:00:00", "mtu": float64(65536), "stats64": map[string]any{"rx": map[string]any{"bytes": float64(100)}, "tx": map[string]any{"bytes": float64(200)}}},
		{"ifindex": float64(2), "ifname": "br0", "operstate": "UP", "address": "aa:bb:cc:dd:ee:ff", "mtu": float64(1500), "stats64": map[string]any{"rx": map[string]any{"bytes": float64(1000)}, "tx": map[string]any{"bytes": float64(2000)}}},
	}
	addrs := []map[string]any{
		{"ifindex": float64(2), "addr_info": []any{map[string]any{"family": "inet", "local": "10.8.0.1"}, map[string]any{"family": "inet6", "local": "fd00:cafe:1::1"}}},
	}
	ifaces := mergeLinksAddrs(links, addrs)
	if len(ifaces) != 2 {
		t.Fatalf("len %d", len(ifaces))
	}
	var br0 *Interface
	for i := range ifaces {
		if ifaces[i].Name == "br0" {
			br0 = &ifaces[i]
			break
		}
	}
	if br0 == nil {
		t.Fatal("br0 not found")
	}
	if len(br0.IPv4) != 1 || br0.IPv4[0] != "10.8.0.1" {
		t.Fatalf("ipv4 %+v", br0.IPv4)
	}
	if len(br0.IPv6) != 1 || br0.IPv6[0] != "fd00:cafe:1::1" {
		t.Fatalf("ipv6 %+v", br0.IPv6)
	}
	if br0.Rx != 1000 || br0.Tx != 2000 {
		t.Fatalf("rx/tx %d/%d", br0.Rx, br0.Tx)
	}
}
