# File Documentation - Complete Content

## File: ./flake.nix

### Purpose
Entry point for the NixOS flake. Defines all flake inputs and outputs.

### Content (FULL)
```nix
{
  description = "NixOS dotfiles for lucy";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/24.11";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, ... }:
    let
      myLib = import ./lib;
    in
    {
      lib = myLib;

      nixosConfigurations.p50 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./nix-settings.nix
          {
            p50.nixSettings = true;
            imports = [ ./hosts/p50 ];
            users.users.lucy.isNormalUser = true;
            users.users.lucy.description = "Lucy";
            users.users.lucy.extraGroups = [ "wheel" "networkmanager" ];
          }
        ];
      };

      homeConfigurations."lucy@p50" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [ import ./home/lucy ];
      };

      devShells.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
        packages = with nixpkgs.legacyPackages.x86_64-linux; [
          nixpkgs-fmt
          nil
          git
        ];
      };

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
    };
}
```

### Key Points
- Uses nixpkgs 24.11 (stable) instead of nixos-unstable due to bugs
- nixosConfigurations.p50: NixOS system for ThinkPad P50
- homeConfigurations."lucy@p50": home-manager config for user lucy
- devShells: Development shell with nixpkgs-fmt, nil, git
- formatter: nixpkgs-fmt for nix code formatting

---

## File: ./lib/default.nix

### Purpose
Helper functions for the dotfiles framework.

### Content (FULL)
```nix
{
  mkUser =
    { username
    , description ? ""
    , modules ? [ ]
    }:
    {
      inherit username modules description;
    };
}
```

### Key Points
- mkUser: Creates a user config with username, description, and modules
- Minimal implementation - more helpers could be added

---

## File: ./nix-settings.nix

### Purpose
Nix settings module - enables flakes and configures Nix.

### Content (FULL)
```nix
{ lib, config, ... }:

{
  options.p50 = {
    nixSettings = lib.mkEnableOption "Nix settings for p50";
  };

  config = lib.mkIf config.p50.nixSettings {
    nix = {
      settings = {
        experimental-features = [ "nix-command" "flakes" ];
        auto-optimise-store = true;
      };
    };
  };
}
```

### Key Points
- Toggle: p50.nixSettings.enable
- Sets: experimental-features (nix-command, flakes)
- Sets: auto-optimise-store = true

---

## File: ./hosts/p50/default.nix

### Purpose
NixOS system configuration for ThinkPad P50 host.

### Content (FULL)
```nix
{ config, pkgs, ... }:

{
  imports =
    [ ./hardware-configuration.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "p50";

  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Berlin";

  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };

  services.xserver.enable = true;

  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.printing.enable = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  users.users.lucy = {
    isNormalUser = true;
    description = "Lucy";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
    ];
  };

  programs.firefox.enable = true;

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
  ];

  system.stateVersion = "25.11";
}
```

### Key Options Set
- boot.loader.systemd-boot.enable = true
- networking.hostName = "p50"
- networking.networkmanager.enable = true
- time.timeZone = "Europe/Berlin"
- i18n.defaultLocale = "en_US.UTF-8"
- services.xserver.enable = true
- services.xserver.displayManager.gdm.enable = true
- services.xserver.desktopManager.gnome.enable = true
- services.xserver.xkb.layout = "us"
- services.printing.enable = true
- security.rtkit.enable = true
- services.pipewire.* (enable, alsa, pulse)
- users.users.lucy.* (isNormalUser, description, extraGroups)
- programs.firefox.enable = true
- nixpkgs.config.allowUnfree = true
- system.stateVersion = "25.11"

---

## File: ./hosts/p50/hardware-configuration.nix

### Purpose
Hardware configuration auto-generated by nixos-generate-config.

### Content (FULL)
```nix
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/mapper/luks-90b17531-753e-4576-a453-a7d81be1d09e";
      fsType = "ext4";
    };

  boot.initrd.luks.devices."luks-90b17531-753e-4576-a453-a7d81be1d09e".device = "/dev/disk/by-uuid/90b17531-753e-4576-a453-a7d81be1d09e";

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/E019-982F";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  swapDevices =
    [ { device = "/dev/mapper/luks-d18ac909-2d76-47d4-a73e-8d396beee250"; }
    ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
```

### Hardware Details
- Root filesystem: LUKS encrypted ext4 (/dev/mapper/luks-90b17531-...)
- Boot: EFI partition at /boot (vfat)
- Swap: LUKS encrypted (/dev/mapper/luks-d18ac909-...)
- Initrd modules: xhci_pci, ahci, nvme, usb_storage, sd_mod, rtsx_pci_sdmmc
- Kernel modules: kvm-intel
- CPU: Intel with microcode update
- Platform: x86_64-linux

---

## File: ./modules/nixos/default.nix

