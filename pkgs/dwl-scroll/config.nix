# Nix-rendered dwl-scroll configuration (dwl 0.9 / wlroots 0.20).
# `render` turns a settings attrset into the complete C config header that the
# package feeds to dwl's `configH`. It mirrors the static fallback
# `pkgs/dwl-scroll/config.h`; both must stay semantically identical. Values are
# validated here with precise errors instead of elaborate type unions.
# A binding arg renders from exactly one of:
#   { i | ui | f | v | direction | cursor | layout | tag | all }
#  .i/.ui/.f plain literals, .v = "cmdArrayName" or [ argv list ],
#  .direction = left/right/up/down, .cursor = move/resize,
#  .layout = layouts index, .tag = tag mask, .all = true (whole tag set).
{ lib }:
let
  inherit (builtins) head match;
  inherit (lib)
    concatStringsSep
    filter
    length
    map
    optionalString
    toUpper
    ;
  inherit (lib.strings) escape;

  throwC = where: msg: throw "dwl-scroll config ${where}: ${msg}";

  # ----- C helpers -----------------------------------------------------------

  cBool =
    where: b:
    if b == true then
      "1"
    else if b == false then
      "0"
    else
      throwC where "expected a boolean, got ${toString b}";

  # Nix floats print with 6 decimals; normalize trailing zeros for readability.
  cFloat =
    where: v:
    if !lib.isFloat v then
      throwC where "expected a float, got ${toString v}"
    else
      let
        go = t: if lib.hasSuffix "0" t && lib.hasInfix "." t then go (lib.removeSuffix "0" t) else t;
        stripped = go (toString v);
        fixed = if lib.hasSuffix "." stripped then lib.removeSuffix "." stripped + ".0" else stripped;
      in
      "${fixed}f";

  cHex =
    where: v:
    let
      h = if lib.isString v then toUpper (lib.removePrefix "#" v) else "";
    in
    if match "[0-9A-F]{6}([0-9A-F]{2})?" h == null then
      throwC where "expected 6 or 8 hex digits (rgb/argb), got ${toString v}"
    else
      "COLOR(0x${h}${optionalString (lib.stringLength h == 6) "ff"})";

  cIdent =
    where: v:
    if lib.isString v && match "[A-Za-z_][A-Za-z0-9_]*" v != null then
      v
    else
      throwC where "expected a C identifier, got ${toString v}";

  keysym =
    where: v:
    if lib.isString v && match "[A-Za-z0-9_]+" v != null then
      "XKB_KEY_${v}"
    else
      throwC where "expected an XKB keysym suffix (letters/digits/underscore), got ${toString v}";

  # C string literal with standard escapes applied.
  cStr =
    where: v:
    if !lib.isString v then
      throwC where "expected a string, got ${toString v}"
    else
      "\"${escape [ "\\" "\"" "\n" "\t" "\r" ] v}\"";

  # ----- modifiers -----------------------------------------------------------

  modNames = [
    "shift"
    "caps"
    "ctrl"
    "alt"
    "mod2"
    "mod3"
    "logo"
    "mod5"
  ];
  modC = n: "WLR_MODIFIER_${toUpper n}";

  # Attrset { logo = true; } -> sorted enabled modifier names.
  modsOfAttrset =
    where: a:
    if !lib.isAttrs a then
      throwC where "expected an attribute set of modifier booleans (e.g. { logo = true; })"
    else
      let
        bad = filter (n: !(lib.elem n modNames)) (lib.attrNames a);
      in
      if bad != [ ] then
        throwC where "unknown modifier(s): ${concatStringsSep "," bad} (allowed: ${concatStringsSep "," modNames})"
      else
        filter (n: a."${n}" or false == true) modNames;

  modsList =
    where: l:
    if !lib.isList l then
      throwC where "expected a list of modifiers"
    else
      let
        bad = filter (m: !(lib.elem m modNames)) l;
      in
      if bad != [ ] then
        throwC where "unknown modifier(s): ${concatStringsSep "," (map toString bad)} (allowed: ${concatStringsSep "," modNames})"
      else
        filter (n: lib.elem n l) modNames; # sorted + deduped

  # ----- option type shorthands ----------------------------------------------

  modsSub = lib.types.submodule {
    options = lib.genAttrs modNames (
      _:
      lib.mkOption {
        type = lib.types.bool;
        default = false;
      }
    );
  };
