{
  pkgs,
  lib,
}:
let
  renderer = import ../pkgs/dwl-scroll/config.nix { inherit lib; };
  inherit (renderer) defaults;
  filled = defaults // {
    commands = {
      terminal = [ pkgs.alacritty ];
      launcher = [ pkgs.fuzzel ];
      locker = [ pkgs.swaylock ];
    };
  };
  package = pkgs.callPackage ../pkgs/dwl-scroll {
    settings = filled;
  };
  niri = import ../pkgs/dwl-scroll/niri-keybinds.nix { inherit pkgs; };
  niriSettings = lib.recursiveUpdate defaults niri;
  bar = import ../pkgs/dwl-scroll/bar.nix {
    inherit pkgs;
    settings = niriSettings;
  };
  tray = import ../pkgs/dwl-scroll/tray.nix {
    inherit pkgs;
    settings = lib.recursiveUpdate niriSettings { colors.root = "112233"; };
    timezone = "Etc/UTC";
  };
  rpcTestId = "123456789012345678";
  niriPackage = pkgs.callPackage ../pkgs/dwl-scroll {
    settings = lib.recursiveUpdate niri {
      discordRpc = {
        enable = true;
        clientId = rpcTestId;
        showApp = true;
      };
    };
  };
  bindings = niri.keybinds ++ niri.extraKeybinds;
  signature =
    b:
    builtins.toJSON [
      (lib.sort builtins.lessThan b.mods)
      b.key
    ];
  signatures = map signature bindings;
  hasBind =
    mods: key: action:
    lib.any (b: signature b == signature { inherit mods key; } && b.action == action) bindings;
  rendered = renderer.render niriSettings;
  defaultRendered = renderer.render filled;
  mediaKeys = [
    "XF86AudioLowerVolume"
    "XF86AudioRaiseVolume"
    "XF86AudioMute"
    "XF86AudioMicMute"
    "XF86AudioPlay"
    "XF86AudioNext"
    "XF86AudioPrev"
    "XF86AudioStop"
    "XF86MonBrightnessUp"
    "XF86MonBrightnessDown"
    "Print"
  ];
in
assert lib.all (key: lib.hasInfix "{ 0, XKB_KEY_${key}, spawn," defaultRendered) mediaKeys;
assert niri.modkey == { logo = true; };
assert lib.length signatures == lib.length (lib.unique signatures);
assert hasBind [ "logo" ] "Return" "spawn";
assert hasBind [ "logo" ] "d" "showlauncher";
assert hasBind [ "logo" ] "w" "killclient";
assert hasBind [ "logo" ] "v" "togglefloating";
assert hasBind [ "logo" ] "f" "scrollmaximize";
assert hasBind [ "logo" "shift" ] "f" "togglefullscreen";
assert lib.all (key: hasBind [ "logo" "ctrl" ] key "scrollmovecolumn") [
  "h"
  "l"
  "Left"
  "Right"
];
assert lib.all (key: hasBind [ "logo" "ctrl" ] key "scrollmovewindow") [
  "j"
  "k"
  "Up"
  "Down"
];
assert lib.all (key: hasBind [ "logo" "shift" ] key "focusmon") [
  "h"
  "j"
  "k"
  "l"
  "Left"
  "Down"
  "Up"
  "Right"
];
assert lib.all (
  n:
  hasBind [ "logo" ] (toString n) "view"
  && hasBind [ "logo" "ctrl" ] (toString n) "tag"
  && hasBind [ "logo" "shift" ] (toString n) "tag"
) (lib.range 1 9);
assert lib.all (key: hasBind [ ] key "spawn") [
  "XF86AudioRaiseVolume"
  "XF86AudioPlay"
  "XF86MonBrightnessUp"
  "Print"
];
assert lib.hasInfix "#define MODKEY WLR_MODIFIER_LOGO\n" rendered;
assert lib.hasInfix "static const float fullscreen_bg[] = COLOR(0x000000ff);" rendered;
assert !renderer.defaults.discordRpc.enable && !renderer.defaults.discordRpc.showApp;
assert !(builtins.tryEval (renderer.render { discordRpc.enable = true; })).success;
assert
  !(builtins.tryEval (renderer.render { discordRpc.clientId = "not-an-application-id"; })).success;
pkgs.runCommand "dwl-scroll-settings"
  {
    nativeBuildInputs = with pkgs; [
      dbus
      fontconfig
      foot
      wtype
      wlr-randr
      grim
      (python3.withPackages (ps: [ ps.pillow ]))
    ];
    FONTCONFIG_FILE = pkgs.makeFontsConf {
      fontDirectories = [
        pkgs.iosevka
        pkgs.nerd-fonts.symbols-only
      ];
    };
    DWL_BAR_COLORS = builtins.toJSON niriSettings.colors;
    DWL_TRAY_TEST_BACKGROUND = "112233";
    TZDIR = "${pkgs.tzdata}/share/zoneinfo";
    DWL_TEST_LOCKER = "${
      import ../pkgs/dwl-scroll/lock-test.nix { inherit pkgs; }
    }/bin/dwl-scroll-test-locker";
  }
  ''
    export HOME="$TMPDIR"
    python3 ${../pkgs/dwl-scroll/status_test.py} ${../pkgs/dwl-scroll/status.py}
    test "$(fc-match -f '%{family}' Iosevka)" = Iosevka
    fc-match -f '%{family}' 'Iosevka,Symbols Nerd Font Mono:size=10:charset=f2db' | grep -F 'Symbols Nerd Font'
    fc-match -f '%{family}' 'Iosevka,Symbols Nerd Font Mono:size=10:charset=f035b' | grep -F 'Symbols Nerd Font'
    python3 ${../pkgs/dwl-scroll/smoke.py} ${package}
    DWL_TEST_DISCORD_RPC="${rpcTestId}" python3 ${../pkgs/dwl-scroll/smoke.py} ${niriPackage} niri ${lib.getExe bar} ${lib.getExe tray}
    touch "$out"
  ''
