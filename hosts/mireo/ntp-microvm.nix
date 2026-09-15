# NTP server for the LAN (microVM on br0, chrony).
# Syncs upstream via WAN NAT, serves LAN + ULA. Advertised to DHCP
# clients via option:ntp-server (dnsmasq). No volume needed (drift
# re-learns after reboot); no TLS/state inside the VM.
{
  imports = [
    (import ./mk-microvm.nix {
      name = "ntp";
      ip = (import ./vm-ips.nix).ntp;
      mem = 256;
      vcpu = 1;
      tcpPorts = [22];
      udpPorts = [123];
      config = {
        services.chrony = {
          enable = true;
          extraConfig = ''
            allow 127.0.0.1
            allow 10.8.0.0/24
            allow fd00:cafe:1::/64
          '';
        };
      };
    })
  ];
}