### Purpose
Base NixOS module aggregating all nixos system modules.

### Content (FULL)
```nix
{ lib, ... }:

{
  imports = [
    ./nix-settings.nix
  ];

  options.lucy.nixos = {
    enable = lib.mkEnableOption "lucy's NixOS system configuration";
  };

  config = lib.mkIf (lib.mkDefault false) { };
}
```

### Imports
- ./nix-settings.nix

### Options
- lucy.nixos.enable: Toggle for lucy's NixOS system config

---

## File: ./modules/nixos/niri.nix

### Purpose
Niri Wayland compositor system-level configuration.

### Content (FULL)
```nix
{ config, lib, pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.niri
  ];

  services.displayManager.sessionPackages = [
    pkgs.niri
  ];

  xdg = {
    autostart.enable = lib.mkDefault true;
    menus.enable = lib.mkDefault true;
    mime.enable = lib.mkDefault true;
    icons.enable = lib.mkDefault true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
    configPackages = [ pkgs.niri ];
  };

  security.polkit.enable = true;

  systemd.user.services.niri-polkit = {
    description = "PolicyKit Authentication Agent for niri";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

  programs.dconf.enable = lib.mkDefault true;
  fonts.enableDefaultPackages = lib.mkDefault true;
}
```

### Key Points
- Installs niri package to system
- Adds niri to display manager session packages
- Enables XDG autostart, menus, mime, icons
- Enables xdg.portal with gnome portal and niri config package
- Enables polkit security
- Sets up polkit KDE authentication agent for niri
- Enables dconf and default fonts

---

## File: ./modules/home/default.nix

### Purpose
Base home-manager module for user configuration.

### Content (FULL)
```nix
{ lib }:

{
  options.lucy.home = {
    enable = lib.mkEnableOption "lucy's home-manager configuration";
  };

  config = lib.mkIf (lib.mkDefault false) { };
}
```

### Options
- lucy.home.enable: Toggle for lucy's home-manager config

---

## File: ./home/lucy/default.nix

### Purpose
Main home-manager configuration for user lucy.

### Content (FULL)
```nix
{ config, pkgs, lib, ... }:

{
  imports = [
    ./shell.nix
    ./git.nix
    ./editor.nix
    ./packages.nix
  ];

  home = {
    username = "lucy";
    homeDirectory = "/home/lucy";
    stateVersion = "25.11";
  };

  programs.home-manager.enable = true;

  xdg.configFile."niri/config.kdl" = {
    source = pkgs.writeText "niri-config.kdl" ''
      input {
        keyboard {
          xkb {
            layout "us"
          }
        }
        touchpad {
          tap
          natural-scroll
        }
      }

      layout {
        gaps 16
      }

      binds {
        Mod+Shift+Slash {
          show-hotkey-overlay
        }
        Mod+T {
          spawn "alacritty"
        }
        Mod+D {
          spawn "fuzzel"
        }
        Mod+Q {
          close-window
        }
        Mod+Left {
          focus-column-left
        }
        Mod+Down {
          focus-window-down
        }
        Mod+Up {
          focus-window-up
        }
        Mod+Right {
          focus-column-right
        }
        Mod+H {
          focus-column-left
        }
        Mod+J {
          focus-window-down
        }
        Mod+K {
          focus-window-up
        }
        Mod+L {
          focus-column-right
        }
        Mod+Ctrl+Left {
          move-column-left
        }
        Mod+Ctrl+Down {
          move-window-down
        }
        Mod+Ctrl+Up {
          move-window-up
        }
        Mod+Ctrl+Right {
          move-column-right
        }
        Mod+Ctrl+H {
          move-column-left
        }
        Mod+Ctrl+J {
          move-window-down
        }
        Mod+Ctrl+K {
          move-window-up
        }
        Mod+Ctrl+L {
          move-column-right
        }
        Mod+Page_Down {
          focus-workspace-down
        }
        Mod+Page_Up {
          focus-workspace-up
        }
        Mod+U {
          focus-workspace-down
        }
        Mod+I {
          focus-workspace-up
        }
        Mod+1 {
          focus-workspace 1
        }
        Mod+2 {
          focus-workspace 2
        }
        Mod+3 {
          focus-workspace 3
        }
        Mod+4 {
          focus-workspace 4
        }
        Mod+5 {
          focus-workspace 5
        }
        Mod+6 {
          focus-workspace 6
        }
        Mod+7 {
          focus-workspace 7
        }
        Mod+8 {
          focus-workspace 8
        }
        Mod+9 {
          focus-workspace 9
        }
        Mod+Comma {
          consume-window-into-column
        }
        Mod+Period {
          expel-window-from-column
        }
        Mod+R {
          switch-preset-column-width
        }
        Mod+F {
          maximize-column
        }
        Mod+Shift+F {
          fullscreen-window
        }
        Mod+C {
          center-column
        }
        Print {
          screenshot
        }
        Mod+Shift+E {
          quit
        }
      }
    '';
  };

  home.packages = [ pkgs.niri ];
}
```

