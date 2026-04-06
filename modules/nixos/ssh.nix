{ config, ... }:

{
  services.openssh.enable = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 24800 ];
  };
}
