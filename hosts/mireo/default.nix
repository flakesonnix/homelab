{...}: {
  imports = [
    ./hardware-configuration.nix
    ./host.nix
    ../../modules/nixos/lucy-services.nix
    ./cups-microvm.nix
    ./monerod-microvm.nix
    ./network-services-microvm.nix
    ./sshkeys-microvm.nix
    ./yammat-microvm.nix
    ./uptime-kuma-microvm.nix
    ./jellyfin-microvm.nix
    ./ntp-microvm.nix
    ./lldap-microvm.nix
    ./pocket-id-microvm.nix
    ./identity-microvm.nix
    ./postgres-microvm.nix
    ./dns-microvm.nix
    ./devops-microvm.nix
    ./artifacts-microvm.nix
    ./management-microvm.nix
    ./cloud-microvm.nix
    ./sync-microvm.nix
    ./media-microvm.nix
    ./documents-microvm.nix
    ./communication-microvm.nix
    ./remote-microvm.nix
    ./maps-microvm.nix
    ./kodi-microvm.nix
    ./dash-microvm.nix
  ];

  # All microvm tap interfaces join the LAN bridge.
  systemd.network.networks."24-lan-microvm" = {
    matchConfig.Name = "vm-*";
    networkConfig.Bridge = "br0";
  };
}
