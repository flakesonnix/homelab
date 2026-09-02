let
  unique = list:
    builtins.foldl' (
      acc: item:
        if builtins.elem item acc
        then acc
        else acc ++ [item]
    ) []
    list;

  collectRoleRefs = field: roles:
    builtins.concatLists (map (role: role.${field} or []) roles);
in {
  inherit collectRoleRefs;

  resolveHostPresets = {
    directPresets ? [],
    roles ? [],
  }:
    unique (directPresets ++ collectRoleRefs "presets" roles);

  resolveHomeBundles = {
    directBundles ? [],
    roles ? [],
  }: let
    roleBundles = collectRoleRefs "bundles" roles;
  in
    unique (
      if directBundles != []
      then directBundles
      else roleBundles
    );
}
