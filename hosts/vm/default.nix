{ config, pkgs, ... }:

{
  # imports = [ microvm.nixosModules.microvm ];  # Uncomment when microvm input is added

  networking.hostName = "microvm";

  microvm = {
    hypervisor = "qemu";
    vcpu = 2;
    memMebibytes = 1024;
    interfaces = [
      {
        type = "tap";
        id = "microvm-br0";
      }
    ];
    shares = [
      {
        proto = "9p";
        tag = "nix-store";
        source = "/nix/store";
        mountPoint = "/nix/store";
        readonly = true;
      }
    ];
  };

  services.getty.autologinUser = "root";

  environment.systemPackages = with pkgs; [
    htop
    vim
  ];

  users.users.root = {
    initialPassword = "root";
    openssh.authorizedKeys.keys = [ ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
    };
  };

  system.stateVersion = "24.11";
}
