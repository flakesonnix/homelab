{lib, mkBuiltinBind, mkBindWithAttrs, keys, actions, symbols, pkgs}:

let
  b = mkBuiltinBind;
  ba = mkBindWithAttrs;
in lib.concatStrings "\n" [
  (b (keys.altShift symbols.keys.slash) "show-hotkey-overlay")
  ""
  (ba (keys.alt symbols.keys.enter) {hotkey-overlay-title = "Open a Terminal: alacritty";} (actions.spawn [symbols.apps.alacritty]))
  (ba (keys.alt "D") {hotkey-overlay-title = "Run an Application: fuzzel";} (actions.spawn [symbols.apps.fuzzel]))
  (ba (keys.altCtrl symbols.keys.escape) {hotkey-overlay-title = "Lock the Screen: swaylock";} (actions.shell "sh -c '${pkgs.swaylock-effects}/bin/swaylock --screenshots --clock'"))
  ""
  "XF86AudioRaiseVolume allow-when-locked=true { spawn-sh \"wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0\"; }"
  "XF86AudioLowerVolume allow-when-locked=true { spawn-sh \"wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-\"; }"
  "XF86AudioMute allow-when-locked=true { spawn-sh \"wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle\"; }"
  "XF86AudioMicMute allow-when-locked=true { spawn-sh \"wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle\"; }"
  ""
  "XF86AudioPlay allow-when-locked=true { spawn-sh \"playerctl play-pause\"; }"
  "XF86AudioStop allow-when-locked=true { spawn-sh \"playerctl stop\"; }"
  "XF86AudioPrev allow-when-locked=true { spawn-sh \"playerctl previous\"; }"
  "XF86AudioNext allow-when-locked=true { spawn-sh \"playerctl next\"; }"
  ""
  "XF86MonBrightnessUp allow-when-locked=true { spawn \"brightnessctl\" \"--class=backlight\" \"set\" \"+10%\"; }"
  "XF86MonBrightnessDown allow-when-locked=true { spawn \"brightnessctl\" \"--class=backlight\" \"set\" \"10%-\"; }"
  ""
  (ba (keys.alt "O") {repeat = false;} actions.named.toggleOverview)
  (ba (keys.alt "W") {repeat = false;} actions.named.closeWindow)
  ""
  "Alt+Left { focus-column-left; }"
  "Alt+Down { focus-window-down; }"
  "Alt+Up { focus-window-up; }"
  "Alt+Right { focus-column-right; }"
  "Alt+H { focus-monitor-left; }"
  "Alt+L { focus-monitor-right; }"
  "Alt+K { focus-monitor-up; }"
  "Alt+J { focus-monitor-down; }"
  ""
  "Alt+Q { close; }"
  "Alt+Shift+Q { quit; }"
  "Alt+F { toggle-fullscreen; }"
  ""
  (ba (keys.alt "Return") {repeat = false;} (actions.spawn [symbols.apps.alacritty]))
  (ba (keys.altShift "R") {repeat = false;} (actions.spawn ["${pkgs.niri}/bin/nirictl set-focused-window-pseudotile"]))
  (ba (keys.altShift "T") {repeat = false;} (actions.spawn ["${pkgs.niri}/bin/niri-msg set-focused-window-floating true"]))
  ""
  (ba (keys.alt "1") {repeat = false;} actions.named.workspace1)
  (ba (keys.alt "2") {repeat = false;} actions.named.workspace2)
  (ba (keys.alt "3") {repeat = false;} actions.named.workspace3)
  (ba (keys.alt "4") {repeat = false;} actions.named.workspace4)
  (ba (keys.alt "5") {repeat = false;} actions.named.workspace5)
  (ba (keys.alt "6") {repeat = false;} actions.named.workspace6)
  (ba (keys.alt "7") {repeat = false;} actions.named.workspace7)
  (ba (keys.alt "8") {repeat = false;} actions.named.workspace8)
  (ba (keys.alt "9") {repeat = false;} actions.named.workspace9)
  ""
  (ba (keys.altShift "1") {repeat = false;} actions.named.moveToWorkspace1)
  (ba (keys.altShift "2") {repeat = false;} actions.named.moveToWorkspace2)
  (ba (keys.altShift "3") {repeat = false;} actions.named.moveToWorkspace3)
  (ba (keys.altShift "4") {repeat = false;} actions.named.moveToWorkspace4)
  (ba (keys.altShift "5") {repeat = false;} actions.named.moveToWorkspace5)
  (ba (keys.altShift "6") {repeat = false;} actions.named.moveToWorkspace6)
  (ba (keys.altShift "7") {repeat = false;} actions.named.moveToWorkspace7)
  (ba (keys.altShift "8") {repeat = false;} actions.named.moveToWorkspace8)
  (ba (keys.altShift "9") {repeat = false;} actions.named.moveToWorkspace9)
  ""
  "Ctrl+Alt+Delete { quit; }"
  ""
  (b "Alt+Shift+P" symbols.actions.powerOffMonitors)
]