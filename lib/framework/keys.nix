{symbols}: let
  join = parts: builtins.concatStringsSep "+" parts;
in {
  combo = join;

  alt = key: join [symbols.keys.alt key];
  altCtrl = key: join [symbols.keys.alt symbols.keys.ctrl key];
  altShift = key: join [symbols.keys.alt symbols.keys.shift key];
  altCtrlShift = key: join [symbols.keys.alt symbols.keys.ctrl symbols.keys.shift key];

  workspace = n: builtins.toString n;
}
