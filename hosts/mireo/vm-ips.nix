# Single source of truth for static LAN IPs (microVMs on br0).
# Imported by the *-microvm.nix specs AND by the dnsmasq host-record
# generator in data/hosts/mireo/settings.nix — declare an IP once.
{
  grafana = "10.8.0.2";
  network-services = "10.8.0.3";
  monerod = "10.8.0.4";
  yammat = "10.8.0.5";
  cups = "10.8.0.6";
  sshkeys = "10.8.0.7";
  aptcache = "10.8.0.8";
}
