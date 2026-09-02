// Package manifest provides typed access to the Nix-generated manifest.json.
package manifest

import (
	"encoding/json"
	"fmt"
)

// Manifest is the Nix-generated declarative inventory.
type Manifest struct {
	Version     int                   `json:"version"`
	Hosts       map[string]Host       `json:"hosts"`
	Vms         map[string]VM         `json:"vms"`
	DeployNodes map[string]DeployNode `json:"deployNodes"`
	Proxy       map[string]any        `json:"proxy"`
	Plugins     map[string][]string   `json:"plugins"`
	Catalog     any                   `json:"catalog"`
}

// Host is a single host entry.
type Host struct {
	Hostname    string              `json:"hostname"`
	Roles       []string            `json:"roles"`
	Bundles     []string            `json:"bundles"`
	Presets     []string            `json:"presets"`
	ModuleFlags map[string]any      `json:"moduleFlags"`
	PackageTags []string            `json:"packageTags"`
	Packages    map[string][]string `json:"packages"`
}

// VM is a single MicroVM entry.
type VM struct {
	Host      string   `json:"host"`
	IP        string   `json:"ip"`
	Mem       *int     `json:"mem"`
	Vcpu      *int     `json:"vcpu"`
	Autostart bool     `json:"autostart"`
	TcpPorts  []int    `json:"tcpPorts"`
	UdpPorts  []int    `json:"udpPorts"`
	Volumes   []Volume `json:"volumes"`
}

// Volume describes a microvm volume.
type Volume struct {
	MountPoint *string `json:"mountPoint"`
	Size       *int    `json:"size"`
}

// DeployNode is a deploy-rs target.
type DeployNode struct {
	Hostname string `json:"hostname"`
	SSHUser  string `json:"sshUser"`
}

// Parse decodes manifest JSON.
func Parse(data []byte) (*Manifest, error) {
	var m Manifest
	if err := json.Unmarshal(data, &m); err != nil {
		return nil, fmt.Errorf("parse manifest: %w", err)
	}
	if m.Hosts == nil {
		m.Hosts = map[string]Host{}
	}
	if m.Vms == nil {
		m.Vms = map[string]VM{}
	}
	return &m, nil
}

// HasHost reports whether host exists.
func (m *Manifest) HasHost(name string) bool {
	_, ok := m.Hosts[name]
	return ok
}

// HasVM reports whether vm exists and belongs to host.
func (m *Manifest) HasVM(name string) bool {
	_, ok := m.Vms[name]
	return ok
}

// VMsForHost returns VMs that belong to host.
func (m *Manifest) VMsForHost(host string) map[string]VM {
	out := map[string]VM{}
	for n, v := range m.Vms {
		if v.Host == host {
			out[n] = v
		}
	}
	return out
}
