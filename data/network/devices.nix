# Network devices for NetBox/LibreNMS inventory.
# Single source of truth for physical/VM infrastructure.
{lib}: let
  inherit (lib) types mkOption;
in {
  devices = {
    mireo = {
      name = "mireo";
      site = "lan";
      role = "router";
      manufacturer = "Mini-PC";
      model = "4-port NIC";
      interfaces = ["br0" "enp4s0" "enp9s0" "enp3s0f0" "enp3s0f1"];
      addresses = ["10.8.0.1"];
      tags = ["infrastructure" "router" "gateway"];
      snmpCommunity = null;
    };
    p53 = {
      name = "p53";
      site = "lan";
      role = "client";
      manufacturer = "ThinkPad";
      model = "P53";
      interfaces = ["wlan0" "eth0"];
      addresses = [];
      tags = ["workstation"];
      snmpCommunity = null;
    };
  };
}