in
rec {
  # Semantic mirror of the static fallback header (pkgs/dwl-scroll/config.h).
  defaults = {
    sloppyfocus = false;
    bypassSurfaceVisibility = false;
    borderpx = 2;
    snap = 32;
    colors = {
      root = "181825";
      border = "45475a";
      focus = "c69bff";
      urgent = "f38ba8";
      fullscreenBg = "000000";
    };
    tags = 9;
    log = {
      level = "error";
    };
    discordRpc = {
      enable = false;
      clientId = null;
      showApp = false;
    };
    rules = [ { } ];
    scroll = {
      width = 0.55;
      widths = [
        0.33
        0.5
        0.67
        1.0
      ];
      columnGap = 12;
      windowGap = 8;
      padding = 12;
      center = false;
      insert = "right"; # left | current | right
      step = 160;
    };
    modkey = {
      logo = true;
    };
    wheel = {
      mod = "modkey"; # modkey | none | modifier attrset
      scale = 2.0;
    };
    layouts = [
      {
        symbol = "|||";
        arrange = "scrolling";
      }
      {
        symbol = "[]=";
        arrange = "tile";
      }
      {
        symbol = "><>";
        arrange = "floating";
      }
      {
        symbol = "[M]";
        arrange = "monocle";
      }
    ];
    monrules = [
      {
        name = null;
        mfact = 0.55;
        nmaster = 1;
        scale = 1.0;
        layout = 0;
        transform = "normal";
        x = -1;
        y = -1;
      }
    ];
    xkb = {
      rules = null;
      model = null;
      layout = null;
      variant = null;
      options = null;
    };
    repeat = {
      rate = 25;
      delay = 600;
    };
    input = {
      tapToClick = true;
      tapAndDrag = true;
      dragLock = false;
      naturalScrolling = true;
      disableWhileTyping = true;
      leftHanded = false;
      middleButtonEmulation = false;
      scrollMethod = "2fg";
      clickMethod = "clickfinger";
      sendEvents = "enabled";
      accelProfile = "adaptive";
      accelSpeed = 0.0;
      tapButtonMap = "lrm";
    };
    commands = {
      terminal = null; # argv list; falls back to the alacritty store path
      launcher = null; # argv list; falls back to the fuzzel store path
      locker = null; # argv list; falls back to the swaylock store path
    };
    keybinds = [
      # Media keys - show notifications and perform actions
      {
        mods = [ ];
        key = "XF86AudioLowerVolume";
        action = "spawn";
        arg = {
          v = [
            "sh"
            "-c"
            "notify-send 'Volume Down' -t 1000 && wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1- -l 1.0"
          ];
        };
      }
      {
        mods = [ ];
        key = "XF86AudioRaiseVolume";
        action = "spawn";
        arg = {
          v = [
            "sh"
            "-c"
            "notify-send 'Volume Up' -t 1000 && wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0"
          ];
        };
      }
      {
        mods = [ ];
        key = "XF86AudioMute";
        action = "spawn";
        arg = {
          v = [
            "sh"
            "-c"
            "notify-send 'Volume Mute' -t 1000 && wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
          ];
        };
      }
      {
        mods = [ ];
        key = "XF86AudioMicMute";
        action = "spawn";
        arg = {
          v = [
            "sh"
            "-c"
            "notify-send 'Mic Mute' -t 1000 && wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
          ];
        };
      }
      {
        mods = [ ];
        key = "XF86AudioPlay";
        action = "spawn";
        arg = {
          v = [
            "sh"
            "-c"
            "notify-send 'Play/Pause' -t 1000 && playerctl play-pause"
          ];
        };
      }
      {
        mods = [ ];
        key = "XF86AudioNext";
        action = "spawn";
        arg = {
          v = [
            "sh"
            "-c"
            "notify-send 'Next Track' -t 1000 && playerctl next"
          ];
        };
      }
      {
        mods = [ ];
        key = "XF86AudioPrev";
        action = "spawn";
        arg = {
          v = [
            "sh"
            "-c"
            "notify-send 'Previous Track' -t 1000 && playerctl previous"
          ];
        };
      }
      {
        mods = [ ];
        key = "XF86AudioStop";
        action = "spawn";
        arg = {
          v = [
            "sh"
            "-c"
            "notify-send 'Stop' -t 1000 && playerctl stop"
          ];
        };
      }
      {
        mods = [ ];
        key = "XF86MonBrightnessUp";
        action = "spawn";
        arg = {
          v = [
            "sh"
            "-c"
            "notify-send 'Brightness Up' -t 1000 && brightnessctl --class=backlight set '+10%'"
          ];
        };
      }
      {
        mods = [ ];
        key = "XF86MonBrightnessDown";
        action = "spawn";
        arg = {
          v = [
            "sh"
            "-c"
            "notify-send 'Brightness Down' -t 1000 && brightnessctl --class=backlight set '10%-'"
          ];
        };
      }
      {
        mods = [ ];
        key = "Print";
        action = "spawn";
        arg = {
          v = [
            "sh"
            "-c"
            "notify-send 'Screenshot' -t 1000 && grim -g $(slurp) \"$HOME/Pictures/Screenshots/Screenshot from $(date '+%Y-%m-%d %H-%M-%S-%N').png\""
          ];
        };
      }
      {
        mods = [ "logo" ];
        key = "h";
        action = "scrollfocuscolumn";
        arg = {
          i = -1;
        };
      }
      {
        mods = [ "logo" ];
        key = "l";
        action = "scrollfocuscolumn";
        arg = {
          i = 1;
        };
      }
      {
        mods = [ "logo" ];
        key = "k";
        action = "scrollfocuswindow";
        arg = {
          i = -1;
        };
      }
      {
        mods = [ "logo" ];
        key = "j";
        action = "scrollfocuswindow";
        arg = {
          i = 1;
        };
      }
      {
        mods = [
          "logo"
          "shift"
        ];
        key = "h";
        action = "scrollmovecolumn";
        arg = {
          i = -1;
        };
      }
      {
        mods = [
          "logo"
          "shift"
        ];
        key = "l";
        action = "scrollmovecolumn";
        arg = {
          i = 1;
        };
      }
      {
        mods = [
          "logo"
          "shift"
        ];
        key = "k";
        action = "scrollmovewindow";
        arg = {
          i = -1;
        };
      }
      {
        mods = [
          "logo"
          "shift"
        ];
        key = "j";
        action = "scrollmovewindow";
        arg = {
          i = 1;
        };
      }
      {
        mods = [
          "logo"
          "ctrl"
        ];
        key = "h";
        action = "scrollpan";
        arg = {
          i = -1;
        };
      }
      {
        mods = [
          "logo"
          "ctrl"
        ];
        key = "l";
        action = "scrollpan";
        arg = {
          i = 1;
        };
      }
      {
        mods = [
          "logo"
          "ctrl"
          "shift"
        ];
        key = "h";
        action = "scrolltransfer";
        arg = {
          i = -1;
        };
      }
      {
        mods = [
          "logo"
          "ctrl"
          "shift"
        ];
        key = "l";
        action = "scrolltransfer";
        arg = {
          i = 1;
        };
      }
      {
        mods = [ "logo" ];
        key = "Return";
        action = "spawn";
        arg = {
          v = "termcmd";
        };
      }
      {
        mods = [
          "logo"
          "ctrl"
        ];
        key = "Return";
        action = "scrollmerge";
        arg = {
          i = 1;
        };
      }
      {
        mods = [
          "logo"
          "ctrl"
          "shift"
        ];
        key = "Return";
        action = "scrollmerge";
        arg = {
          i = -1;
        };
      }
      {
        mods = [ "logo" ];
        key = "i";
        action = "scrollsetinsert";
        arg = {
          i = 2;
        };
      }
      {
        mods = [
          "logo"
          "ctrl"
        ];
        key = "bracketleft";
        action = "scrollsetinsert";
        arg = {
          i = -1;
        };
      }
      {
        mods = [
          "logo"
          "ctrl"
        ];
        key = "bracketright";
        action = "scrollsetinsert";
        arg = {
          i = 1;
        };
      }
      {
        mods = [ "logo" ];
        key = "bracketleft";
        action = "scrollwidth";
        arg = {
          f = -0.05;
        };
      }
      {
        mods = [ "logo" ];
        key = "bracketright";
        action = "scrollwidth";
        arg = {
          f = 0.05;
        };
      }
      {
        mods = [ "logo" ];
        key = "r";
        action = "scrollpreset";
      }
      {
        mods = [
          "logo"
          "shift"
        ];
        key = "Return";
        action = "scrollsplit";
        arg = {
          i = 1;
        };
      }
      {
        mods = [ "logo" ];
        key = "d";
        action = "showlauncher";
      }
      {
        mods = [ "logo" ];
        key = "q";
        action = "killclient";
      }
      {
        mods = [
          "logo"
          "shift"
        ];
        key = "space";
        action = "togglefloating";
      }
      {
        mods = [ "logo" ];
        key = "f";
        action = "togglefullscreen";
      }
      {
        mods = [
          "logo"
          "ctrl"
        ];
        key = "Escape";
        action = "spawn";
        arg = {
          v = "lockcmd";
        };
      }
      {
        mods = [
          "logo"
          "shift"
        ];
        key = "e";
        action = "quit";
      }
      {
        mods = [ "logo" ];
        key = "s";
        action = "setlayout";
        arg = {
          layout = 0;
        };
      }
      {
        mods = [ "logo" ];
        key = "t";
        action = "setlayout";
        arg = {
          layout = 1;
        };
      }
      {
        mods = [ "logo" ];
        key = "v";
        action = "setlayout";
        arg = {
          layout = 2;
        };
      }
      {
        mods = [ "logo" ];
        key = "m";
        action = "setlayout";
        arg = {
          layout = 3;
        };
      }
      {
        mods = [
          "logo"
          "ctrl"
        ];
        key = "j";
        action = "focusstack";
        arg = {
          i = 1;
        };
      }
      {
        mods = [
          "logo"
          "ctrl"
        ];
        key = "k";
        action = "focusstack";
        arg = {
          i = -1;
        };
      }
      {
        mods = [
          "logo"
          "ctrl"
        ];
        key = "equal";
        action = "incnmaster";
        arg = {
          i = 1;
        };
      }
      {
        mods = [
          "logo"
          "ctrl"
        ];
        key = "minus";
        action = "incnmaster";
        arg = {
          i = -1;
        };
      }
      {
        mods = [
          "logo"
          "ctrl"
        ];
        key = "comma";
        action = "setmfact";
        arg = {
          f = -0.05;
        };
      }
      {
        mods = [
          "logo"
          "ctrl"
        ];
        key = "period";
        action = "setmfact";
        arg = {
          f = 0.05;
        };
      }
      {
        mods = [
          "logo"
          "ctrl"
        ];
        key = "z";
        action = "zoom";
      }
      {
        mods = [ "logo" ];
        key = "Tab";
        action = "view";
      }
      {
        mods = [ "logo" ];
        key = "0";
        action = "view";
        arg = {
          all = true;
        };
      }
      {
        mods = [ "logo" ];
        key = "comma";
        action = "focusmon";
        arg = {
          direction = "left";
        };
      }
      {
        mods = [ "logo" ];
        key = "period";
        action = "focusmon";
        arg = {
          direction = "right";
        };
      }
      {
        mods = [
          "logo"
          "shift"
        ];
        key = "comma";
        action = "tagmon";
        arg = {
          direction = "left";
        };
      }
      {
        mods = [
          "logo"
          "shift"
        ];
        key = "period";
        action = "tagmon";
        arg = {
          direction = "right";
        };
      }
      { tag = 0; }
      { tag = 1; }
      { tag = 2; }
      { tag = 3; }
      { tag = 4; }
      { tag = 5; }
      { tag = 6; }
      { tag = 7; }
      { tag = 8; }
    ]
    ++ map (n: {
      mods = [
        "ctrl"
        "alt"
      ];
      key = "F${toString n}";
      action = "chvt";
      arg = {
        ui = n;
      };
    }) (lib.range 1 12);
    buttons = [
      {
        mods = [ "logo" ];
        button = "left";
        action = "moveresize";
        arg = {
          cursor = "move";
        };
      }
      {
        mods = [ "logo" ];
        button = "right";
        action = "moveresize";
        arg = {
          cursor = "resize";
        };
      }
      {
        mods = [ "logo" ];
        button = "middle";
        action = "togglefloating";
      }
    ];
    axes = [ ]; # zero row emitted; add plain dwl Axis bindings as needed
    extraKeybinds = [ ];
    extraButtons = [ ];
    extraAxes = [ ];
    extraConfig = "";
  };

  # Typed option tree consumed by modules/nixos/dwl-scroll.nix.
  options =
    with lib;
    with lib.types;
    {
      sloppyfocus = mkOption {
        type = bool;
        default = defaults.sloppyfocus;
        description = "Assign focus to the window under the pointer (dwl's sloppyfocus).";
      };
      bypassSurfaceVisibility = mkOption {
        type = bool;
        default = defaults.bypassSurfaceVisibility;
        description = "Also focus surfaces hidden under other windows (dwl's bypass_surface_visibility).";
      };
      borderpx = mkOption {
        type = ints.unsigned;
        default = defaults.borderpx;
        description = "Border pixel count.";
      };
      snap = mkOption {
        type = ints.unsigned;
        default = defaults.snap;
        description = "Floating snap distance (dwl 0.9).";
      };
      discordRpc = mkOption {
        type = submodule {
          options = {
            enable = mkOption {
              type = bool;
              default = defaults.discordRpc.enable;
              description = "Publish Discord Rich Presence via local IPC; never publishes window titles and clears while locked.";
            };
            clientId = mkOption {
              type = nullOr (strMatching "[0-9]{17,20}");
              default = defaults.discordRpc.clientId;
              description = "Public Discord application/client ID (not a token); required when enabled.";
            };
            showApp = mkOption {
              type = bool;
              default = defaults.discordRpc.showApp;
              description = "Also publish the focused application's name/ID. Opt-in disclosure; window titles are never read.";
            };
          };
        };
        default = defaults.discordRpc;
      };
      colors = mkOption {
        type = submodule {
          options = genAttrs [ "root" "border" "focus" "urgent" "fullscreenBg" ] (
            name:
            mkOption {
              type = strMatching "[0-9a-fA-F]{6}([0-9a-fA-F]{2})?";
              default = defaults.colors."${name}";
              description = "Color as 6-digit rgb or 8-digit argb hex, without the 0x prefix.";
            }
          );
        };
        default = defaults.colors;
      };
      tags = mkOption {
        type = ints.unsigned;
        default = defaults.tags;
        description = "TAGCOUNT (1..31). The TAGKEYS row group exists only for tags 0..8.";
      };
      log = mkOption {
        type = submodule {
          options.level = mkOption {
            type = enum [
              "error"
              "info"
              "debug"
            ];
            default = "error";
            description = "wlroots log verbosity.";
          };
        };
        default = defaults.log;
      };
      rules = mkOption {
        type = listOf (submodule {
          options = {
            app_id = mkOption {
              type = nullOr str;
              default = null;
              description = "Match the XDG shell app id (null matches all).";
            };
            title = mkOption {
              type = nullOr str;
              default = null;
              description = "Match the window title (null matches all).";
            };
            tags = mkOption {
              type = ints.unsigned;
              default = 0;
              description = "Tag mask; 0 keeps the currently selected tags.";
            };
            floating = mkOption {
              type = bool;
              default = false;
              description = "Start the client floating.";
            };
            monitor = mkOption {
              type = int;
              default = -1;
              description = "Monitor index; -1 keeps the focused monitor.";
            };
          };
        });
        default = defaults.rules;
        description = "Client rules in dwl's positional order: app_id, title, tags, floating, monitor.";
      };
      scroll = mkOption {
        type = submodule {
          options = {
            width = mkOption {
              type = float;
              default = defaults.scroll.width;
              description = "Default column width as a fraction of the padded usable area.";
            };
            widths = mkOption {
              type = nonEmptyListOf float;
              default = defaults.scroll.widths;
              description = "Cycling widths applied by scrollpreset.";
            };
            columnGap = mkOption {
              type = ints.unsigned;
              default = defaults.scroll.columnGap;
              description = "Gap between columns in pixels.";
            };
            windowGap = mkOption {
              type = ints.unsigned;
              default = defaults.scroll.windowGap;
              description = "Gap inside a column in pixels.";
            };
            padding = mkOption {
              type = ints.unsigned;
              default = defaults.scroll.padding;
              description = "Outer padding in pixels.";
            };
            center = mkOption {
              type = bool;
              default = defaults.scroll.center;
              description = "false: minimal reveal on focus change; true: center the focused column.";
            };
            insert = mkOption {
              type = enum [
                "left"
                "current"
                "right"
              ];
              default = defaults.scroll.insert;
              description = "Where new windows are inserted: left of, inside the focused, or right of the focused column.";
            };
            step = mkOption {
              type = ints.unsigned;
              default = defaults.scroll.step;
              description = "Keyboard pan distance in pixels (clamped to content).";
            };
          };
        };
        default = defaults.scroll;
      };
      modkey = mkOption {
        type = modsSub;
        default = {
          logo = true;
        };
        description = "Modifier mask for MODKEY; at least one modifier must be enabled.";
      };
      wheel = mkOption {
        type = submodule {
          options = {
            mod = mkOption {
              type = either (enum [
                "modkey"
                "none"
              ]) modsSub;
              default = "modkey";
              description = "Modifier that makes the wheel pan columns: \"modkey\" follows modkey, \"none\" disables compositor wheel handling, an attribute set selects modifiers.";
            };
            scale = mkOption {
              type = float;
              default = defaults.wheel.scale;
              description = "Continuous wheel delta to pixels multiplier.";
            };
          };
        };
        default = defaults.wheel;
      };
      layouts = mkOption {
        type = listOf (submodule {
          options = {
            symbol = mkOption {
              type = nullOr str;
              default = null;
              description = "Bar symbol, or null to fail the render with a precise message.";
            };
            arrange = mkOption {
              type = enum [
                "scrolling"
                "tile"
                "monocle"
                "floating"
              ];
              default = "scrolling";
              description = "Arrange function; floating maps to NULL (clients keep position).";
            };
          };
        });
        default = defaults.layouts;
        description = "Layout list; monrules reference entries by index.";
      };
      monrules = mkOption {
        type = listOf (submodule {
          options = {
            name = mkOption {
              type = nullOr str;
              default = null;
              description = "Match the output name (null matches all).";
            };
            mfact = mkOption {
              type = float;
              default = 0.55;
              description = "Tile master factor.";
            };
            nmaster = mkOption {
              type = ints.unsigned;
              default = 1;
              description = "Tile master window count.";
            };
            scale = mkOption {
              type = float;
              default = 1.0;
              description = "Scale applied to the monitor's surfaces.";
            };
            layout = mkOption {
              type = ints.unsigned;
              default = 0;
              description = "Index into layouts.";
            };
            transform = mkOption {
              type = enum [
                "normal"
                "90"
                "180"
                "270"
                "flipped"
                "flipped-90"
                "flipped-180"
                "flipped-270"
              ];
              default = "normal";
              description = "wl_output transform for the monitor.";
            };
            x = mkOption {
              type = int;
              default = -1;
              description = "Monitor x position; -1 keeps placement.";
            };
            y = mkOption {
              type = int;
              default = -1;
              description = "Monitor y position; -1 keeps placement.";
            };
          };
        });
        default = defaults.monrules;
      };
      xkb = mkOption {
        type = submodule {
          options = genAttrs [ "rules" "model" "layout" "variant" "options" ] (
            name:
            mkOption {
              type = nullOr str;
              default = null;
              description = "xkb_rule_names field; null keeps xkb defaults.";
            }
          );
        };
        default = defaults.xkb;
      };
      repeat = mkOption {
        type = submodule {
          options = {
            rate = mkOption {
              type = ints.positive;
              default = defaults.repeat.rate;
              description = "Keyboard repeat rate per second.";
            };
            delay = mkOption {
              type = ints.positive;
              default = defaults.repeat.delay;
              description = "Keyboard repeat delay in milliseconds.";
            };
          };
        };
        default = defaults.repeat;
      };
      input = mkOption {
        type = submodule {
          options = {
            tapToClick = mkOption {
              type = bool;
              default = defaults.input.tapToClick;
            };
            tapAndDrag = mkOption {
              type = bool;
              default = defaults.input.tapAndDrag;
            };
            dragLock = mkOption {
              type = bool;
              default = defaults.input.dragLock;
            };
            naturalScrolling = mkOption {
              type = bool;
              default = defaults.input.naturalScrolling;
            };
            disableWhileTyping = mkOption {
              type = bool;
              default = defaults.input.disableWhileTyping;
            };
            leftHanded = mkOption {
              type = bool;
              default = defaults.input.leftHanded;
            };
            middleButtonEmulation = mkOption {
              type = bool;
              default = defaults.input.middleButtonEmulation;
            };
            scrollMethod = mkOption {
              type = enum [
                "none"
                "2fg"
                "edge"
                "button"
              ];
              default = defaults.input.scrollMethod;
            };
            clickMethod = mkOption {
              type = enum [
                "none"
                "areas"
                "clickfinger"
              ];
              default = defaults.input.clickMethod;
            };
            sendEvents = mkOption {
              type = enum [
                "enabled"
                "disabled"
                "disabled-on-external-mouse"
              ];
              default = defaults.input.sendEvents;
            };
            accelProfile = mkOption {
              type = enum [
                "flat"
                "adaptive"
              ];
              default = defaults.input.accelProfile;
            };
            accelSpeed = mkOption {
              type = float;
              default = defaults.input.accelSpeed;
              description = "Pointer acceleration speed, typically -1..1.";
            };
            tapButtonMap = mkOption {
              type = enum [
                "lrm"
                "lmr"
              ];
              default = defaults.input.tapButtonMap;
            };
          };
        };
        default = defaults.input;
      };
      commands = mkOption {
        type = submodule {
          options = {
            terminal = mkOption {
              type = nullOr (nonEmptyListOf str);
              default = null;
              description = "Terminal argv; null falls back to the alacritty store path.";
            };
            launcher = mkOption {
              type = nullOr (nonEmptyListOf str);
              default = null;
              description = "Launcher argv; null falls back to the fuzzel store path.";
            };
            locker = mkOption {
              type = nullOr (nonEmptyListOf str);
              default = null;
              description = "Locker argv; null falls back to the swaylock store path.";
            };
          };
        };
        default = defaults.commands;
      };
      keybinds = mkOption {
        type = listOf anything;
        default = defaults.keybinds;
        description = "Replaces the default keybindings wholesale; see docs/dwl-scroll.md. Extend via extraKeybinds.";
      };
      extraKeybinds = mkOption {
        type = listOf anything;
        default = [ ];
        description = "Appended to keybinds.";
      };
      buttons = mkOption {
        type = listOf anything;
        default = defaults.buttons;
        description = "Mouse button bindings; replaces defaults. Extend via extraButtons.";
      };
      extraButtons = mkOption {
        type = listOf anything;
        default = [ ];
      };
      axes = mkOption {
        type = listOf anything;
        default = [ ];
        description = "Plain dwl Axis bindings; modifier+wheel panning is handled separately.";
      };
      extraAxes = mkOption {
        type = listOf anything;
        default = [ ];
      };
      extraConfig = mkOption {
        type = lines;
        default = "";
        description = "Raw C inserted before the TAGKEYS macro and binding tables; can define helper functions and command arrays.";
      };
    };

  # Render the complete C header. `render` merges group attrsets with
  # defaults recursively; list sections replace defaults wholesale.
  render =
    rawSettings:
    let
      s = lib.recursiveUpdate defaults rawSettings;

      modEnabled =
        let
          m = modsOfAttrset "modkey" s.modkey;
        in
        if m == [ ] then throwC "modkey" "at least one modifier must be enabled" else m;

      wheelExpr =
        if s.wheel.mod == "modkey" then
          "MODKEY"
        else if s.wheel.mod == "none" then
          "0"
        else if lib.isAttrs s.wheel.mod then
          let
            m = modsOfAttrset "wheel.mod" s.wheel.mod;
          in
          if m == [ ] then "0" else concatStringsSep "|" (map modC m)
        else
          throwC "wheel.mod" (
            "expected \"modkey\", \"none\" or a modifier attrset, got " + toString s.wheel.mod
          );

      bindAll =
        let
          keyBinds = map (row: {
            kind = "key";
            inherit row;
          }) (s.keybinds ++ s.extraKeybinds);
          buttonBinds = map (row: {
            kind = "button";
            inherit row;
          }) (s.buttons ++ s.extraButtons);
          axisBinds = map (row: {
            kind = "axis";
            inherit row;
          }) (s.axes ++ s.extraAxes);
        in
        keyBinds ++ buttonBinds ++ axisBinds;

      processed =
        lib.foldl'
          (
            st: e:
            let
              arg = e.row.arg or null;
              inline = lib.isAttrs arg && (arg ? "v") && lib.isList arg.v;
              name = "dwl_cmd${toString st.n}";
              row =
                if inline then
                  e.row
                  // {
                    arg = {
                      v = name;
                    };
                  }
                else
                  e.row;
              decl =
                if inline then
                  assert
                    e.row.arg.v != [ ] && lib.all (x: lib.isString x || lib.isDerivation x) e.row.arg.v
                    || throwC "arg.v" "inline spawn argv must be a non-empty list of strings or packages";
                  "static const char *${name}[] = { ${
                    concatStringsSep ", " (map (x: cStr "arg.v" (toArgStr x)) e.row.arg.v)
                  }, NULL };"
                else
                  null;
            in
            {
              n = st.n + 1;
              key = st.key ++ (lib.optional (e.kind == "key") row);
              button = st.button ++ (lib.optional (e.kind == "button") row);
              axis = st.axis ++ (lib.optional (e.kind == "axis") row);
              decls = st.decls ++ (lib.optional (decl != null) decl);
            }
          )
          {
            n = 0;
            key = [ ];
            button = [ ];
            axis = [ ];
            decls = [ ];
          }
          bindAll;

      # Row renderers apply per-kind field defaults over the raw row first.
      keyDef = {
        mods = null;
        key = null;
        action = null;
        arg = null;
        tag = null;
      };
      buttonDef = {
        mods = null;
        button = null;
        action = null;
        arg = null;
      };
      axisDef = {
        mods = null;
        dir = null;
        action = null;
        arg = null;
      };

      modsExpr =
        where: mkOn: l:
        let
          m = modsList where l;
          inside = lib.all (n: lib.elem n m) mkOn;
          extra = filter (n: !(lib.elem n mkOn)) m;
        in
        if m == mkOn then
          "MODKEY"
        else if inside && m != [ ] && mkOn != m then
          "MODKEY|${concatStringsSep "|" (map modC extra)}"
        else if m == [ ] then
          "0"
        else
          concatStringsSep "|" (map modC m);

      argC =
        where: commands: arg:
        if arg == null then
          "{0}"
        else if !lib.isAttrs arg then
          throwC "${where}.arg" "expected null or a single-field attrset (i/ui/f/v/direction/cursor/layout/tag/all), got ${toString arg}"
        else
          let
            fs = lib.attrNames arg;
            one = length fs == 1;
            f = if one then head fs else "";
            v = if one then arg."${f}" else null;
          in
          if !one then
            throwC "${where}.arg" "expected exactly one field, got: ${concatStringsSep "," fs}"
          else if f == "i" then
            if lib.isInt v then
              "{.i = ${toString v}}"
            else
              throwC "${where}.arg.i" "expected an integer, got ${toString v}"
          else if f == "ui" then
            if lib.isInt v && v >= 0 then
              "{.ui = ${toString v}}"
            else
              throwC "${where}.arg.ui" "expected a non-negative integer, got ${toString v}"
          else if f == "f" then
            "{.f = ${cFloat "${where}.arg.f" v}}"
          else if f == "v" then
            if lib.isString v && match "[A-Za-z_][A-Za-z0-9_]*" v != null then
              (
                if match "^dwl_cmd[0-9]+$" v != null then
                  "{.v = ${v}}"
                else if v == "termcmd" then
                  assert
                    commands.terminal != null || throwC "commands.terminal" "required for binding arg.v = \"termcmd\"";
                  "{.v = ${v}}"
                else if v == "menucmd" then
                  assert
                    commands.launcher != null || throwC "commands.launcher" "required for binding arg.v = \"menucmd\"";
                  "{.v = ${v}}"
                else if v == "lockcmd" then
                  assert
                    commands.locker != null || throwC "commands.locker" "required for binding arg.v = \"lockcmd\"";
                  "{.v = ${v}}"
                else
                  "{.v = ${v}}"
              )
            else
              throwC "${where}.arg.v" "expected a command array name (string) or an inline argv list, got ${toString v}"
          else if f == "direction" then
            if
              lib.elem v [
                "left"
                "right"
                "up"
                "down"
              ]
            then
              "{.i = WLR_DIRECTION_${toUpper v}}"
            else
              throwC "${where}.arg.direction" "expected left/right/up/down, got ${toString v}"
          else if f == "cursor" then
            if v == "move" then
              "{.ui = CurMove}"
            else if v == "resize" then
              "{.ui = CurResize}"
            else
              throwC "${where}.arg.cursor" "expected move/resize, got ${toString v}"
          else if f == "layout" then
            if lib.isInt v && v >= 0 && v < length s.layouts then
              "{.v = &layouts[${toString v}]}"
            else
              throwC "${where}.arg.layout" "expected a layouts index inside 0..${
                toString (length s.layouts - 1)
              }, got ${toString v}"
          else if f == "tag" then
            if lib.isInt v && v >= 0 then
              "{.ui = 1 << ${toString v}}"
            else
              throwC "${where}.arg.tag" "expected a tag index >= 0, got ${toString v}"
          else if f == "all" then
            "{.ui = ~0}"
          else
            throwC "${where}.arg.${f}" "unknown arg field (use i, ui, f, v, direction, cursor, layout, tag or all)";

      keyRow =
        rawB:
        let
          b = keyDef // rawB;
        in
        if b.tag != null then
          assert b.mods == null || throwC "keybind" "tag binds take only `tag = n;`";
          assert b.key == null || throwC "keybind" "tag binds take only `tag = n;`";
          assert b.action == null || throwC "keybind" "tag binds take only `tag = n;`";
          assert b.arg == null || throwC "keybind" "tag binds take only `tag = n;`";
          if b.tag < 0 then
            throwC "keybind.tag" "tag must be >= 0, got ${toString b.tag}"
          else if b.tag >= 9 then
            throwC "keybind.tag" "TAGKEYS rows cover tags 0..8 (keys 1..9); tag ${toString b.tag} is not a TAGKEYS row; bind view/tag/toggleview/toggletag with an explicit .tag arg instead"
          else if b.tag >= s.tags then
            throwC "keybind.tag" "tag ${toString b.tag} exceeds settings.tags = ${toString s.tags}"
          else
            "\tTAGKEYS(XKB_KEY_${toString (b.tag + 1)}, ${toString b.tag}),"
        else if b.key == null then
          throwC "keybind" "key is required"
        else if b.action == null then
          throwC "keybind" "action is required for key ${b.key}"
        else if !lib.isList b.mods then
          throwC "keybind.mods" "expected a list of modifiers, got ${toString b.mods}"
        else
          "\t{ ${
            modsExpr "keybind.mods" modEnabled b.mods
          }, ${keysym "keybind.key" b.key}, ${cIdent "keybind.action" b.action}, ${
            argC "keybind" s.commands b.arg
          } },";

      buttonRow =
        rawB:
        let
          b = buttonDef // rawB;
          btn =
            if b.button == "left" then
              "BTN_LEFT"
            else if b.button == "middle" then
              "BTN_MIDDLE"
            else if b.button == "right" then
              "BTN_RIGHT"
            else if lib.isInt b.button && b.button >= 0 then
              toString b.button
            else
              throwC "button.button" "expected left/middle/right or a BTN code integer, got ${toString b.button}";
        in
        if b.action == null then
          throwC "button" "action is required"
        else if !lib.isList b.mods then
          throwC "button.mods" "expected a list of modifiers, got ${toString b.mods}"
        else
          "\t{ ${
            modsExpr "button.mods" modEnabled b.mods
          }, ${btn}, ${cIdent "button.action" b.action}, ${argC "button" s.commands b.arg} },";

      axisDirC =
        d:
        if d == "up" then
          "AxisUp"
        else if d == "right" then
          "AxisRight"
        else if d == "down" then
          "AxisDown"
        else if d == "left" then
          "AxisLeft"
        else
          throwC "axis.dir" "expected up/right/down/left, got ${toString d}";

      axisRow =
        rawB:
        let
          b = axisDef // rawB;
          func = if b.action == null then "NULL" else cIdent "axis.action" b.action;
          argText =
            if b.action == null then
              if b.arg != null then
                throwC "axis" "arg is ignored together with a NULL action; set arg = null"
              else
                "{0}"
            else
              argC "axis" s.commands b.arg;
        in
        if !lib.isList b.mods then
          throwC "axis.mods" "expected a list of modifiers, got ${toString b.mods}"
        else
          "\t{ ${modsExpr "axis.mods" modEnabled b.mods}, ${axisDirC b.dir}, ${func}, ${argText} },";

      ruleRow =
        rawR:
        let
          r = {
            app_id = null;
            title = null;
            tags = 0;
            floating = false;
            monitor = -1;
          }
          // rawR;
          str = k: v: if v == null then "NULL" else cStr "rules[].${k}" v;
        in
        "\t{ ${str "app_id" r.app_id}, ${str "title" r.title}, ${toString r.tags}, ${cBool "rules[].floating" r.floating}, ${toString r.monitor} },";

      layoutRow =
        rawL:
        let
          l = {
            symbol = null;
            arrange = null;
          }
          // rawL;
          arrange = if l.arrange == "floating" then "NULL" else cIdent "layouts[].arrange" l.arrange;
        in
        "\t{ ${cStr "layouts[].symbol" l.symbol}, ${arrange} },";

      transformC = t: "WL_OUTPUT_TRANSFORM_${concatStringsSep "_" (lib.splitString "-" (toUpper t))}";

      monruleRow =
        rawR:
        let
          r = {
            name = null;
            mfact = 0.55;
            nmaster = 1;
            scale = 1.0;
            layout = 0;
            transform = "normal";
            x = -1;
            y = -1;
          }
          // rawR;
          name = if r.name == null then "NULL" else cStr "monrules[].name" r.name;
        in
        "\t{ ${name}, ${cFloat "monrules[].mfact" r.mfact}, ${toString r.nmaster}, ${cFloat "monrules[].scale" r.scale}, &layouts[${toString r.layout}], ${transformC r.transform}, ${toString r.x}, ${toString r.y} },";

      logLevelC = {
        "error" = "WLR_ERROR";
        "info" = "WLR_INFO";
        "debug" = "WLR_DEBUG";
      };

      inputC = {
        scroll = {
          "none" = "LIBINPUT_CONFIG_SCROLL_NO_SCROLL";
          "2fg" = "LIBINPUT_CONFIG_SCROLL_2FG";
          "edge" = "LIBINPUT_CONFIG_SCROLL_EDGE";
          "button" = "LIBINPUT_CONFIG_SCROLL_ON_BUTTON_DOWN";
        };
        click = {
          "none" = "LIBINPUT_CONFIG_CLICK_METHOD_NONE";
          "areas" = "LIBINPUT_CONFIG_CLICK_METHOD_BUTTON_AREAS";
          "clickfinger" = "LIBINPUT_CONFIG_CLICK_METHOD_CLICKFINGER";
        };
        send = {
          "enabled" = "LIBINPUT_CONFIG_SEND_EVENTS_ENABLED";
          "disabled" = "LIBINPUT_CONFIG_SEND_EVENTS_DISABLED";
          "disabled-on-external-mouse" = "LIBINPUT_CONFIG_SEND_EVENTS_DISABLED_ON_EXTERNAL_MOUSE";
        };
        accel = {
          "flat" = "LIBINPUT_CONFIG_ACCEL_PROFILE_FLAT";
          "adaptive" = "LIBINPUT_CONFIG_ACCEL_PROFILE_ADAPTIVE";
        };
        tap = {
          "lrm" = "LIBINPUT_CONFIG_TAP_MAP_LRM";
          "lmr" = "LIBINPUT_CONFIG_TAP_MAP_LMR";
        };
      };

      lineWidths = map (w: cFloat "scroll.widths[]" w) s.scroll.widths;

      ruleBlock =
        if s.rules == [ ] then
          "\t{ NULL, NULL, 0, 0, -1 }," # inert no-op rule
        else
          concatStringsSep "\n" (map ruleRow s.rules);

      keysBlock =
        if processed.key == [ ] then
          "\t{ 0, 0, NULL, {0} },"
        else
          concatStringsSep "\n" (map keyRow processed.key);

      buttonsBlock =
        if processed.button == [ ] then
          "\t{ 0, 0, NULL, {0} },"
        else
          concatStringsSep "\n" (map buttonRow processed.button);

      axesBlock =
        if processed.axis == [ ] then
          "\t{ 0, AxisUp, NULL, {0} },"
        else
          concatStringsSep "\n" (map axisRow processed.axis);

      toArgStr = x: if lib.isDerivation x then lib.getExe x else toString x;

      cmdArray =
        label: argv:
        if argv == null then
          throwC "commands.${label}" "argv list is required for bindings referencing ${label}"
        else if argv == [ ] || !lib.all (x: lib.isString x || lib.isDerivation x) argv then
          throwC "commands.${label}" "argv must be a non-empty list of strings or packages"
        else
          "static const char *${label}[] = { ${
            concatStringsSep ", " (map (x: cStr "commands.${label}" (toArgStr x)) argv)
          }, NULL };";

      tagkeysDefine = concatStringsSep "\n" [
        "#define TAGKEYS(KEY,TAG) \\"
        "\t{ MODKEY, KEY, view, {.ui = 1 << TAG} }, \\"
        "\t{ MODKEY|WLR_MODIFIER_CTRL, KEY, toggleview, {.ui = 1 << TAG} }, \\"
        "\t{ MODKEY|WLR_MODIFIER_SHIFT, KEY, tag, {.ui = 1 << TAG} }, \\"
        "\t{ MODKEY|WLR_MODIFIER_CTRL|WLR_MODIFIER_SHIFT, KEY, toggletag, {.ui = 1 << TAG} }"
      ];

      colorMacro = concatStringsSep "\n" [
        "#define COLOR(hex) { ((hex >> 24) & 0xff) / 255.0f, \\"
        "                    ((hex >> 16) & 0xff) / 255.0f, \\"
        "                    ((hex >> 8) & 0xff) / 255.0f, (hex & 0xff) / 255.0f }"
      ];

      xkbFields = filter (x: x != null) [
        (if s.xkb.rules != null then ".rules = ${cStr "xkb.rules" s.xkb.rules}" else null)
        (if s.xkb.model != null then ".model = ${cStr "xkb.model" s.xkb.model}" else null)
        (if s.xkb.layout != null then ".layout = ${cStr "xkb.layout" s.xkb.layout}" else null)
        (if s.xkb.variant != null then ".variant = ${cStr "xkb.variant" s.xkb.variant}" else null)
        (
          if s.xkb.options != null then
            ".options = ${cStr "xkb.options" s.xkb.options}"
          else
            ".options = NULL"
        )
      ];

      insertC = {
        "left" = "-1";
        "current" = "0";
        "right" = "1";
      };
    in
    assert
      (
        s.discordRpc.clientId == null
        || (lib.isString s.discordRpc.clientId && match "[0-9]{17,20}" s.discordRpc.clientId != null)
      )
      || throwC "discordRpc.clientId" "expected a public numeric application ID (17..20 digits), not a token";
    assert
      (!s.discordRpc.enable || s.discordRpc.clientId != null)
      || throwC "discordRpc.clientId" "required when Discord RPC is enabled";
    assert
      (s.scroll.width > 0 && s.scroll.width <= 1)
      || throwC "scroll.width" "expected a fraction in (0,1], got ${toString s.scroll.width}";
    assert
      lib.all (w: w > 0 && w <= 1) s.scroll.widths
      || throwC "scroll.widths" "every width must be a fraction in (0,1]";
    assert
      s.tags >= 1 && s.tags <= 31
      || throwC "tags" "TAGCOUNT must be within 1..31, got ${toString s.tags}";
    assert s.wheel.scale > 0 || throwC "wheel.scale" "expected > 0, got ${toString s.wheel.scale}";
    assert
      lib.all (r: r.mfact > 0 && r.mfact < 1) s.monrules
      || throwC "monrules[].mfact" "expected a fraction strictly in (0,1)";
    assert lib.all (r: r.scale >= 0) s.monrules || throwC "monrules[].scale" "expected >= 0";
    assert length s.layouts >= 1 || throwC "layouts" "at least one layout is required";
    assert
      lib.all (r: r.layout >= 0 && r.layout < length s.layouts) s.monrules
      || throwC "monrules[].layout" "layout index must be inside 0..${toString (length s.layouts - 1)}";
    assert
      s.input.accelSpeed >= -1.0 && s.input.accelSpeed <= 1.0
      || throwC "input.accelSpeed" "expected a value in -1..1, got ${toString s.input.accelSpeed}";
    concatStringsSep "\n" (
      [
        "/* dwl-scroll, dwl 0.9 / wlroots 0.20 - config header generated from"
        " * lucy.dwlScroll.settings (pkgs/dwl-scroll/config.nix). Do not edit;"
        " * rebuild to apply. */"
        colorMacro
        "static const int sloppyfocus = ${cBool "sloppyfocus" s.sloppyfocus};"
        "static const int bypass_surface_visibility = ${cBool "bypassSurfaceVisibility" s.bypassSurfaceVisibility};"
        "static const unsigned int borderpx = ${toString s.borderpx};"
        "static const unsigned int snap = ${toString s.snap};"
        "static const float rootcolor[] = ${cHex "colors.root" s.colors.root};"
        "static const float bordercolor[] = ${cHex "colors.border" s.colors.border};"
        "static const float focuscolor[] = ${cHex "colors.focus" s.colors.focus};"
        "static const float urgentcolor[] = ${cHex "colors.urgent" s.colors.urgent};"
        "static const float fullscreen_bg[] = ${
          cHex "colors.fullscreenBg" (
            s.colors.fullscreenBg or s.colors.fullscreen or s.colors.fullscreen_bg or "000000"
          )
        };"
        "#define TAGCOUNT ${toString s.tags}"
        "static int log_level = ${logLevelC."${s.log.level}"};"
        "#define DISCORD_RPC_ENABLED ${cBool "discordRpc.enable" s.discordRpc.enable}"
        "#define DISCORD_RPC_SHOW_APP ${cBool "discordRpc.showApp" s.discordRpc.showApp}"
        "#define DISCORD_RPC_CLIENT_ID ${
          if s.discordRpc.clientId == null then "NULL" else cStr "discordRpc.clientId" s.discordRpc.clientId
        }"
        ""
        "static const Rule rules[] = {"
        ruleBlock
        "};"
        ""
        "static const float scroll_width = ${cFloat "scroll.width" s.scroll.width};"
        "static const float scroll_widths[] = {${concatStringsSep ", " lineWidths}};"
        "static const int scroll_column_gap = ${toString s.scroll.columnGap};"
        "static const int scroll_window_gap = ${toString s.scroll.windowGap};"
        "static const int scroll_padding = ${toString s.scroll.padding};"
        "static const int scroll_center = ${cBool "scroll.center" s.scroll.center};"
        "static const int scroll_insert = ${insertC."${s.scroll.insert}"};"
        "static const int scroll_step = ${toString s.scroll.step};"
        "#define MODKEY ${concatStringsSep "|" (map modC modEnabled)}"
        "static const uint32_t scroll_wheel_mod = ${wheelExpr};"
        "static const double scroll_wheel_scale = ${cFloat "wheel.scale" s.wheel.scale};"
        ""
        "static const Layout layouts[] = {"
        (concatStringsSep "\n" (map layoutRow s.layouts))
        "};"
        "static const MonitorRule monrules[] = {"
        (concatStringsSep "\n" (map monruleRow s.monrules))
        "};"
        "static const struct xkb_rule_names xkb_rules = { ${concatStringsSep ", " xkbFields} };"
        "static const int repeat_rate = ${toString s.repeat.rate}, repeat_delay = ${toString s.repeat.delay};"
        "static const int tap_to_click = ${cBool "input.tapToClick" s.input.tapToClick}, tap_and_drag = ${cBool "input.tapAndDrag" s.input.tapAndDrag}, drag_lock = ${cBool "input.dragLock" s.input.dragLock};"
        "static const int natural_scrolling = ${cBool "input.naturalScrolling" s.input.naturalScrolling}, disable_while_typing = ${cBool "input.disableWhileTyping" s.input.disableWhileTyping};"
        "static const int left_handed = ${cBool "input.leftHanded" s.input.leftHanded}, middle_button_emulation = ${cBool "input.middleButtonEmulation" s.input.middleButtonEmulation};"
        "static const enum libinput_config_scroll_method scroll_method = ${
          inputC.scroll."${s.input.scrollMethod}"
        };"
        "static const enum libinput_config_click_method click_method = ${
          inputC.click."${s.input.clickMethod}"
        };"
        "static const uint32_t send_events_mode = ${inputC.send."${s.input.sendEvents}"};"
        "static const enum libinput_config_accel_profile accel_profile = ${
          inputC.accel."${s.input.accelProfile}"
        };"
        "static const double accel_speed = ${cFloat "input.accelSpeed" s.input.accelSpeed};"
        "static const enum libinput_config_tap_button_map button_map = ${
          inputC.tap."${s.input.tapButtonMap}"
        };"
        ""
        s.extraConfig
        tagkeysDefine
        (cmdArray "termcmd" s.commands.terminal)
        (cmdArray "menucmd" s.commands.launcher)
        (cmdArray "lockcmd" s.commands.locker)
      ]
      ++ processed.decls
      ++ [
        ""
        "static const Key keys[] = {"
        keysBlock
        "};"
        "static const Button buttons[] = {"
        buttonsBlock
        "};"
        "static const Axis axes[] = {"
        axesBlock
        "};"
        ""
      ]
    );
}
