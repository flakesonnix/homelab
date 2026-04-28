{
  mkUser = {
    username,
    description ? "",
    modules ? [],
  }: {
    inherit username modules description;
  };

  enableAttrs = lib: names:
    map (name: lib.setAttrByPath [name] true) names;

  mkPackageOptions = lib: packageOptions:
    lib.mapAttrs (_: value: lib.mkEnableOption value.description) packageOptions;

  getEnabledPackagesBy = lib: enabledAttrs: packageOptions: getPackages:
    lib.concatMap (
      name:
        lib.optionals (enabledAttrs.${name} or false) (getPackages packageOptions.${name})
    ) (builtins.attrNames packageOptions);
}