### Key Points
- Imports shell.nix, git.nix, editor.nix, packages.nix
- home.username = "lucy"
- home.homeDirectory = "/home/lucy"
- home.stateVersion = "25.11"
- programs.home-manager.enable = true
- xdg.configFile."niri/config.kdl": Full KDL config for niri compositor
- home.packages = [ pkgs.niri ]

---

## File: ./home/lucy/shell.nix

### Purpose
Shell configuration module for lucy.

### Content (FULL)
```nix
{ config, pkgs, lib, ... }:

{
  options.lucy.shell = {
    enable = lib.mkEnableOption "lucy's shell configuration";
  };

  config = lib.mkIf config.lucy.shell.enable {
    programs.zsh.enable = true;
  };
}
```

### Options
- lucy.shell.enable: Toggle shell config
- When enabled: programs.zsh.enable = true

---

## File: ./home/lucy/git.nix

### Purpose
Git configuration module for lucy.

### Content (FULL)
```nix
{ config, pkgs, lib, ... }:

{
  options.lucy.git = {
    enable = lib.mkEnableOption "lucy's git configuration";
  };

  config = lib.mkIf config.lucy.git.enable {
    programs.git.enable = true;
  };
}
```

### Options
- lucy.git.enable: Toggle git config
- When enabled: programs.git.enable = true

---

## File: ./home/lucy/editor.nix

### Purpose
Editor configuration module for lucy.

### Content (FULL)
```nix
{ config, pkgs, lib, ... }:

{
  options.lucy.editor = {
    enable = lib.mkEnableOption "lucy's editor configuration";
  };

  config = lib.mkIf config.lucy.editor.enable {
    programs.neovim.enable = true;
  };
}
```

### Options
- lucy.editor.enable: Toggle editor config
- When enabled: programs.neovim.enable = true

---

## File: ./home/lucy/packages.nix

### Purpose
Additional packages configuration for lucy.

### Content (FULL)
```nix
{ config, pkgs, lib, ... }:

{
  options.lucy.packages = {
    enable = lib.mkEnableOption "lucy's additional packages";
    list = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "List of packages to install for lucy";
    };
  };

  config = lib.mkIf config.lucy.packages.enable {
    home.packages = config.lucy.packages.list;
  };
}
```

### Options
- lucy.packages.enable: Toggle additional packages
- lucy.packages.list: List of packages to install

---

## File: ./profiles/base.nix

### Purpose
Base system profile with common configuration.

### Content (FULL)
```nix
{ lib }:

{
  imports = [
    ../modules/nixos
  ];

  environment.sessionVariables = {
    EDITOR = "vim";
    VISUAL = "vim";
  };

  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  nixpkgs.config.allowUnfree = true;

  programs.firefox.enable = true;

  services.printing.enable = true;

  security.rtkit.enable = true;

  users.users.lucy = {
    isNormalUser = true;
    description = "Lucy";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  system.stateVersion = lib.mkDefault "25.11";
}
```

### Key Points
- Imports modules/nixos
- Sets EDITOR and VISUAL to vim
- Sets defaultLocale to en_US.UTF-8
- Enables unfree packages
- Enables firefox
- Enables printing
- Enables rtkit
- Defines lucy user

---

## File: ./profiles/desktop.nix

### Purpose
Desktop profile with GNOME and pipewire.

### Content (FULL)
```nix
{ lib, ... }:

{
  imports = [
    ./base.nix
    ../modules/home
  ];

  services.displayManager.gdm.enable = lib.mkDefault true;
  services.desktopManager.gnome.enable = lib.mkDefault true;

  services.xserver.enable = lib.mkDefault true;
  services.xserver.xkb = {
    layout = lib.mkDefault "us";
    variant = "";
  };

  services.pipewire = {
    enable = lib.mkDefault true;
    alsa.enable = lib.mkDefault true;
    alsa.support32Bit = true;
    pulse.enable = lib.mkDefault true;
  };

  programs.home-manager.enable = lib.mkDefault true;
}
```

### Key Points
- Imports base.nix and modules/home
- Enables GDM display manager
- Enables GNOME desktop
- Enables X server with US keymap
- Enables pipewire with ALSA and pulse
- Enables home-manager

---

## File: ./.gitignore

### Content (FULL)
```
# Nix
result
result-*
*.drv
*.nar

# direnv
.direnv

# editor
*.swp
*.swo
*~

# build outputs
哥 德巴赫
```

### Purpose
Ignores Nix build outputs, direnv files, editor temp files, and build outputs.
