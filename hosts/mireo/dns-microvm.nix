# DNS microVM: AdGuard Home
# DNS server on the LAN gateway.
{...}: {
  imports = [
    (import ./mk-microvm.nix {
      name = "dns";
      ip = (import ./vm-ips.nix).dns;
      mem = 256;
      vcpu = 1;
      tcpPorts = [22 53];
      udpPorts = [53];
      config = {
        imports = [(import ../../modules/nixos/dns-adguard.nix)];
        lucy.services.dns = {
          enable = true;
          domain = "home.arpa";
          upstream = ["1.1.1.1" "9.9.9.9"];
          blocklists = [];
        };
      };
    })
  ];
}
