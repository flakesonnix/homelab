{pkgs}: {
  jetbrains-mono = {
    description = "JetBrains Mono font";
    targets = ["home"];
    packages.home = [pkgs.jetbrains-mono];
    tags = ["desktop" "fonts"];
  };

  nautilus = {
    description = "Nautilus file manager";
    targets = ["home"];
    packages.home = [pkgs.nautilus];
    tags = ["desktop" "files"];
  };

  comma = {
    description = "comma (run programs without installing)";
    targets = ["home"];
    packages.home = [pkgs.comma];
    tags = ["cli" "nix"];
  };

  manix = {
    description = "manix option and API search";
    targets = ["home"];
    packages.home = [pkgs.manix];
    tags = ["cli" "nix"];
  };

  nix-output-monitor = {
    description = "nix-output-monitor build UI";
    targets = ["home"];
    packages.home = [pkgs.nix-output-monitor];
    tags = ["cli" "nix"];
  };

  android-studio = {
    description = "Android Studio";
    targets = ["home"];
    packages.home = [pkgs.android-studio];
    tags = ["dev" "android"];
  };
}
