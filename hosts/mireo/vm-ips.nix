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
  uptime-kuma = "10.8.0.9";
  jellyfin = "10.8.0.10";
  ntp = "10.8.0.11";
  lldap = "10.8.0.12";
  pocket-id = "10.8.0.13";
  identity = "10.8.0.29";
  postgres = "10.8.0.28";
  dns = "10.8.0.30";
  nextcloud = "10.8.0.14";
  netbox = "10.8.0.15";
  librenms = "10.8.0.16";
  woodpecker = "10.8.0.17";
  hydra = "10.8.0.18";
  registry = "10.8.0.19";
  attic = "10.8.0.20";
  immich = "10.8.0.21";
  paperless = "10.8.0.22";
  matrix = "10.8.0.23";
  ntfy = "10.8.0.24";
  rustdesk = "10.8.0.25";
  syncthing = "10.8.0.26";
  osm = "10.8.0.27";
  kodi = "10.8.0.31";
}
