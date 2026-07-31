{
  lib,
  pkgs,
  yammat,
  ...
}: let
  inherit (import ../../lib/secret-keys.nix pkgs) mkKeyGenService;
  yammatPackage = yammat.packages.${pkgs.stdenv.hostPlatform.system}.yammat.overrideAttrs (old: {
    meta = (old.meta or {}) // {mainProgram = "yammat";};
  });
in {
  imports = [
    (import ./mk-microvm.nix {
      name = "yammat";
      ip = "10.8.0.5";
      mem = 2304;
      vcpu = 2;
      tcpPorts = [22 3000];
      volumes = [
        {
          image = "yammat-postgres.img";
          mountPoint = "/var/lib/postgresql";
          size = 8192;
          user = "postgres";
          group = "postgres";
        }
        {
          image = "yammat-state.img";
          mountPoint = "/var/lib/yammat";
          size = 128;
          user = "yammat";
          group = "yammat";
        }
      ];
      config = {
        imports = [
          yammat.nixosModule
          (mkKeyGenService {
            serviceName = "yammat";
            secretFile = "/var/lib/yammat/client_session_key.aes";
            user = "yammat";
            group = "yammat";
            bytes = 96;
            extraCommands = ''
              install -m 600 /var/lib/yammat/client_session_key.aes /tmp/yammat_session_key.aes
            '';
          })
        ];

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

        systemd.services.yammat = {
          after = ["postgresql.service"];
          requires = ["postgresql.service"];
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
    })
  ];
}
