# Source — load real project data for the docs framework.
# Reuses the existing framework's data layout, no duplication.
{
  lib,
  pkgs,
}: let
  # Load roles, bundles, presets from data/
  readNixDir = dir:
    builtins.listToAttrs (map (name: {
      name = lib.removeSuffix ".nix" name;
      value = import (dir + "/${name}");
    }) (builtins.attrNames (lib.filterAttrs (n: v: v == "regular" && lib.hasSuffix ".nix" n) (builtins.readDir dir))));

  roles = readNixDir ../../data/roles;
  bundles = readNixDir ../../data/bundles;
  presets = readNixDir ../../data/presets;

  # Hosts: from data/hosts/<host>/settings.nix and microVMs
  # For now, define a minimal host inventory derived from known hosts.
  # This will be expanded to load from data/hosts and hosts/mireo.
  hosts = {
    p53 = {
      id = "p53";
      title = "P53";
      description = "Primary desktop / gaming laptop — ThinkPad P53";
      hardware.info = "Lenovo ThinkPad P53 · i7-9750H";
      roles = import ../../data/hosts/p53/roles.nix;
      services = ["niri" "waybar" "pipewire"];
      microvms = [];
      modules = ["base" "niri" "gaming"];
      tags = ["desktop" "laptop"];
    };
    mireo = {
      id = "mireo";
      title = "Mireo";
      description = "Home server and router — Mini-PC with 4-port NIC, NAT, microVM host";
      hardware.info = "Mini-PC · 4-port NIC · 10.8.0.1 + 192.168.178.25";
      # mireo has no roles.nix (server profile)
      roles = [];
      services = ["dnsmasq" "nixfleet" "nfs" "avahi" "podman"];
      microvms = ["grafana" "network-services" "monerod" "yammat" "cups" "sshkeys"];
      modules = ["base" "microvm" "cups" "dnsmasq" "nat"];
      network = {
        ipv4 = "10.8.0.1/24";
        ipv6 = "fd00:cafe:1::1/64";
        wan = "192.168.178.25/24";
      };
      tags = ["server" "router"];
    };
  };

  microvms = {
    grafana = {
      host = "mireo";
      ip = "10.8.0.2";
      mem = 768;
      vcpu = 2;
      services = ["grafana" "prometheus"];
      description = "Prometheus + Grafana";
    };
    "network-services" = {
      host = "mireo";
      ip = "10.8.0.3";
      mem = 384;
      vcpu = 1;
      services = [];
      description = "Bridge stub";
    };
    monerod = {
      host = "mireo";
      ip = "10.8.0.4";
      mem = 2304;
      vcpu = 2;
      services = ["monerod" "tor"];
      description = "Monero + Tor";
    };
    yammat = {
      host = "mireo";
      ip = "10.8.0.5";
      mem = 2304;
      vcpu = 2;
      services = ["yammat" "postgres"];
      description = "YAMMAT";
    };
    cups = {
      host = "mireo";
      ip = "10.8.0.6";
      mem = 512;
      vcpu = 1;
      services = ["cups" "avahi"];
      description = "CUPS print";
    };
    sshkeys = {
      host = "mireo";
      ip = "10.8.0.7";
      mem = 256;
      vcpu = 1;
      services = ["caddy"];
      description = "SSH keys web";
    };
  };

  modules = {
    base = {description = "Base NixOS config (SSH, locale, firewall)";};
    niri = {description = "Niri compositor + greetd";};
    gaming = {description = "Gaming stack (Steam, GameMode)";};
    microvm = {description = "MicroVM host (QEMU, tap, br0)";};
    dnsmasq = {description = "DHCP/DNS/RA for LAN";};
    nixfleet = {description = "NixFleet control plane (API+agent)";};
    cups = {description = "CUPS print server";};
  };
in {
  inherit hosts roles bundles presets microvms modules;
}
