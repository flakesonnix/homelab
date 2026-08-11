pkgs: let
  inherit (pkgs) lib;
  inherit (lib) mkOption types;
in {
  # Creates a oneshot service that generates `secretFile` (if missing) before
  # `serviceName` starts, so secrets never land in the Nix store.
  #
  # The spec is checked against a typed submodule (keyGenSpecType): unknown
  # or ill-typed fields abort evaluation instead of being ignored.
  mkKeyGenService = spec: let
    inherit (import ./types.nix {inherit lib;}) checked;
    specType = types.submodule {
      options = {
        serviceName = mkOption {type = types.nonEmptyStr;};
        secretFile = mkOption {type = types.path;};
        user = mkOption {type = types.nonEmptyStr;};
        group = mkOption {type = types.nonEmptyStr;};
        bytes = mkOption {type = types.ints.positive;};
        format = mkOption {
          type = types.enum ["raw" "base64"];
          default = "raw";
        };
        extraCommands = mkOption {
          type = types.lines;
          default = "";
        };
      };
    };
    s = checked specType spec;
  in
    {pkgs, ...}: {
      systemd.services."${s.serviceName}-secret-key" = {
        description = "Generate ${s.serviceName} secret key";
        before = ["${s.serviceName}.service"];
        requiredBy = ["${s.serviceName}.service"];
        wantedBy = ["multi-user.target"];
        path = [pkgs.coreutils];
        serviceConfig = {
          Type = "oneshot";
          inherit (s) user group;
          UMask = "0077";
        };
        script = ''
          if [ ! -s "${s.secretFile}" ]; then
            head -c ${toString s.bytes} /dev/urandom${lib.optionalString (s.format == "base64") " | base64"} > "${s.secretFile}"
          fi
          ${s.extraCommands}
        '';
      };

      systemd.services.${s.serviceName} = {
        after = ["${s.serviceName}-secret-key.service"];
        requires = ["${s.serviceName}-secret-key.service"];
      };
    };
}
