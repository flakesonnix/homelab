{
  lib,
  pkgs,
  ...
}: {
  lucy.base.enable = true;
  lucy.base.sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAT5LcBzQCMfPyq0t29vGjz6UCcTXKZWROmUy82A0lrS";
  lucy.base.sshKeyComment = "lucy@x270";

  networking.hostName = "x270";
  networking.networkmanager.enable = true;

  # Time sync: own NTP VM first (single source via vm-ips.nix), public
  # pools as fallback for roaming (timesyncd tries in order). mireo host
  # and microVMs intentionally keep upstream defaults (no guest-boot
  # dependency for the router).
  networking.timeServers = [
    (import ../../../hosts/mireo/vm-ips.nix).ntp
    "0.nixos.pool.ntp.org"
    "1.nixos.pool.ntp.org"
  ];

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General = {
      Enable = "Source,Sink,Media,Socket";
      Experimental = true;
    };
  };
  services.blueman.enable = true;

  niri.users = ["lucy"];

  lucy.topology = {
    icon = "devices.laptop";
    hardware.info = "Lenovo ThinkPad X270 · i7-7600U";
  };

  hq.deskflow.enable = true;

  # Workaround for libvirtd TPM failure on recent NixOS (tpmrm0 missing, exit 243).
  # Local daemon aus, Client bleibt an für remote mireo:
  # qemu+ssh://root@10.8.0.1/system (programs.virt-manager aus base.nix).
  virtualisation.libvirtd.enable = lib.mkForce false;
  programs.virt-manager.enable = true;

  # --- Lexmark MX410de via Windows Server 2003 print server ---
  # Data path: CUPS (Raw) -> smbwin2k backend -> SMB1/NT1 -> win2klexmark/LexmarkM.
  # Secrets: only the sops KEY NAME is referenced here; the password itself
  # lives encrypted in hosts/x270/secrets.yaml and decrypted in /run/secrets
  # (tmpfs, never in the Nix store).
  lucy.secrets = {
    enable = true;
    sopsFile = ../../../hosts/x270/secrets.yaml;
  };
  sops.secrets."samba/lexmark-password" = {
    # Backend läuft nicht zwingend als root: Gruppe lp darf mitlesen.
    mode = "0440";
    owner = "root";
    group = "lp";
  };

  # CUPS backend wrapper: same smbspool binary NixOS already ships for `smb`,
  # but credentials come from the sops file (via DEVICE_URI env, readable by
  # root only) and SMB1 is scoped to this printer via a private smb.conf
  # (SMB_CONF_PATH). The global smb.conf — and every other SMB client — is
  # untouched and stays on modern protocols.
  # NOTE: both heredocs below are QUOTED, so the outer build shell expands
  # nothing; only explicit ${...} is Nix interpolation. The @out@ token is
  # replaced with the store path afterwards for the same reason.
  services.printing.drivers = let
    smbWin2k = pkgs.runCommand "cups-backend-smbwin2k" {} ''
      mkdir -p $out/lib/cups/backend $out/etc/cups
      cat > $out/etc/cups/smb-win2k.conf <<'EOF'
      [global]
      client min protocol = NT1
      client max protocol = NT1
      EOF
      cat > $out/lib/cups/backend/smbwin2k <<'SCRIPT_EOF'
      #!${pkgs.runtimeShell}
      # CUPS backend protocol args: job-id user title copies options [file].
      set -eu
      export LC_ALL=C
      SMB_USER="Administrator"
      PASSFILE="/run/secrets/samba/lexmark-password"
      if [ ! -r "$PASSFILE" ]; then
        echo "smbwin2k: credential file $PASSFILE unreadable" >&2
        exit 1
      fi
      SMB_PASS="$(cat "$PASSFILE")"
      urlencode() {
        _ue_out=""
        _ue_i=0
        _ue_len="''${#1}"
        while [ "$_ue_i" -lt "$_ue_len" ]; do
          _ue_c="''${1:$_ue_i:1}"
          case "$_ue_c" in
            [a-zA-Z0-9.~_-]) _ue_out="$_ue_out$_ue_c" ;;
            *) printf -v _ue_h '%%%02X' "'$_ue_c"; _ue_out="$_ue_out$_ue_h" ;;
          esac
          _ue_i=$((_ue_i + 1))
        done
        printf '%s' "$_ue_out"
      }
      export SMB_CONF_PATH="@out@/etc/cups/smb-win2k.conf"
      export DEVICE_URI="smb://$(urlencode "$SMB_USER"):$(urlencode "$SMB_PASS")@win2klexmark/LexmarkM"
      unset SMB_PASS
      exec "${pkgs.samba}/bin/smbspool" "$@"
      SCRIPT_EOF
      substituteInPlace $out/lib/cups/backend/smbwin2k --replace-fail '@out@' "$out"
      chmod 755 $out/lib/cups/backend/smbwin2k
    '';
  in [smbWin2k];

  # Raw queue: bytes pass through to the Windows driver untouched, exactly
  # the path already tested with smbclient. No PPD/driver package needed.
  hardware.printers.ensurePrinters = [
    {
      name = "LexmarkM";
      location = "win2klexmark.home.arpa";
      deviceUri = "smbwin2k://win2klexmark/LexmarkM";
      model = "raw";
    }
  ];
}
