{
  lib,
  pkgs,
  nixpkgs,
  wrappers,
  ...
}: let
  dotfilesFlake = ../..;
in {
  imports = [
    # Base live ISO: minimal installer + firmware
    "${nixpkgs}/nixos/modules/installer/cd-dvd/iso-image.nix"
    "${nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
    ../../profiles/desktop.nix
    ../../modules/nixos/cups.nix
    ../../modules/nixos/fonts.nix
    ../../modules/nixos/niri.nix
    ../../modules/nixos/waybar.nix
    ../../modules/nixos/hm-base.nix
  ];

  # --- ISO identity ---
  isoImage = {
    isoName = "lucy-live.iso";
    volumeID = "LUCY_LIVE";
    makeEfiBootable = true;
    makeUsbBootable = true;
    appendToMenuLabel = " Live (TTY or Niri)";
  };

  # Live user: nixos (TTY) and lucy (Niri with dots)
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "video" "audio"];
    initialPassword = "nixos";
    shell = pkgs.bash;
  };
  # Autologin shell runs live-select menu, then drops to bash
  # We keep shell as bash, but add profile hook to run live-select on first login
  environment.shellInit = ''
    if [ "$(whoami)" = "nixos" ] && [ "$(tty)" = "/dev/tty1" ] && [ -z "$LIVE_SELECT_DONE" ]; then
      export LIVE_SELECT_DONE=1
      if command -v live-select >/dev/null 2>&1; then
        live-select
      fi
    fi
  '';
  users.users.lucy = {
    isNormalUser = true;
    description = lib.mkForce "Lucy (live Niri)";
    extraGroups = ["wheel" "networkmanager" "video" "audio"];
    initialPassword = lib.mkForce "nixos";
    shell = pkgs.bash;
  };
  security.sudo.wheelNeedsPassword = false;
  # Boot to TTY with live-select menu (not auto Niri)
  services.getty.autologinUser = lib.mkForce "nixos";

  # Greetd disabled for live ISO — we use getty + live-select for explicit choice
  services.greetd.enable = lib.mkForce false;

  # Niri live session
  programs.niri.enable = lib.mkForce true;
  services.displayManager.sessionPackages = [pkgs.niri];

  # Copy dotfiles flake into ISO for offline install
  environment.etc."nixos/dotfiles".source = dotfilesFlake;

  # Installer helpers + all CLI tools in both TTY and Niri (system-wide)
  environment.systemPackages = with pkgs; [
    # our installer
    (writeShellApplication {
      name = "install-dotfiles";
      runtimeInputs = [pkgs.nixos-install-tools pkgs.gptfdisk pkgs.parted pkgs.curl pkgs.jq pkgs.git];
      text = builtins.readFile ./install.sh;
    })
    (writeShellApplication {
      name = "live-select";
      runtimeInputs = [pkgs.fzf pkgs.util-linux];
      text = ''
        #!/usr/bin/env bash
        set -e
        while true; do
          clear
          cat <<'MENU'
        Purr / Homelab Live ISO
        ────────────────────────────

          1) Start graphical session (Niri)
          2) Start shell
          3) Install / configure host
          4) Reboot

        MENU
          echo ""
          read -rp "Select [1-4] (q to quit): " choice
          case "$choice" in
            1) echo "Starting Niri..."; niri-session; break ;;
            2) echo "Starting shell..."; bash --login; ;;
            3) install-dotfiles ;;
            4) reboot ;;
            q|Q) break ;;
            *) echo "Invalid choice"; sleep 1 ;;
          esac
        done
      '';
    })
    (writeShellApplication {
      name = "choose-desktop";
      text = ''
        echo "1) TTY  — stay in console (login nixos/nixos)"
        echo "2) Niri — start niri with lucy dots (login lucy/nixos, then: niri-session)"
        echo ""
        echo "Greetd already lets you choose: TTY = 'nixos' session, Niri = 'niri-session'."
        echo "From TTY run: sudo systemctl start display-manager  # to get greetd"
        echo "From live shell run: install-dotfiles  # to install to disk"
        echo "Or run: live-select  (TTY menu: Niri / shell / install / reboot)"
      '';
    })
    git
    curl
    wget
    vim
    neovim
    htop
    btop
    nmap
    tcpdump
    # all CLI tools from dotfiles (home + system)
    comma
    manix
    nix-output-monitor
    nload
    iotop
    iftop
    ripgrep
    fd
    fzf
    jq
    yq
    tmux
    tree
    dust
    ncdu
    lsof
    strace
    usbutils
    pciutils
    ethtool
    iperf3
    mtr
    socat
    netcat-gnu
    file
    lm_sensors
    smartmontools
    sysstat
    dmidecode
  ];

  # Networking + SSH for headless install
  networking.networkmanager.enable = lib.mkForce true;
  networking.useNetworkd = lib.mkForce false;
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };
  users.users.root.initialPassword = "nixos";

  # Firmware + base
  hardware.enableAllFirmware = true;
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];
  system.stateVersion = "25.11";

  # Say hello on TTY
  environment.etc."issue".text = lib.mkForce ''
    Lucy Live ISO — TTY or Niri with dots

    Boot: TTY with live-select menu (not auto Niri)
      1) Start graphical session (Niri)  →  niri-session
      2) Start shell                     →  bash
      3) Install / configure host        →  install-dotfiles
      4) Reboot

    Login: nixos/nixos (TTY, autologin → live-select)  or  lucy/nixos  →  niri-session
    Manual: live-select  (re-run menu),  choose-desktop (help)

    Flake at /etc/nixos/dotfiles  —  nix run .#menu
    Docs: data/hosts/*/host.nix, profiles/base.nix, modules/nixos/niri.nix


  '';
}
