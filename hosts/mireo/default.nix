{...}: {
  imports = [
    ./hardware-configuration.nix
    ./host.nix
    ./microvm-wait.nix
    ./optional-data.nix
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
    ./dns-microvm.nix
    ./artifacts-microvm.nix
    ./communication-microvm.nix
    ./remote-microvm.nix
    ./maps-microvm.nix
    ./dash-microvm.nix
    # DEAKTIVIERT (Stub-VMs ohne echte Dienste, fressen nur RAM/Build-Zeit;
    # zum Reaktivieren einkommentieren — IPs/DNS in vm-ips.nix bleiben
    # reserviert, daher kein Adress-Konflikt):
    # ./identity-microvm.nix
    # ./postgres-microvm.nix
    # ./devops-microvm.nix
    # ./management-microvm.nix
    # ./cloud-microvm.nix
    # ./sync-microvm.nix
    # ./media-microvm.nix
    # ./documents-microvm.nix
    ./fxsync-microvm.nix
  ];

  # All microvm tap interfaces join the LAN bridge.
  systemd.network.networks."24-lan-microvm" = {
    matchConfig.Name = "vm-*";
    networkConfig.Bridge = "br0";
  };
}
