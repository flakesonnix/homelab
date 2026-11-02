{
  pkgs,
  self,
}:
let
  inherit (pkgs) lib;
  eval =
    modules:
    (import "${pkgs.path}/nixos/lib/eval-config.nix" {
      system = pkgs.stdenv.hostPlatform.system;
      modules = [ { system.stateVersion = "26.05"; } ] ++ modules;
    }).config;
  disabled = eval [ ../modules/nixos/dwl-scroll.nix ];
  both = eval [
    ../modules/nixos/dwl-scroll.nix
    {
      lucy.dwlScroll.enable = true;
      programs.dwl.enable = true;
    }
  ];
  p53 =
    (self.nixosConfigurations.p53.extendModules {
      modules = [ { lucy.dwlScroll.enable = lib.mkForce false; } ];
    }).config;
  mireo = self.nixosConfigurations.mireo.config;
  enabled =
    (self.nixosConfigurations.p53.extendModules {
      modules = [ { lucy.dwlScroll.enable = lib.mkForce true; } ];
    }).config;
  provides = name: package: lib.elem name (package.providedSessions or [ ]);
  session =
    lib.findFirst (provides "dwl-scroll") (throw "dwl-scroll session missing")
      enabled.services.displayManager.sessionPackages;
  custom = eval [
    ../modules/nixos/dwl-scroll.nix
    {
      lucy.dwlScroll = {
        enable = true;
        settings.colors = {
          fullscreenBg = "123456";
          root = "102030";
          border = "405060";
          focus = "abcdef80";
          urgent = "ff1234";
        };
        settings.commands.launcher = [ "custom-launcher" ];
      };
    }
  ];
  customSession =
    lib.findFirst (provides "dwl-scroll") (throw "custom dwl-scroll session missing")
      custom.services.displayManager.sessionPackages;
  rejectsSettings =
    settings:
    !(builtins.tryEval (
      builtins.deepSeq
        (eval [
          ../modules/nixos/dwl-scroll.nix
          { lucy.dwlScroll.settings = settings; }
        ]).lucy.dwlScroll.settings
        true
    )).success;
in
assert !disabled.lucy.dwlScroll.enable;
assert disabled.services.displayManager.sessionPackages == [ ];
assert !(disabled.systemd.user.services ? dwl-scroll-status);
assert !(disabled.systemd.user.services ? dwl-scroll-tray);
assert !p53.lucy.dwlScroll.enable && !mireo.lucy.dwlScroll.enable;
assert !lib.any (provides "dwl-scroll") p53.services.displayManager.sessionPackages;
assert !lib.any (provides "dwl-scroll") mireo.services.displayManager.sessionPackages;
assert lib.all (
  p: lib.elem p enabled.services.displayManager.sessionPackages
) p53.services.displayManager.sessionPackages;
assert enabled.services.displayManager.gdm.enable == p53.services.displayManager.gdm.enable;
assert enabled.services.displayManager.defaultSession == p53.services.displayManager.defaultSession;
assert enabled.programs.dwl.enable == p53.programs.dwl.enable;
assert enabled.programs.sway.package == p53.programs.sway.package;
assert enabled.programs.ewm.package == p53.programs.ewm.package;
assert builtins.isString enabled.system.build.toplevel.drvPath;
assert !enabled.services.greetd.enable && !enabled.services.displayManager.sddm.enable;
assert enabled.xdg.portal.config.dwl-scroll."org.freedesktop.impl.portal.ScreenCast" == "wlr";
assert enabled.systemd.user.services.dwl-scroll-polkit.partOf == [ "dwl-scroll-session.target" ];
assert lib.all
  (
    name:
    let
      unit = enabled.systemd.user.services.${name};
    in
    unit.wantedBy == [ "dwl-scroll-session.target" ]
    && unit.requisite == [ "dwl-scroll-session.target" ]
    && unit.partOf == [ "dwl-scroll-session.target" ]
    && lib.elem "dwl-scroll-session.target" unit.after
    &&
      unit.unitConfig.ConditionEnvironment == [
        "XDG_CURRENT_DESKTOP=dwl-scroll"
        "WAYLAND_DISPLAY"
      ]
  )
  [
    "dwl-scroll-status"
    "dwl-scroll-tray"
    "dwl-scroll-nm-applet"
  ];
assert
  enabled.systemd.user.services.dwl-scroll-nm-applet.serviceConfig.ExecStart
  == "${lib.getExe pkgs.networkmanagerapplet} --indicator";
assert lib.elem pkgs.dwlb enabled.environment.systemPackages;
assert lib.hasInfix "--mode fill --image /home/lucy/Pictures/wallpaper.webp &"
  enabled.lucy.dwlScroll.startupCommands;
