let
  symbols = import ./symbols.nix;

  coreAttrs = import ./core/attrs.nix;
  coreLists = import ./core/lists.nix;
  coreToggles = import ./core/toggles.nix;
  coreRegistry = import ./core/registry.nix;
  corePackageRouting = import ./core/package-routing.nix;
  coreComposition = import ./core/composition.nix;
  coreValidation = import ./core/validation.nix;

  renderCommand = import ./render/command.nix;
  renderKdl = import ./render/kdl.nix;
  renderCss = import ./render/css.nix;
  theme = import ./theme.nix;

  frameworkKeys = import ./framework/keys.nix;
  frameworkActions = import ./framework/actions.nix;
  frameworkPackage = import ./framework/package.nix;
  frameworkBundle = import ./framework/bundle.nix;
  frameworkExport = import ./framework/export.nix;
  frameworkPreset = import ./framework/preset.nix;
  frameworkResolve = import ./framework/resolve.nix;
  frameworkWebui = import ./framework/webui.nix;
  frameworkHost = import ./framework/host.nix;
  frameworkHome = import ./framework/home.nix;
  frameworkNiri = import ./framework/niri.nix;
  frameworkWaybar = import ./framework/waybar.nix;

  compat = {
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
  };
in
  {
    inherit symbols compat;

    core = {
      attrs = coreAttrs;
      lists = coreLists;
      toggles = coreToggles;
      registry = coreRegistry;
      composition = coreComposition;
      "package-routing" = corePackageRouting;
      validation = coreValidation;
    };

    render = {
      command = renderCommand;
      kdl = renderKdl;
      css = renderCss;
    };

    inherit theme;

    framework = {
      keys = frameworkKeys;
      actions = frameworkActions;
      package = frameworkPackage;
      bundle = frameworkBundle;
      export = frameworkExport;
      preset = frameworkPreset;
      resolve = frameworkResolve;
      webui = frameworkWebui;
      host = frameworkHost;
      home = frameworkHome;
      niri = frameworkNiri;
      waybar = frameworkWaybar;
    };
  }
  // compat
