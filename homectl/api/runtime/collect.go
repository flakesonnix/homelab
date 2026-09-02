// Package runtime collects local runtime state from the host.
// All collectors use fixed commands and bounded reads; no arbitrary execution.
package runtime

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"strings"
	"syscall"
)

// SystemInfo holds basic host identity.
type SystemInfo struct {
	Hostname string `json:"hostname"`
	Kernel   string `json:"kernel"`
	OS       string `json:"os"`
	OSPretty string `json:"osPretty"`
	UptimeS  uint64 `json:"uptimeS"`
}

// Resources holds CPU/memory/storage.
type Resources struct {
	CPU     CPUInfo      `json:"cpu"`
	Memory  MemoryInfo   `json:"memory"`
	Storage []Filesystem `json:"storage"`
	Load    LoadAvg      `json:"load"`
}

type CPUInfo struct {
	Logical int     `json:"logical"`
	UsagePct *float64 `json:"usagePct,omitempty"`
}

type LoadAvg struct {
	Load1  float64 `json:"load1"`
	Load5  float64 `json:"load5"`
	Load15 float64 `json:"load15"`
}

type MemoryInfo struct {
	Total     uint64  `json:"total"`
	Available uint64  `json:"available"`
	Used      uint64  `json:"used"`
	Free      uint64  `json:"free"`
	UsedPct   float64 `json:"usedPct"`
}

type Filesystem struct {
	Filesystem string  `json:"filesystem"`
	Mount      string  `json:"mount"`
	Type       string  `json:"type"`
	Total      uint64  `json:"total"`
	Used       uint64  `json:"used"`
	Available  uint64  `json:"available"`
	UsedPct    float64 `json:"usedPct"`
}

// Network holds interfaces and routes.
type Network struct {
	Interfaces []Interface `json:"interfaces"`
	Routes     []Route     `json:"routes"`
}

type Interface struct {
	Name  string   `json:"name"`
	State string   `json:"state"`
	MAC   string   `json:"mac"`
	MTU   int      `json:"mtu,omitempty"`
	IPv4  []string `json:"ipv4"`
	IPv6  []string `json:"ipv6"`
	Rx    uint64   `json:"rx"`
	Tx    uint64   `json:"tx"`
}

type Route struct {
	Destination string `json:"destination"`
	Gateway     string `json:"gateway,omitempty"`
	Interface   string `json:"interface,omitempty"`
}

// FailedUnit holds systemd failed unit info.
type FailedUnit struct {
	Unit        string `json:"unit"`
	Load        string `json:"load"`
	Active      string `json:"active"`
	Sub         string `json:"sub"`
	Description string `json:"description"`
}

// --- System ---

func CollectSystem() (SystemInfo, error) {
	var s SystemInfo
	// hostname
	if h, err := os.Hostname(); err == nil {
		s.Hostname = h
	}
	// kernel via uname -r (fixed)
	if out, err := exec.Command("uname", "-r").Output(); err == nil {
		s.Kernel = strings.TrimSpace(string(out))
	}
	// os via /etc/os-release
	if data, err := os.ReadFile("/etc/os-release"); err == nil {
		s.OS, s.OSPretty = parseOSRelease(string(data))
	}
	// uptime via /proc/uptime
	if data, err := os.ReadFile("/proc/uptime"); err == nil {
		if fields := strings.Fields(string(data)); len(fields) > 0 {
			if f, err := strconv.ParseFloat(fields[0], 64); err == nil {
				s.UptimeS = uint64(f)
			}
		}
	}
	return s, nil
}

func parseOSRelease(data string) (id, pretty string) {
	sc := bufio.NewScanner(strings.NewReader(data))
	for sc.Scan() {
		line := sc.Text()
		if strings.HasPrefix(line, "ID=") {
			id = strings.Trim(strings.TrimPrefix(line, "ID="), `"`)
		}
		if strings.HasPrefix(line, "PRETTY_NAME=") {
			pretty = strings.Trim(strings.TrimPrefix(line, "PRETTY_NAME="), `"`)
		}
	}
	if pretty == "" {
		pretty = id
	}
	return
}

// --- Resources ---

func CollectResources() (Resources, error) {
	var r Resources
	r.CPU.Logical = runtime.NumCPU()
	// loadavg
	if data, err := os.ReadFile("/proc/loadavg"); err == nil {
		r.Load = parseLoadAvg(string(data))
	}
	// memory
	if data, err := os.ReadFile("/proc/meminfo"); err == nil {
		if mem, err := parseMeminfo(string(data)); err == nil {
			r.Memory = mem
		}
	}
	// cpu usage approx via /proc/stat (single snapshot, not accurate but bounded)
	if usage, err := parseCPUUsage(); err == nil {
		r.CPU.UsagePct = usage
	}
	// storage via syscall.Statfs for key mounts
	r.Storage = collectFilesystems()
	return r, nil
}

