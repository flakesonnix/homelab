{
  lib,
  pkgs,
  yammat,
  ...
}: let
  keys = import ../../ssh-public-keys.nix {inherit lib;};
  yammatPackage = yammat.packages.${pkgs.system}.yammat.overrideAttrs (old: {
    meta = (old.meta or {}) // {mainProgram = "yammat";};
  });
in {

  systemd.network.networks."27-lan-microvm-yammat" = {
    matchConfig.Name = "vm-yammat";
    networkConfig.Bridge = "br0";
  };

  microvm.autostart = ["yammat"];

  microvm.vms.yammat = {
    autostart = true;
    config = {
      imports = [yammat.nixosModule];

      system.stateVersion = "25.11";
      networking.hostName = "yammat";
      networking.firewall.allowedTCPPorts = [22 3000];

      users.users.root.openssh.authorizedKeys.keys = [keys.lucy.servers];
      services.openssh = {
        enable = true;
        settings.PermitRootLogin = "yes";
      };

      microvm = {
        hypervisor = "qemu";
        mem = 2304;
        vcpu = 2;
        interfaces = [
          {
            type = "tap";
            id = "vm-yammat";
            mac = "02:00:00:10:08:05";
          }
        ];
        shares = [
          {
            proto = "virtiofs";
            tag = "ro-store";
            source = "/nix/store";
            mountPoint = "/nix/.ro-store";
          }
        ];
        volumes = [
          {
            image = "yammat-postgres.img";
            mountPoint = "/var/lib/postgresql";
            size = 8192;
          }
          {
            image = "yammat-state.img";
            mountPoint = "/var/lib/yammat";
            size = 128;
          }
        ];
      };

      systemd.network.enable = true;
      systemd.network.networks."20-lan" = {
        matchConfig.Type = "ether";
        address = ["10.8.0.5/24"];
        networkConfig = {
          Gateway = "10.8.0.1";
          DNS = ["10.8.0.1"];
          DHCP = "no";
          IPv6AcceptRA = false;
        };
      };

      services.yammat = {
        enable = true;
        package = yammatPackage;
        config = lib.mkForce ''
          static-dir: "_env:STATIC_DIR:static"
          host: "_env:HOST:10.8.0.5"
          port: "_env:PORT:3000"
          approot: "_env:APPROOT:http://10.8.0.5:3000"
          ip-from-header: "_env:IP_FROM_HEADER:false"

          database:
            user: "_env:PGUSER:yammat"
            password: "_env:PGPASS:notused"
            host: "_env:PGHOST:localhost"
            port: "_env:PGPORT:5432"
            database: "_env:PGDATABASE:yammat"
            poolsize: "_env:PGPOOLSIZE:10"

          email:
          - "noreply@yammat.local"
          currency: "€"
          cash_charge: 0

          copyright: "Powered by YAMMAT"
          copyright_link: "https://gitea.c3d2.de/c3d2/yammat"

          block_users: false
        '';
      };

      systemd.tmpfiles.rules = [
        "d /var/lib/yammat 0750 yammat yammat - -"
      ];

      systemd.services.yammat-session-key = {
        description = "Prepare YAMMAT session key";
        before = ["yammat.service"];
        requiredBy = ["yammat.service"];
        wantedBy = ["multi-user.target"];
        path = [pkgs.coreutils];
        serviceConfig = {
          Type = "oneshot";
          User = "yammat";
          Group = "yammat";
          UMask = "0077";
        };
        script = ''
          if [ ! -s /var/lib/yammat/client_session_key.aes ]; then
            head -c 96 /dev/urandom > /var/lib/yammat/client_session_key.aes
          fi
          install -m 600 /var/lib/yammat/client_session_key.aes /tmp/yammat_session_key.aes
        '';
      };

      systemd.services.yammat = {
        after = ["postgresql.service" "yammat-session-key.service"];
        requires = ["postgresql.service" "yammat-session-key.service"];
        environment = {
          APPROOT = lib.mkForce "http://10.8.0.5:3000";
          HOST = lib.mkForce "10.8.0.5";
          PORT = lib.mkForce "3000";
          STATIC_DIR = lib.mkForce "${yammatPackage}/static";
          PGHOST = lib.mkForce "";
          PGPASS = lib.mkForce "";
          PGUSER = lib.mkForce "yammat";
          PGDATABASE = lib.mkForce "yammat";
        };
      };
    };
  };
}
