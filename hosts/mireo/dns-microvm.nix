# DNS filtering microVM: AdGuard Home (blocklists only).
# dnsmasq on the host stays authoritative for LAN DHCP+DNS; AdGuard is a
# filtering frontend (DHCP advertises .30 first, host .1 as fallback).
# /etc/hosts records (A+AAAA+aliases, served via hostsfile_enabled) are
# generated from hosts/mireo/vm-ips.nix (single source stays).
{lib, ...}: let
  vmIps = import ./vm-ips.nix;
  lastOctetOf = ip: lib.last (lib.splitString "." ip);
  # CNAME-equivalents as extra hosts names (AdGuard rewrites serve A, so
  # aliases ride on the target's lines — same answers, no CNAME needed).
  aliases = {
    prometheus = "grafana";
    media = "jellyfin";
    status = "uptime-kuma";
    adguard = "dns";
  };
  aliasNamesFor = host:
    lib.concatLists (lib.mapAttrsToList (alias: target:
      lib.optionals (target == host) ["${alias}.home.arpa" alias])
    aliases);
in {
  imports = [
    (import ./mk-microvm.nix {
      name = "dns";
      ip = vmIps.dns;
      mem = 384;
      vcpu = 1;
      tcpPorts = [22 53 3000];
      udpPorts = [53];
      volumes = [
        {
          image = "adguard-data.img";
          mountPoint = "/var/lib/AdGuardHome";
          size = 512;
          user = "adguardhome";
          group = "adguardhome";
        }
      ];
      config = {
        imports = [(import ../../modules/nixos/dns-adguard.nix)];
        lucy.services.dns = {
          enable = true;
          domain = "home.arpa";
          upstream = ["1.1.1.1" "9.9.9.9"];
          blocklists = [];
        };
        users.users.adguardhome = {
          isSystemUser = true;
          group = "adguardhome";
        };
        users.groups.adguardhome = {};
        # Upstream unit uses DynamicUser+StateDirectory — collides with the
        # mounted volume (exit 238, same trap as uptime-kuma/lldap/dash).
        systemd.services.adguardhome.serviceConfig = {
          DynamicUser = lib.mkForce false;
          User = "adguardhome";
          Group = "adguardhome";
        };
        # Static records for every LAN host (A+AAAA+aliases). Served by
        # AdGuard via hostsfile_enabled; doubles as the guest's own hosts.
        # networking.hosts shape: { "IP" = [ names ]; }.
        networking.hosts = let
          base = vmIps // {mireo = "10.8.0.1";};
          namesFor = name: (["${name}.home.arpa" name] ++ aliasNamesFor name);
          v4 = lib.mapAttrs' (name: ip: lib.nameValuePair ip (namesFor name)) base;
          v6 = lib.mapAttrs' (name: ip: lib.nameValuePair "fd00:cafe:1::${lastOctetOf ip}" (namesFor name)) base;
        in
          v4 // v6;
        # Static IPv4 (DHCP would be circular for DNS infra; dnsmasq hands
        # out .30 statically via reservation anyway).
        # ULA mirrors microvm-base (10.8.0.N -> fd00:cafe:1::N); the address
        # list REPLACES base's, so both families are listed explicitly.
        systemd.network.networks."20-lan" = {
          address = ["10.8.0.30/24" "fd00:cafe:1::30/64"];
          routes = [{Gateway = "10.8.0.1";}];
          networkConfig = {
            DHCP = lib.mkForce false;
            DNS = ["127.0.0.1"];
          };
        };
        # AdGuard binds 0.0.0.0:53 — systemd-resolved's stub listeners
        # (127.0.0.53:53, 127.0.0.54:53) would steal the bind (EADDRINUSE)
        # and kill LAN DNS. The guest resolves via 127.0.0.1 = AdGuard
        # itself (networkd DNS above), so resolved is expendable here.
        services.resolved.enable = lib.mkForce false;
        services.adguardhome = {
          enable = true;
          settings = {
            dns = {
              bind_hosts = ["0.0.0.0" "::"];
              port = 53;
              bootstrap_dns = ["1.1.1.1" "9.9.9.9"];
              # Public upstreams directly: host dnsmasq REFUSES queries with
              # the DO bit (no DNSSEC in its build) and AdGuard always sets
              # it upstream — .1 as upstream broke all external resolution
              # (seen 2026-10-05, REFUSED). LAN names never leave anyway
              # (local_domain_name + hostsfile answer them locally).
              upstream_dns = ["1.1.1.1" "9.9.9.9" "2606:4700:4700::1111" "2620:fe::9"];
              local_domain_name = "home.arpa";
              hostsfile_enabled = true;
              # Cap query-log retention: default 90d filled 276M/512M volume
              # (seen 2026-10-05, mostly NTP pool noise). 7d is plenty.
              querylog = {
                interval = "168h";
              };
              protection_enabled = true;
              filtering_enabled = true;
              filters = [
                {
                  enabled = true;
                  url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt";
                  name = "AdGuard DNS filter";
                  id = 1;
                }
                {
                  enabled = true;
                  url = "https://adaway.org/hosts.txt";
                  name = "AdAway Default Blocklist";
                  id = 2;
                }
              ];
            };
            # NOTE: no dhcp section on purpose — host dnsmasq owns DHCP.
          };
        };
      };
    })
  ];
}
