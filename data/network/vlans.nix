# VLAN definitions for the homelab network.
{lib}: let
  inherit (lib) types mkOption;
in {
  vlans = {
    management = {
      id = 10;
      name = "management";
      subnet = "10.8.10.0/24";
      gateway = "10.8.10.1";
    };
    storage = {
      id = 20;
      name = "storage";
      subnet = "10.8.20.0/24";
      gateway = "10.8.20.1";
    };
    services = {
      id = 30;
      name = "services";
      subnet = "10.8.30.0/24";
      gateway = "10.8.30.1";
    };
  };
}
