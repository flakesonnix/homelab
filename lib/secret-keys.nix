pkgs: let
  inherit (pkgs) lib;
in {
  # Creates a oneshot service that generates `secretFile` (if missing) before
  # `serviceName` starts, so secrets never land in the Nix store.
  mkKeyGenService = {
    serviceName,
    secretFile,
    user,
    group,
    bytes,
    format ? "raw",
    extraCommands ? "",
  }: {pkgs, ...}: {
    systemd.services."${serviceName}-secret-key" = {
      description = "Generate ${serviceName} secret key";
      before = ["${serviceName}.service"];
      requiredBy = ["${serviceName}.service"];
      wantedBy = ["multi-user.target"];
      path = [pkgs.coreutils];
      serviceConfig = {
        Type = "oneshot";
        inherit user group;
        UMask = "0077";
      };
      script = ''
        if [ ! -s "${secretFile}" ]; then
          head -c ${toString bytes} /dev/urandom${lib.optionalString (format == "base64") " | base64"} > "${secretFile}"
        fi
        ${extraCommands}
      '';
    };

    systemd.services.${serviceName} = {
      after = ["${serviceName}-secret-key.service"];
      requires = ["${serviceName}-secret-key.service"];
    };
  };
}
