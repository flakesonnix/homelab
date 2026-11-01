# p53's Niri shortcuts, with Alt replaced by Super. Only supported dwl actions
# are bound; this does not add Niri's overview/dynamic workspace/layout features.
{pkgs}: let
  inherit (pkgs) lib;
  bind = mods: key: action: arg: {inherit mods key action arg;};
  super = bind ["logo"];
  ctrl = bind ["logo" "ctrl"];
  shift = bind ["logo" "shift"];
  ctrlShift = bind ["logo" "ctrl" "shift"];
  spawn = mods: key: argv: bind mods key "spawn" {v = argv;};
  media = key: argv: spawn [] key argv;
  directions = [
    {
      keys = ["Left" "h"];
      direction = "left";
      axis = "column";
      step = -1;
    }
    {
      keys = ["Right" "l"];
      direction = "right";
      axis = "column";
      step = 1;
    }
    {
      keys = ["Up" "k"];
      direction = "up";
      axis = "window";
      step = -1;
    }
    {
      keys = ["Down" "j"];
      direction = "down";
      axis = "window";
      step = 1;
    }
  ];
  screenshot = pkgs.writeShellApplication {
    name = "dwl-screenshot";
    runtimeInputs = with pkgs; [coreutils grim slurp];
    text = ''
      directory="$HOME/Pictures/Screenshots"
      mkdir -p "$directory"
      destination="$directory/Screenshot from $(date '+%Y-%m-%d %H-%M-%S-%N').png"
      if [ "''${1:-area}" = screen ]; then
        grim "$destination"
      else
        geometry=$(slurp)
        grim -g "$geometry" "$destination"
      fi
    '';
  };
  wpctl = lib.getExe' pkgs.wireplumber "wpctl";
in {
  modkey = {logo = true;};
  commands = {
    terminal = [(lib.getExe pkgs.alacritty)];
    launcher = [(lib.getExe pkgs.fuzzel)];
    locker = [(lib.getExe pkgs.swaylock)];
  };
  keybinds =
    [
      (super "Return" "spawn" {v = "termcmd";})
      (super "d" "showlauncher" null)
      (ctrl "Escape" "spawn" {v = "lockcmd";})
      (spawn ["logo" "shift"] "a" [(lib.getExe pkgs.pwvucontrol)])
      (super "w" "killclient" null)
      (super "v" "togglefloating" null)
      (super "f" "scrollmaximize" null)
      (shift "f" "togglefullscreen" null)
      (super "r" "scrollpreset" null)
      (super "minus" "scrollwidth" {f = -0.1;})
      (super "equal" "scrollwidth" {f = 0.1;})
      # Expel into a new right-hand column, as in Niri.
      (super "period" "scrollsplit" {i = 1;})
      (shift "e" "quit" null)
      (ctrl "Delete" "quit" null)
      (media "XF86AudioRaiseVolume" [wpctl "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1+" "-l" "1.0"])
      (media "XF86AudioLowerVolume" [wpctl "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1-"])
      (media "XF86AudioMute" [wpctl "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"])
      (media "XF86AudioMicMute" [wpctl "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"])
      (media "XF86AudioPlay" [(lib.getExe pkgs.playerctl) "play-pause"])
      (media "XF86AudioStop" [(lib.getExe pkgs.playerctl) "stop"])
      (media "XF86AudioPrev" [(lib.getExe pkgs.playerctl) "previous"])
      (media "XF86AudioNext" [(lib.getExe pkgs.playerctl) "next"])
      (media "XF86MonBrightnessUp" [(lib.getExe pkgs.brightnessctl) "--class=backlight" "set" "+10%"])
      (media "XF86MonBrightnessDown" [(lib.getExe pkgs.brightnessctl) "--class=backlight" "set" "10%-"])
      (media "Print" [(lib.getExe screenshot) "area"])
      (spawn ["ctrl"] "Print" [(lib.getExe screenshot) "screen"])
      (spawn ["logo" "shift"] "s" [(lib.getExe screenshot) "area"])
      (spawn ["logo" "ctrl" "shift"] "s" [(lib.getExe screenshot) "screen"])
      # Toggle so the same shortcut can turn displays back on in dwl.
      (spawn ["logo" "shift"] "p" [(lib.getExe pkgs.wlopm) "--toggle" "*"])
    ]
    ++ lib.concatMap (d:
      lib.concatMap (key: [
        (super key "scrollfocus${d.axis}" {i = d.step;})
        (ctrl key "scrollmove${d.axis}" {i = d.step;})
        (shift key "focusmon" {direction = d.direction;})
        # dwl moves the focused window, not the entire column, across outputs.
        (ctrlShift key "tagmon" {direction = d.direction;})
      ])
      d.keys)
    directions
    ++ lib.concatMap (n: [
      (super (toString n) "view" {tag = n - 1;})
      # Like output transfers, dwl's tag action moves the focused window only.
      (ctrl (toString n) "tag" {tag = n - 1;})
      (shift (toString n) "tag" {tag = n - 1;})
    ]) (lib.range 1 9)
    ++ map (n: bind ["ctrl" "alt"] "F${toString n}" "chvt" {ui = n;}) (lib.range 1 12);

  # Keep dwl-only management actions off the copied Niri combinations.
  extraKeybinds = [
    (super "Tab" "view" null)
    (super "0" "view" {all = true;})
    (bind ["logo" "alt"] "h" "scrollpan" {i = -1;})
    (bind ["logo" "alt"] "l" "scrollpan" {i = 1;})
    (bind ["logo" "alt"] "i" "scrollsetinsert" {i = 2;})
    (bind ["logo" "alt"] "Return" "scrollmerge" {i = 1;})
    (bind ["logo" "alt" "shift"] "Return" "scrollmerge" {i = -1;})
    (bind ["logo" "alt"] "bracketleft" "scrolltransfer" {i = -1;})
    (bind ["logo" "alt"] "bracketright" "scrolltransfer" {i = 1;})
    (bind ["logo" "alt"] "s" "setlayout" {layout = 0;})
    (bind ["logo" "alt"] "t" "setlayout" {layout = 1;})
    (bind ["logo" "alt"] "v" "setlayout" {layout = 2;})
    (bind ["logo" "alt"] "m" "setlayout" {layout = 3;})
  ];

  # Disable continuous panning so it cannot swallow the copied wheel bindings.
  wheel.mod = "none";
  axes = [
    {
      mods = ["logo"];
      dir = "left";
      action = "scrollfocuscolumn";
      arg.i = -1;
    }
    {
      mods = ["logo"];
      dir = "right";
      action = "scrollfocuscolumn";
      arg.i = 1;
    }
    {
      mods = ["logo" "ctrl"];
      dir = "left";
      action = "scrollmovecolumn";
      arg.i = -1;
    }
    {
      mods = ["logo" "ctrl"];
      dir = "right";
      action = "scrollmovecolumn";
      arg.i = 1;
    }
    {
      mods = ["logo" "shift"];
      dir = "up";
      action = "scrollfocuscolumn";
      arg.i = -1;
    }
    {
      mods = ["logo" "shift"];
      dir = "down";
      action = "scrollfocuscolumn";
      arg.i = 1;
    }
    {
      mods = ["logo" "ctrl" "shift"];
      dir = "up";
      action = "scrollmovecolumn";
      arg.i = -1;
    }
    {
      mods = ["logo" "ctrl" "shift"];
      dir = "down";
      action = "scrollmovecolumn";
      arg.i = 1;
    }
  ];
}
