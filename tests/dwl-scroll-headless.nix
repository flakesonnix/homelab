{
  pkgs,
  package,
}:
pkgs.runCommand "dwl-scroll-headless"
  {
    nativeBuildInputs = with pkgs; [
      foot
      wtype
      wlr-randr
      grim
      (python3.withPackages (ps: [ ps.pillow ]))
    ];
    FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.iosevka ]; };
    DWL_TEST_LOCKER = "${
      import ../pkgs/dwl-scroll/lock-test.nix { inherit pkgs; }
    }/bin/dwl-scroll-test-locker";
  }
  ''
    export HOME="$TMPDIR"
    python3 ${../pkgs/dwl-scroll/smoke.py} ${package}
    touch "$out"
  ''
