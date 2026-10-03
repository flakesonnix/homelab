# DNS + DHCP microVM: AdGuard Home (replaces dnsmasq on mireo).
# Single source of truth stays hosts/mireo/vm-ips.nix: static DHCP leases
# (MAC formula identical to microvm-base.nix) and /etc/hosts records
# (A+AAAA+aliases, served via hostsfile_enabled) are generated from it.
# Trade-offs vs dnsmasq (accepted): no PXE/TFTP, no FritzBox-PD RAs
# (ULA RA/DHCPv6 only), GUA-SLAAC degrades to FritzBox scope.
# Safety: static IPv4 for this VM (no DHCP chicken-and-egg — it IS the
# DHCP server), rollback = redeploy previous generation (dnsmasq back).
{lib, ...}: let
  vmIps = import ./vm-ips.nix;
  # Must match microvm-base.nix + the old dnsmasq dhcp-host generator.
  hexDigit = d: builtins.elemAt ["0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "a" "b" "c" "d" "e" "f"] d;
  macForIp = ip: let
    lastOctet = lib.toInt (lib.last (lib.splitString "." ip));
  in "02:00:00:10:08:${hexDigit (builtins.div lastOctet 16)}${hexDigit (lib.mod lastOctet 16)}";
  lastOctetOf = ip: lib.last (lib.splitString "." ip);
  # CNAME-equivalents as extra hosts names (AdGuard rewrites serve A, so
  # aliases ride on the target's lines — same answers, no CNAME needed).
  aliases = {
    prometheus = "grafana";
    media = "jellyfin";
    status = "uptime-kuma";
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
      udpPorts = [53 67 547];
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
        # Static IPv4: this VM IS the DHCP server (no chicken-and-egg).
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
        services.adguardhome = {
          enable = true;
          settings = {
            dns = {
              bind_hosts = ["0.0.0.0" "::"];
              port = 53;
              bootstrap_dns = ["1.1.1.1" "9.9.9.9"];
              upstream_dns = ["1.1.1.1" "9.9.9.9" "2606:4700:4700::1111" "2620:fe::9"];
              local_domain_name = "home.arpa";
              hostsfile_enabled = true;
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
            dhcp = {
              enabled = true;
              interface_name = "";
              local_domain_name = "home.arpa";
              dhcpv4 = {
                gateway_ip = "10.8.0.1";
                subnet_mask = "255.255.255.0";
                range_start = "10.8.0.100";
                range_end = "10.8.0.199";
                lease_duration = 86400;
              };
              dhcpv6 = {
                enabled = true;
                range_start = "fd00:cafe:1::100";
                range_end = "fd00:cafe:1::1ff";
                lease_duration = 86400;
              };
              static_leases =
                lib.mapAttrsToList (name: ip: {
                  mac = macForIp ip;
                  ip = ip;
                  hostname = name;
                })
                vmIps;
            };
          };
        };
      };
    })
  ];
}
