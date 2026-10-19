{
  config,
  lib,
  ...
}: let
  systemd = config.systemd.package;
  dataVMs = lib.attrNames (lib.filterAttrs (_: vm:
    lib.any (share: share.source == "/data" || lib.hasPrefix "/data/" share.source)
    (vm.config.config.microvm.shares or []))
  (config.microvm.vms or {}));
  consumers =
    ["nfs-server" "nfs-mountd" "asterisk" "fax-poller" "mopidy" "mopidy-scan"]
    ++ lib.concatMap (name: ["microvm@${name}" "microvm-virtiofsd@${name}"]) dataVMs;
  mountGuard = {
    after = ["data.mount"];
    unitConfig = {
      # Hard mount dependencies fail before conditions can skip a missing disk.
      StopPropagatedFrom = ["data.mount"];
      ConditionPathIsMountPoint = "/data";
    };
  };
in {
  fileSystems."/data" = {
    neededForBoot = false;
    options = ["x-systemd.device-timeout=10s" "x-systemd.mount-timeout=30s"];
  };

  systemd.services =
    {
      # Exclude all /data rules, including structured rules from microvm.nix.
      systemd-tmpfiles-setup.serviceConfig.ExecStart = lib.mkForce [
        ""
        "${systemd}/bin/systemd-tmpfiles --create --remove --boot --exclude-prefix=/dev --exclude-prefix=/data"
      ];
      systemd-tmpfiles-resetup.serviceConfig.ExecStart = lib.mkForce "${systemd}/bin/systemd-tmpfiles --create --remove --exclude-prefix=/dev --exclude-prefix=/data";

      mireo-data-setup =
        mountGuard
        // {
          description = "Initialize mireo data directories only on the mounted filesystem";
          wantedBy = ["multi-user.target"];
          restartTriggers = [config.environment.etc."tmpfiles.d".source];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${systemd}/bin/systemd-tmpfiles --create --remove --prefix=/data";
          };
        };
    }
    // lib.genAttrs consumers (_:
      mountGuard
      // {
        requires = ["mireo-data-setup.service"];
        after = mountGuard.after ++ ["mireo-data-setup.service"];
      });
}
