{pkgs, ...}: let
  consumers = [
    "nfs-server"
    "nfs-mountd"
    "asterisk"
    "fax-poller"
    "mopidy"
    "mopidy-scan"
    "microvm@jellyfin"
    "microvm-virtiofsd@jellyfin"
  ];
in
  pkgs.testers.runNixOSTest {
    name = "mireo-optional-data";

    nodes.machine = {lib, ...}: {
      # QEMU normally discards host filesystems; retain the module's /data policy.
      imports = [
        ({
          config,
          lib,
          ...
        }: let
          dataModule = import ../hosts/mireo/optional-data.nix {inherit config lib;};
        in
          dataModule // {fileSystems = lib.mkVMOverride dataModule.fileSystems;})
      ];

      # Only the evaluated share metadata is needed; no production VM builds.
      options.microvm.vms = lib.mkOption {
        type = lib.types.attrs;
        default = {};
      };
      config = {
        microvm.vms = {
          jellyfin.config.config.microvm.shares = [{source = "/data/Jellyfin";}];
          unrelated.config.config.microvm.shares = [{source = "/database";}];
        };
        fileSystems = lib.mkVMOverride {
          "/data" = {
            device = "/dev/disk/by-label/missing-data";
            fsType = "ext4";
            options = ["defaults" "nofail"];
          };
        };
        services.openssh.enable = true;
        services.dnsmasq = {
          enable = true;
          resolveLocalQueries = false;
          settings = {
            interface = "eth1";
            bind-interfaces = true;
            no-resolv = true;
            host-record = "mireo.test,192.168.1.1";
            dhcp-range = "192.168.1.100,192.168.1.200,255.255.255.0,1h";
            enable-tftp = true;
            tftp-root = "/data/pxe";
            tftp-no-fail = true;
          };
        };
        environment.systemPackages = [pkgs.dig];

        systemd.tmpfiles.rules = [
          "d /data/pxe 0755 root root - -"
          "d /data/fax/inbox 0755 root root - -"
          "d /var/lib/optional-data-test 0755 root root - -"
        ];
        systemd.tmpfiles.settings."10-microvm"."/data/Jellyfin".d = {
          mode = "0755";
          user = "root";
          group = "root";
        };

        systemd.services =
          lib.genAttrs consumers (name: {
            wantedBy = ["multi-user.target"];
            serviceConfig.Type = "simple";
            script = ''
              set -eu
              test -d /data/pxe -a -d /data/fax/inbox -a -d /data/Jellyfin
              mkdir -p /data/writers
              touch /data/writers/${lib.escapeShellArg name}
              exec ${pkgs.coreutils}/bin/sleep infinity
            '';
          })
          // {
            "microvm@unrelated" = {
              wantedBy = ["multi-user.target"];
              serviceConfig.ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
            };
          };
      };
    };

    testScript = ''
      import json

      consumers = json.loads('${builtins.toJSON consumers}')
      units = " ".join(name + ".service" for name in consumers)

      def assert_root_data_empty():
          machine.fail("mountpoint -q /data")
          machine.succeed("test ! -e /data || test -z \"$(find /data -mindepth 1 -print -quit)\"")

      def assert_consumers_stopped():
          for name in ["mireo-data-setup"] + consumers:
              machine.fail(f"systemctl is-active --quiet {name}.service")

      start_all()
      with subtest("missing disk does not prevent boot or network services"):
          machine.wait_for_unit("multi-user.target", timeout=180)
          machine.wait_for_unit("dnsmasq.service")
          machine.wait_for_unit("sshd.service")
          machine.wait_for_open_port(22)
          machine.wait_for_unit("microvm@unrelated.service")
          machine.succeed("dig @127.0.0.1 mireo.test +short | grep -Fx 192.168.1.1")
          machine.succeed("ss -lun | grep -E ':67[[:space:]]'")
          machine.succeed("test -d /var/lib/optional-data-test")
          assert_consumers_stopped()
          assert_root_data_empty()

      with subtest("activation tmpfiles also leaves the underlying root untouched"):
          machine.succeed("systemctl start systemd-tmpfiles-resetup.service")
          assert_root_data_empty()

      with subtest("mounting data initializes it before any consumer writes"):
          # Replace only the missing disk in this fixture, retaining the real guards.
          machine.succeed(
              "printf '[Mount]\\nWhat=tmpfs\\nWhere=/data\\nType=tmpfs\\nOptions=mode=0755\\n' "
              "> /run/systemd/system/data.mount"
          )
          machine.succeed("systemctl daemon-reload")
          machine.succeed("systemctl reset-failed")
          machine.succeed("systemctl start data.mount")
          machine.succeed("mountpoint -q /data")
          machine.succeed(f"systemctl start {units}")
          machine.wait_for_unit("mireo-data-setup.service")
          for name in consumers:
              machine.wait_for_unit(name + ".service")
              machine.wait_until_succeeds(f"test -e /data/writers/{name}")
          machine.succeed("systemctl restart systemd-tmpfiles-resetup.service")

      with subtest("unmounting data stops consumers and never writes to root"):
          machine.succeed("systemctl stop data.mount")
          assert_consumers_stopped()
          assert_root_data_empty()
          machine.succeed("systemctl restart systemd-tmpfiles-resetup.service")
          assert_root_data_empty()
          for name in ["dnsmasq", "sshd", "microvm@unrelated"]:
              machine.succeed(f"systemctl is-active --quiet {name}.service")
    '';
  }
