{
  lib,
  pkgs,
  ...
}: {
  lucy.base.enable = true;
  # All owner keys: 5× github.com/flakesonnix.keys + p53-local omen key
  # + helianthus deploy key. Same set on every host with SSH.
  lucy.base.sshKey = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOgPFwTysg5vOZ77Zqo9AehacYvO4iTm/T4QTy7MtfD2"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAT5LcBzQCMfPyq0t29vGjz6UCcTXKZWROmUy82A0lrS"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAzrW5cHMre50s8jFSbG6Yzg2TlQkKNQ59qRejIRUM0T"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFSg7uG+/7pn6biGGzHTynH7FZUu0YzhfurY0L5GW7Di"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINMermWS2Yxd5lthm6QpCxooP08ppv2+MJxYbHhoBYCz"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOppWJbYYY/Uwy2x4fb5RUUW+VLzLkRODyiha6QRM/tW lucy@omen"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFrxXlvevZfbBd5Ey07hahyXQYrDjk/0I7mrERillcHZ helianthus@nixos"
  ];

  networking.hostName = "p53";
  networking.networkmanager.enable = true;

  programs.sway = {
    package = pkgs.swayfx;
    wrapperFeatures.gtk = true;
    extraSessionCommands = ''
      # Intel renders first; NVIDIA also supplies the external display ports.
      # Resolve PCI paths because wlroots uses colons as device-list separators.
      unset WLR_DRM_DEVICES
      if [ -e /dev/dri/by-path/pci-0000:00:02.0-card ] && drm_device="$(${pkgs.coreutils}/bin/readlink -f /dev/dri/by-path/pci-0000:00:02.0-card)"; then
        export WLR_DRM_DEVICES="$drm_device"
      fi
      if [ -e /dev/dri/by-path/pci-0000:01:00.0-card ] && drm_device="$(${pkgs.coreutils}/bin/readlink -f /dev/dri/by-path/pci-0000:01:00.0-card)"; then
        export WLR_DRM_DEVICES="''${WLR_DRM_DEVICES:+$WLR_DRM_DEVICES:}$drm_device"
      fi
      unset drm_device
      export NIXOS_OZONE_WL=1
    '';
  };

  # Kein IPv6 auf dem Laptop: alles (NFS, DNS, Druck, VMs, WebUIs) läuft
  # über IPv4 (10.8.0.0/24); v6 brachte nur hängende AAAA-Pfade im Browser.
  # mireo/VMs behalten ihr ULA — stört hier nicht ohne v6-Stack.
  networking.enableIPv6 = false;

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

  lucy.topology = {
    icon = "devices.laptop";
    hardware.info = "Lenovo ThinkPad P53 · i7-9750H";
  };

  hq.deskflow.enable = true;

  # Lokale VMs auf p53: libvirtd an (TPM vorhanden: /dev/tpmrm0).
  # Alter Workaround (libvirt 12.4 Tss2_Tcti_Device_Init 243/CREDENTIALS bei
  # fehlendem TPM) ist obsolet — fällt der Daemon wieder so, hilft:
  # rm /var/lib/libvirt/secrets/secrets-encryption-key + reboot.
  # Client bleibt zusätzlich für remote mireo:
  # qemu+ssh://root@10.8.0.1/system (programs.virt-manager aus base.nix).
  virtualisation.libvirtd = {
    enable = true;
    qemu.swtpm.enable = true;
  };
  programs.virt-manager.enable = true;

  # OBS Studio für Streaming unter Sway: Bild via xdg-desktop-portal-wlr
  # (ScreenCast=wlr, kommt aus programs.sway), Ton via PipeWire
  # (wireplumber läuft, siehe profiles/desktop.nix). Virtuelle Kamera
  # (v4l2loopback) für Videocalls gleich mit an.
  programs.obs-studio = {
    enable = true;
    enableVirtualCamera = true;
    plugins = with pkgs; [
      obs-studio-plugins.obs-pipewire-audio-capture
    ];
  };

  # --- Lexmark MX410de via Windows Server 2003 print server ---
  # Data path: CUPS (Raw) -> smbwin2k backend -> SMB1/NT1 -> win2klexmark/LexmarkM.
  # Secrets: only the sops KEY NAME is referenced here; the password itself
  # lives encrypted in hosts/p53/secrets.yaml and decrypted in /run/secrets
  # (tmpfs, never in the Nix store).
  lucy.secrets = {
    enable = true;
    sopsFile = ../../../hosts/p53/secrets.yaml;
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
