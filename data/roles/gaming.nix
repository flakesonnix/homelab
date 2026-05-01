{
  meta = {
    description = "Gaming stack with Steam, GameMode, and performance presets";
    requires.host = ["desktop"];
    conflicts.host = [];
    targets = ["host"];
  };

  host = {
    presets = [
      "gaming-base"
      "gaming-performance"
      "gaming-steam"
    ];
  };
}