func parseLoadAvg(s string) LoadAvg {
	f := strings.Fields(s)
	var l LoadAvg
	if len(f) >= 3 {
		l.Load1, _ = strconv.ParseFloat(f[0], 64)
		l.Load5, _ = strconv.ParseFloat(f[1], 64)
		l.Load15, _ = strconv.ParseFloat(f[2], 64)
	}
	return l
}

func parseMeminfo(s string) (MemoryInfo, error) {
	m := map[string]uint64{}
	sc := bufio.NewScanner(strings.NewReader(s))
	for sc.Scan() {
		line := sc.Text()
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}
		key := strings.TrimSuffix(fields[0], ":")
		val, err := strconv.ParseUint(fields[1], 10, 64)
		if err != nil {
			continue
		}
		// values are in kB
		m[key] = val * 1024
	}
	total, ok := m["MemTotal"]
	if !ok {
		return MemoryInfo{}, fmt.Errorf("MemTotal not found")
	}
	available := m["MemAvailable"]
	if available == 0 {
		available = m["MemFree"] + m["Buffers"] + m["Cached"]
	}
	used := total - available
	if used > total {
		used = total
	}
	var pct float64
	if total > 0 {
		pct = float64(used) / float64(total) * 100
	}
	return MemoryInfo{
		Total:     total,
		Available: available,
		Used:      used,
		Free:      m["MemFree"],
		UsedPct:   pct,
	}, nil
}

func parseCPUUsage() (*float64, error) {
	data, err := os.ReadFile("/proc/stat")
	if err != nil {
		return nil, err
	}
	sc := bufio.NewScanner(bytes.NewReader(data))
	for sc.Scan() {
		line := sc.Text()
		if !strings.HasPrefix(line, "cpu ") {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) < 8 {
			return nil, fmt.Errorf("unexpected cpu line")
		}
		var total, idle uint64
		for i, v := range fields[1:] {
			n, _ := strconv.ParseUint(v, 10, 64)
			total += n
			if i == 3 { // idle
				idle = n
			}
		}
		if total == 0 {
			return nil, nil
		}
		usedPct := float64(total-idle) / float64(total) * 100
		return &usedPct, nil
	}
	return nil, nil
}

func collectFilesystems() []Filesystem {
	// Key mount points to report; filter to real filesystems.
	mounts := []string{"/", "/data", "/nix/store", "/boot"}
	var out []Filesystem
	for _, mp := range mounts {
		var stat syscall.Statfs_t
		if err := syscall.Statfs(mp, &stat); err != nil {
			continue
		}
		total := stat.Blocks * uint64(stat.Bsize)
		free := stat.Bfree * uint64(stat.Bsize)
		avail := stat.Bavail * uint64(stat.Bsize)
		used := total - free
		var pct float64
		if total > 0 {
			pct = float64(used) / float64(total) * 100
		}
		// filesystem and type via /proc/mounts
		fs, fstype := fsForMount(mp)
		out = append(out, Filesystem{
			Filesystem: fs,
			Mount:      mp,
			Type:       fstype,
			Total:      total,
			Used:       used,
			Available:  avail,
			UsedPct:    pct,
		})
	}
	return out
}

func fsForMount(mount string) (fs, fstype string) {
	data, err := os.ReadFile("/proc/mounts")
	if err != nil {
		return mount, "unknown"
	}
	sc := bufio.NewScanner(strings.NewReader(string(data)))
	for sc.Scan() {
		fields := strings.Fields(sc.Text())
		if len(fields) < 3 {
			continue
		}
		if fields[1] == mount {
			return fields[0], fields[2]
		}
	}
	return mount, "unknown"
}

// --- Network ---

func CollectNetwork() (Network, error) {
	var n Network
	// interfaces via ip -j link and ip -j addr (fixed commands)
	links, err := ipJSON("link")
	if err == nil {
		addrs, _ := ipJSON("addr")
		n.Interfaces = mergeLinksAddrs(links, addrs)
	} else {
		// fallback to /proc/net/dev
		n.Interfaces = fallbackInterfaces()
	}
	// routes via ip -j route
	if routes, err := ipJSON("route"); err == nil {
		n.Routes = parseRoutes(routes)
	}
	return n, nil
}

func ipJSON(sub string) ([]map[string]any, error) {
	var args []string
	switch sub {
	case "link":
		args = []string{"-j", "link"}
	case "addr":
		args = []string{"-j", "addr"}
	case "route":
		args = []string{"-j", "route"}
	default:
		return nil, fmt.Errorf("unknown ip subcommand %s", sub)
	}
	out, err := exec.Command("ip", args...).Output()
	if err != nil {
		return nil, err
	}
	var data []map[string]any
	if err := json.Unmarshal(out, &data); err != nil {
		return nil, err
	}
	return data, nil
}

