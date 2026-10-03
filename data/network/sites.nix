# Network sites for the homelab.
{lib}: let
  inherit (lib) types mkOption;
in {
  sites = {
    lan = {
      name = "lan";
      vlan = 1;
      gateway = "10.8.0.1";
      prefix = 24;
      dns = true;
      domain = "home.arpa";
    };
    wan = {
      name = "wan";
      vlan = 0;
      gateway = "192.168.178.1";
      prefix = 24;
      dns = false;
    };
    vpn = {
      name = "vpn";
      vlan = 0;
      gateway = "10.66.0.1";
      prefix = 30;
      dns = false;
    };
  };
}
