{
  pkgs,
  lib,
  self,
}:
let
  cfg = self.nixosConfigurations.p53.config;
  package = cfg.virtualisation.waydroid.package;
  init = cfg.systemd.services.waydroid-gapps-init;
  network = "${package}/lib/waydroid/data/scripts/waydroid-net.sh";
in
assert lib.assertMsg (
  cfg.virtualisation.waydroid.enable
  && package.drvPath == self.nixosConfigurations.p53.pkgs.waydroid-nftables.drvPath
  &&
    cfg.systemd.services.waydroid-container.serviceConfig.ExecStart
    == "${package}/bin/waydroid container start"
  && init.serviceConfig.ExecStart == "${package}/bin/waydroid init -s GAPPS"
  && lib.any (p: p.drvPath == package.drvPath) init.path
  && lib.all (
    p: (p.pname or "") != "waydroid" || p.drvPath == package.drvPath
  ) cfg.environment.systemPackages
) "Waydroid CLI, container and GApps init must use the nftables package";
pkgs.testers.runNixOSTest {
  name = "waydroid-network";

  nodes.machine = { lib, ... }: {
    imports = [ ../modules/nixos/waydroid.nix ];
    lucy.waydroid = {
      enable = true;
      gapps = false;
    };
    # Exercise networking without downloading or booting Android images.
    systemd.services.waydroid-container.wantedBy = lib.mkForce [ ];
    environment.systemPackages = [
      pkgs.lxc
      pkgs.nftables
    ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.succeed("mkdir -p /var/lib/waydroid/lxc/waydroid")
    machine.succeed("echo 'lxc.net.0.link = waydroid0' > /var/lib/waydroid/lxc/waydroid/config")

    for attempt in range(2):
        with subtest(f"network start {attempt + 1} uses nftables"):
            machine.succeed("${network} start")
            machine.succeed("test -f /run/waydroid-lxc/network_up")
            machine.succeed("ip -4 addr show dev waydroid0 | grep -F '192.168.240.1/24'")
            machine.succeed("nft list chain inet lxc input | grep -F '53, 67'")
            machine.succeed("nft list chain inet lxc forward | grep -F waydroid0")
            machine.succeed("nft list chain ip lxc postrouting | grep -F masquerade")
            machine.succeed("kill -0 $(cat /run/waydroid-lxc/dnsmasq.pid)")
            machine.fail("grep '^ip_tables ' /proc/modules")

        with subtest(f"network stop {attempt + 1} cleans up"):
            machine.succeed("${network} stop")
            machine.succeed("test ! -e /run/waydroid-lxc/network_up")
            machine.succeed("test ! -e /run/waydroid-lxc/dnsmasq.pid")
            machine.fail("ip link show dev waydroid0")
            machine.fail("nft list table inet lxc")
            machine.fail("nft list table ip lxc")
  '';
}