func mergeLinksAddrs(links, addrs []map[string]any) []Interface {
	byIndex := map[int]Interface{}
	for _, l := range links {
		idxF, _ := l["ifindex"].(float64)
		idx := int(idxF)
		name, _ := l["ifname"].(string)
		state, _ := l["operstate"].(string)
		mac, _ := l["address"].(string)
		mtuF, _ := l["mtu"].(float64)
		ifc := Interface{
			Name:  name,
			State: strings.ToLower(state),
			MAC:   mac,
			MTU:   int(mtuF),
		}
		// stats
		if stats, ok := l["stats64"].(map[string]any); ok {
			if rx, ok := stats["rx"].(map[string]any); ok {
				if v, ok := rx["bytes"].(float64); ok {
					ifc.Rx = uint64(v)
				}
			}
			if tx, ok := stats["tx"].(map[string]any); ok {
				if v, ok := tx["bytes"].(float64); ok {
					ifc.Tx = uint64(v)
				}
			}
		}
		byIndex[idx] = ifc
	}
	for _, a := range addrs {
		idxF, _ := a["ifindex"].(float64)
		idx := int(idxF)
		ifc := byIndex[idx]
		if addrInfos, ok := a["addr_info"].([]any); ok {
			for _, ai := range addrInfos {
				if m, ok := ai.(map[string]any); ok {
					family, _ := m["family"].(string)
					local, _ := m["local"].(string)
					if local == "" {
						continue
					}
					// validate IP
					if ip := net.ParseIP(local); ip != nil {
						if family == "inet" {
							ifc.IPv4 = append(ifc.IPv4, local)
						} else if family == "inet6" {
							ifc.IPv6 = append(ifc.IPv6, local)
						}
					}
				}
			}
		}
		byIndex[idx] = ifc
	}
	var out []Interface
	for _, v := range byIndex {
		// filter lo unless it has addrs?
		out = append(out, v)
	}
	return out
}

func fallbackInterfaces() []Interface {
	data, err := os.ReadFile("/proc/net/dev")
	if err != nil {
		return nil
	}
	var out []Interface
	sc := bufio.NewScanner(strings.NewReader(string(data)))
	for sc.Scan() {
		line := sc.Text()
		if strings.Contains(line, "|") || strings.Contains(line, "face") {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}
		name := strings.TrimSuffix(fields[0], ":")
		out = append(out, Interface{Name: name, State: "unknown"})
	}
	return out
}

func parseRoutes(data []map[string]any) []Route {
	var out []Route
	for _, r := range data {
		dst, _ := r["dst"].(string)
		if dst == "" {
			dst = "default"
		}
		gw, _ := r["gateway"].(string)
		dev, _ := r["dev"].(string)
		out = append(out, Route{Destination: dst, Gateway: gw, Interface: dev})
	}
	return out
}

// --- Systemd ---

func CollectFailedUnits() ([]FailedUnit, error) {
	// systemctl --failed --no-legend --plain (fixed, bounded)
	out, err := exec.Command("systemctl", "--failed", "--no-legend", "--plain").Output()
	if err != nil {
		// systemctl returns 0 even when failed units exist, but may fail if systemd not running
		// check if output is empty and err is ExitError with code 0? For now return empty.
		if _, ok := err.(*exec.ExitError); ok {
			// still try to parse output
		} else {
			return nil, err
		}
	}
	return parseSystemctlFailed(string(out)), nil
}

func parseSystemctlFailed(s string) []FailedUnit {
	var out []FailedUnit
	sc := bufio.NewScanner(strings.NewReader(s))
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" {
			continue
		}
		// format: UNIT LOAD ACTIVE SUB DESCRIPTION
		fields := strings.Fields(line)
		if len(fields) < 4 {
			continue
		}
		unit := fields[0]
		load := fields[1]
		active := fields[2]
		sub := fields[3]
		desc := ""
		if len(fields) > 4 {
			desc = strings.Join(fields[4:], " ")
		}
		out = append(out, FailedUnit{
			Unit:        unit,
			Load:        load,
			Active:      active,
			Sub:         sub,
			Description: desc,
		})
	}
	return out
}

// --- VM runtime ---

type VMRuntime struct {
	State string  `json:"state"` // running, stopped, unknown
	UptimeS *uint64 `json:"uptimeS,omitempty"`
}

// CollectVMState checks systemctl is-active for microvm@<name>.
func CollectVMState(vmName string) (VMRuntime, error) {
	unit := fmt.Sprintf("microvm@%s", vmName)
	// Validate vmName: only allow [a-z0-9-]
	if !isValidVMName(vmName) {
		return VMRuntime{State: "unknown"}, fmt.Errorf("invalid vm name")
	}
	out, err := exec.Command("systemctl", "is-active", unit).Output()
	state := strings.TrimSpace(string(out))
	if err != nil {
		// is-active returns non-zero when not active, but output still contains state
		if state == "" {
			state = "unknown"
		}
		// map to known states
		if state == "inactive" || state == "failed" {
			state = "stopped"
		} else if state != "active" && state != "activating" {
			state = "stopped"
		}
	} else {
		if state == "active" {
			state = "running"
		}
	}
	return VMRuntime{State: state}, nil
}

func isValidVMName(s string) bool {
	if s == "" || len(s) > 64 {
		return false
	}
	for _, c := range s {
		if (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-' {
			continue
		}
		return false
	}
	return true
}
