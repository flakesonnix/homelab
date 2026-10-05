# Common NixOS module for all mireo microvms.
# Usage: imports = [ (import ./microvm-base.nix { name = "cups"; ip = "10.8.0.6"; interfaceId = "vm-cups"; }) ];
# name selects /var/lib/microvms/<name>/ on the host (stable SSH host keys;
# provision once per new VM: ssh-keygen -f .../ssh-host-keys/ssh_host_ed25519_key).
{
  ip,
  interfaceId,
  extraDns ? [],
  name,
}: {lib, ...}: let
  keys = import ../../ssh-public-keys.nix {inherit lib;};
  hexDigit = d: builtins.elemAt ["0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "a" "b" "c" "d" "e" "f"] d;
  mac = let
    lastOctet = lib.toInt (lib.last (lib.splitString "." ip));
  in "02:00:00:10:08:${hexDigit (builtins.div lastOctet 16)}${hexDigit (lib.mod lastOctet 16)}";
in {
  system.stateVersion = "25.11";

  # keys file holds one key per line (all owner keys); split into list
  # entries (tolerates trailing newline).
  users.users.root.openssh.authorizedKeys.keys = builtins.filter (k: k != "") (lib.splitString "\n" keys.lucy.servers);
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };

  microvm.hypervisor = "qemu";
  microvm.interfaces = [
    {
      type = "tap";
      id = interfaceId;
      inherit mac;
    }
  ];
  microvm.shares = [
    {
      proto = "virtiofs";
      tag = "ro-store";
      source = "/nix/store";
      mountPoint = "/nix/.ro-store";
    }
    # Stable host keys (host-provisioned, survive rebuilds/reboots —
    # without this every VM rebuild rotates keys and breaks automation
    # SSH like epg-refresh). Replaces the ephemeral default hostKeys.
    {
      proto = "virtiofs";
      tag = "ssh-host-keys";
      source = "/var/lib/microvms/${name}/ssh-host-keys";
      mountPoint = "/run/vm-host-keys";
    }
  ];

  services.openssh.hostKeys = [
    {
      path = "/run/vm-host-keys/ssh_host_ed25519_key";
      type = "ed25519";
    }
  ];

  systemd.network.enable = true;
  systemd.network.networks."20-lan" = {
    matchConfig.Type = "ether";
    # IPv4 via DHCP reservation: dnsmasq pins this MAC to `ip`
    # (dhcp-host generated from the same vm-ips.nix, so the address
    # stays centrally declared). Gateway + DNS server arrive via DHCP
    # options (router 10.8.0.1, DNS 10.8.0.30 = AdGuard filter first,
    # host 10.8.0.1 fallback);
    # extraDns merges on top.
    # Static ULA mirrors the IPv4 last octet (10.8.0.N -> fd00:cafe:1::N),
    # same single source as the MAC above. On-link LAN needs no v6 route;
    # DNS serves the matching AAAA (dnsmasq host-record on the host).
    address = ["fd00:cafe:1::${lib.last (lib.splitString "." ip)}/64"];
    networkConfig = {
      DNS = ["10.8.0.30" "10.8.0.1"] ++ extraDns;
      DHCP = "ipv4";
      IPv6AcceptRA = false;
    };
  };
}
