{
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption types mkForce;
in {
  # ── mkReconciler ────────────────────────────────────────
  # Creates a systemd service that runs an idempotent
  # reconciliation script. This is the core pattern for
  # making stateful applications declarative in NixOS.
  #
  # The reconciler:
  # 1. Runs after the target service
  # 2. Executes the script idempotently
  # 3. Never fails the deploy (exit 0 always)
  # 4. Logs errors for debugging
  #
  # Usage:
  #   lib.reconciliation.mkReconciler {
  #     name = "nextcloud";
  #     after = ["nextcloud.service"];
  #     script = ''
  #       ...idempotent commands...
  #     '';
  #   }
  mkReconciler = {
    name,
    after ? [],
    script,
    requires ? [],
    wantedBy ? ["multi-user.target"],
    serviceConfig ? {},
    environment ? {},
    path ? [],
    ...
  }: {
    systemd.services."reconcile-${name}" = {
      description = "Reconcile ${name} state (idempotent)";
      after = after;
      requires = requires;
      wantedBy = wantedBy;
      serviceConfig =
        {
          Type = "oneshot";
          RemainAfterExit = true;
          # Never fail the deploy: reconciler errors are logged
          # but don't block the system.
          ExecStart = "${pkgs.runtimeShell} -c 'exec 2>&1; ${script}'";
          TimeoutStartSec = 300;
        }
        // serviceConfig;
      environment = environment;
      path = path;
    };
  };

  # ── mkSafeReconciler ────────────────────────────────────
  # Like mkReconciler but with fail-safe behavior: if the
  # script fails, it retries up to N times before giving up.
  mkSafeReconciler = {
    name,
    retries ? 3,
    after ? [],
    script,
    ...
  }:
    mkReconciler {
      inherit name after script;
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "10s";
        StartLimitBurst = retries;
      };
    };

  # ── mkDeclarativeService ────────────────────────────────
  # Combines a microVM spec with a reconciler for a stateful
  # service. This is the main entry point for building
  # "declarative but stateful" services.
  mkDeclarativeService = {
    name,
    microvmSpec,
    reconcilerScript,
    ...
  }:
    import ../../hosts/mireo/mk-microvm.nix microvmSpec
    // {
      config =
        microvmSpec.config
        // {
          systemd.services."reconcile-${name}" = {
            description = "Reconcile ${name} state (idempotent)";
            after = ["${name}.service"];
            requires = ["${name}.service"];
            wantedBy = ["multi-user.target"];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = reconcilerScript;
          };
        };
    };

  # ── mkSyncConfig ────────────────────────────────────────
  # Creates a one-shot service that syncs a generated config
  # file into the service's config directory. Used for
  # services that read their config from a file that Nix
  # generates.
  mkSyncConfig = {
    name,
    source,
    target,
    mode ? "0644",
    user ? null,
    group ? null,
    after ? [],
  }: {
    systemd.services."${name}-config-sync" = {
      description = "Sync ${name} configuration";
      after = after ++ ["${name}.service"];
      requires = ["${name}.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -eu
        install -D -m ${mode} ${source} ${target}
        ${lib.optionalString (user != null) "chown ${user}:${group} ${target}"}
      '';
    };
  };

  # ── mkStageSecrets ──────────────────────────────────────
  # Creates a systemd service that stages host-shared secrets
  # from a virtiofs share into guest tmpfs. Used when the guest
  # application cannot read directly from virtiofs (EOPNOTSUPP).
  mkStageSecrets = {
    name,
    secretTag,
    targetDir,
    owner,
    group,
    mode ? "0400",
  }: {
    systemd.services."${name}-secrets-setup" = {
      description = "Stage ${name} secrets from virtiofs share into tmpfs";
      before = ["${name}.service"];
      requiredBy = ["${name}.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -eu
        mkdir -p ${targetDir}
        cd /run/secrets/${name}
        find . -type f -print0 | while IFS= read -r -d "" f; do
          install -D -o ${owner} -g ${group} -m${mode} "$f" "${targetDir}/$(basename "$f")"
        done
      '';
    };
  };

  # ── mkSopsSecretReference ───────────────────────────────
  # Generates a sops.secrets reference for the data/hosts/mireo
  # services.nix file.
  mkSopsSecretReference = name: {
    sops = {
      secrets."${name}" = {};
    };
  };
}
