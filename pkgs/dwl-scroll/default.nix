{
  lib,
  dwl,
  replaceVars,
  alacritty,
  fuzzel,
  swaylock,
  cairo,
  pango,
  glib,
  json-glib,
  libdrm,
  libsfdo,
  gdk-pixbuf,
  librsvg,
  papirus-icon-theme,
  configH ? null,
  enableXWayland ? true,
  settings ? null,
}:
assert lib.assertMsg (dwl.version == "0.9") "dwl-scroll patches require dwl 0.9; rebase and test before updating";
assert lib.assertMsg (configH == null || settings == null) "Choose either configH (raw C header) or settings (typed Nix), not both"; let
  cfg = import ./config.nix {inherit lib;};
  effectiveSettings =
    if settings != null
    then let
      cmds = settings.commands or {};
      filledCommands = {
        terminal =
          if (cmds.terminal or null) != null
          then cmds.terminal
          else [(lib.getExe alacritty)];
        launcher =
          if (cmds.launcher or null) != null
          then cmds.launcher
          else [(lib.getExe fuzzel)];
        locker =
          if (cmds.locker or null) != null
          then cmds.locker
          else [(lib.getExe swaylock)];
      };
    in
      settings // {commands = (settings.commands or {}) // filledCommands;}
    else null;
  header =
    if configH != null
    then configH
    else if settings != null
    then (cfg.render effectiveSettings)
    else
      replaceVars ./config.h {
        terminal = lib.getExe alacritty;
        launcher = lib.getExe fuzzel;
        locker = lib.getExe swaylock;
      };
in
  (dwl.override {
    inherit enableXWayland;
    configH = header;
  }).overrideAttrs (old: {
    pname = "dwl-scroll";
    makeFlags = old.makeFlags ++ ["VERSION=0.9-scroll1"];
    patches =
      (old.patches or [])
      ++ [
        ./patches/0001-scrolling-layout.patch
        ./patches/0002-management-and-wheel.patch
        ./patches/0003-builtin-launcher.patch
        ./patches/0004-discord-rpc.patch
      ];
    patchFlags = ["-p1" "--fuzz=0"];
    buildInputs = old.buildInputs ++ [cairo pango glib json-glib libdrm libsfdo gdk-pixbuf librsvg];
    postPatch = lib.concatStringsSep "\n" [
      (old.postPatch or "")
      ''
        cp ${./launcher.c} launcher.c
        cp ${./launcher-model.c} launcher-model.c
        cp ${./launcher-icons.c} launcher-icons.c
        cp ${./discord-rpc.c} discord-rpc.c
        substituteInPlace launcher-icons.c \
          --replace-fail '@launcherIconPath@' '${papirus-icon-theme}/share/icons'
      ''
    ];
    doCheck = true;
    checkPhase = ''
      runHook preCheck
      $CC -std=c11 -Wall -Wextra -Werror -I. ${./tests.c} \
        $(pkg-config --cflags --libs wayland-server) -lm -o scroll-test
      ./scroll-test
      $CC -std=c11 -Wall -Wextra -Werror -fsanitize=address,undefined \
        -fno-omit-frame-pointer -I. ${./tests.c} \
        $(pkg-config --cflags --libs wayland-server) -lm -o scroll-test-sanitized
      ASAN_OPTIONS=detect_leaks=1 ./scroll-test-sanitized
      $CC -std=c11 -Wall -Wextra -Werror -I. ${./launcher-tests.c} \
        $(pkg-config --cflags --libs gio-unix-2.0) -o launcher-test
      ./launcher-test
      $CC -std=c11 -Wall -Wextra -Werror -fsanitize=address,undefined \
        -fno-omit-frame-pointer -I. ${./launcher-tests.c} \
        $(pkg-config --cflags --libs gio-unix-2.0) -o launcher-test-sanitized
      ASAN_OPTIONS=detect_leaks=1 ./launcher-test-sanitized
      $CC -std=c11 -Wall -Wextra -Werror -I. ${./launcher-icons-tests.c} \
        $(pkg-config --cflags --libs cairo gio-2.0 libsfdo-icon libsfdo-basedir gdk-pixbuf-2.0 librsvg-2.0) \
        -o launcher-icons-test
      ./launcher-icons-test
      $CC -std=c11 -Wall -Wextra -Werror -fsanitize=address,undefined \
        -fno-omit-frame-pointer -I. ${./launcher-icons-tests.c} \
        $(pkg-config --cflags --libs cairo gio-2.0 libsfdo-icon libsfdo-basedir gdk-pixbuf-2.0 librsvg-2.0) \
        -o launcher-icons-test-sanitized
      ASAN_OPTIONS=detect_leaks=1 ./launcher-icons-test-sanitized
      $CC -std=c11 -Wall -Wextra -Werror -I. ${./discord-rpc-tests.c} \
        $(pkg-config --cflags --libs wayland-server gio-unix-2.0 json-glib-1.0) -o discord-rpc-test
      ./discord-rpc-test
      $CC -std=c11 -Wall -Wextra -Werror -fsanitize=address,undefined \
        -fno-omit-frame-pointer -I. ${./discord-rpc-tests.c} \
        $(pkg-config --cflags --libs wayland-server gio-unix-2.0 json-glib-1.0) -o discord-rpc-test-sanitized
      ASAN_OPTIONS=detect_leaks=1 ./discord-rpc-test-sanitized
      runHook postCheck
    '';
    postInstall =
      (old.postInstall or "")
      + ''
        mv "$out/bin/dwl" "$out/bin/dwl-scroll"
        mv "$man/share/man/man1/dwl.1" "$man/share/man/man1/dwl-scroll.1"
        rm "$out/share/wayland-sessions/dwl.desktop"
        cat > "$out/share/wayland-sessions/dwl-scroll.desktop" <<EOF
        [Desktop Entry]
        Name=dwl-scroll
        Comment=Upstream dwl with persistent scrolling columns
        Exec=$out/bin/dwl-scroll
        Type=Application
        DesktopNames=dwl-scroll
        EOF
      '';
    # Upstream's passthru tests refer to its original binary/session name.
    # Our checkPhase and flake checks exercise this variant instead.
    passthru =
      builtins.removeAttrs (old.passthru or {}) ["tests"]
      // {
        providedSessions = ["dwl-scroll"];
      };
    meta =
      old.meta
      // {
        description = "Upstream dwl with a persistent scrolling-column layout";
        mainProgram = "dwl-scroll";
      };
  })
