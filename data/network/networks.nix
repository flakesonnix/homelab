# Network networks definition.
{lib}: let
  inherit (lib) types mkOption;
in {
  networks = {
    lan = {
      name = "lan";
      subnet = "10.8.0.0/24";
      gateway = "10.8.0.1";
      dns = "10.8.0.1";
      domain = "home.arpa";
    };
    vpn = {
      name = "vpn";
      subnet = "10.66.0.0/30";
      gateway = "10.66.0.1";
      dns = null;
    };
  };
}