assert lib.any (provides "dwl") both.services.displayManager.sessionPackages;
assert lib.any (provides "dwl-scroll") both.services.displayManager.sessionPackages;
assert both.programs.dwl.package.drvPath == pkgs.dwl.drvPath;
assert custom.lucy.dwlScroll.settings.scroll.width == 0.55;
assert custom.lucy.dwlScroll.settings.colors.fullscreenBg == "123456";
assert enabled.lucy.dwlScroll.settings.modkey.logo;
assert !enabled.lucy.dwlScroll.settings.modkey.alt;
assert !custom.lucy.dwlScroll.settings.discordRpc.enable;
assert enabled.lucy.dwlScroll.settings.discordRpc.enable;
assert enabled.lucy.dwlScroll.settings.discordRpc.showApp;
assert enabled.lucy.dwlScroll.settings.discordRpc.clientId == "1566412441414410262";
assert rejectsSettings { scroll.width = "not-a-float"; };
assert rejectsSettings { modkey.logo = "not-a-boolean"; };
assert rejectsSettings { unknownSetting = true; };
assert rejectsSettings { discordRpc.clientId = "not-an-application-id"; };
assert rejectsSettings { discordRpc.showApp = "not-a-boolean"; };
pkgs.runCommand "dwl-scroll-module-check" { } ''
  test -x ${lib.getExe enabled.lucy.dwlScroll.package}
  test -x ${lib.getExe custom.lucy.dwlScroll.package}
  grep -q '^DesktopNames=dwl-scroll$' ${session}/share/wayland-sessions/dwl-scroll.desktop
  test -e ${pkgs.dwl}/share/wayland-sessions/dwl.desktop
  test ! -e ${enabled.lucy.dwlScroll.package}/share/wayland-sessions/dwl.desktop
  wrapper=$(sed -n 's/^Exec=//p' ${session}/share/wayland-sessions/dwl-scroll.desktop)
  ${pkgs.bash}/bin/bash -n "$wrapper"
  grep -q 'unset-environment' "$wrapper"
  startup=$(sed -n 's/.* -s \([^ ]*\) &$/\1/p' "$wrapper")
  test -n "$startup"
  ${pkgs.bash}/bin/bash -n "$startup"
  bar=$(sed -n 's/^exec \([^ ]*\)$/\1/p' "$startup")
  test -x "$bar"
  ${pkgs.bash}/bin/bash -n "$bar"
  grep -Fq '${lib.getExe pkgs.dwlb}' "$bar"
  grep -Fq -- "-font 'Iosevka,Symbols Nerd Font Mono:size=10'" "$bar"
  grep -Fq -- '-no-status-commands' "$bar"
  grep -Fq -- '-active-bg-color ${enabled.lucy.dwlScroll.settings.colors.focus}' "$bar"
  grep -Fq -- '-inactive-bg-color ${enabled.lucy.dwlScroll.settings.colors.root}' "$bar"
  grep -Fq -- '-occupied-bg-color ${enabled.lucy.dwlScroll.settings.colors.border}' "$bar"
  grep -Fq -- '-urgent-bg-color ${enabled.lucy.dwlScroll.settings.colors.urgent}' "$bar"
  grep -Fq '${lib.getExe pkgs.swaybg} --mode fill --image /home/lucy/Pictures/wallpaper.webp &' "$startup"
  custom_wrapper=$(sed -n 's/^Exec=//p' ${customSession}/share/wayland-sessions/dwl-scroll.desktop)
  custom_startup=$(sed -n 's/.* -s \([^ ]*\) &$/\1/p' "$custom_wrapper")
  custom_bar=$(sed -n 's/^exec \([^ ]*\)$/\1/p' "$custom_startup")
  grep -Fq -- '-active-bg-color abcdef80' "$custom_bar"
  grep -Fq -- '-inactive-bg-color 102030' "$custom_bar"
  grep -Fq -- '-occupied-bg-color 405060' "$custom_bar"
  grep -Fq -- '-urgent-bg-color ff1234' "$custom_bar"
  test -x ${enabled.systemd.user.services.dwl-scroll-tray.serviceConfig.ExecStart}
  ${pkgs.bash}/bin/bash -n ${enabled.systemd.user.services.dwl-scroll-status.serviceConfig.ExecStart}
  ${pkgs.bash}/bin/bash -n ${enabled.systemd.user.services.dwl-scroll-tray.serviceConfig.ExecStart}
  tray_config=$(sed -n 's/.* --config \([^ ]*\) --style .*/\1/p' ${enabled.systemd.user.services.dwl-scroll-tray.serviceConfig.ExecStart})
  grep -Fq '"position":"top"' "$tray_config"
  grep -Fq '"exclusive":false' "$tray_config"
  grep -Fq '"modules-right":["tray","clock"]' "$tray_config"
  grep -Fq '"format":" {:%H:%M}"' "$tray_config"
  grep -Fq '"tooltip-format":"{:%d.%m.%Y}"' "$tray_config"
  touch "$out"
''
