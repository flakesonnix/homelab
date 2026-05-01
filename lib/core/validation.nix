let
  normalizeRoleList = value:
    if builtins.isList value
    then value
    else if builtins.isAttrs value
    then value.roles or []
    else [];

  findMissingFiles = {
    root,
    names,
  }:
    builtins.filter (name: !(builtins.pathExists (root + "/${name}.nix"))) names;

  findMissingNames = {
    known,
    names,
  }:
    builtins.filter (name: !(builtins.elem name known)) names;

  findDuplicateNames = names: let
    counts =
      builtins.foldl' (
        acc: name:
          acc
          // {
            ${name} = (acc.${name} or 0) + 1;
          }
      ) {}
      names;
  in
    builtins.filter (name: counts.${name} > 1) (builtins.attrNames counts);

  roleTargetList = {
    meta,
    field,
    target,
  }: let
    value = meta.${field} or [];
  in
    if builtins.isList value
    then value
    else if builtins.isAttrs value
    then value.${target} or []
    else [];

  valueFingerprint = value:
    builtins.toJSON value;

  flattenModuleFlags = moduleFlags: let
    go = prefix: value:
      if builtins.isAttrs value
      then
        builtins.concatLists (
          map (
            name:
              go
              (prefix ++ [name])
              value.${name}
          ) (builtins.attrNames value)
        )
      else [
        {
          name = builtins.concatStringsSep "." prefix;
          inherit value;
        }
      ];
  in
    builtins.listToAttrs (go [] moduleFlags);

  collectModuleFlagConflicts = parts: let
    fingerprintsByKey =
      builtins.foldl' (
        acc: part: let
          flags = flattenModuleFlags (part.moduleFlags or {});
        in
          builtins.foldl' (
            inner: key: let
              fingerprint = valueFingerprint flags.${key};
              known = inner.${key} or {};
            in
              inner
              // {
                ${key} = known // {${fingerprint} = true;};
              }
          )
          acc (builtins.attrNames flags)
      ) {}
      parts;
  in
    builtins.filter (
      key: builtins.length (builtins.attrNames fingerprintsByKey.${key}) > 1
    ) (builtins.attrNames fingerprintsByKey);

  invalidModuleFlagKeys = {
    moduleFlags,
    allowedRoots,
  }:
    builtins.filter (
      key: let
        rootMatch = builtins.match "([A-Za-z_][A-Za-z0-9_-]*).*" key;
        root =
          if rootMatch == null
          then ""
          else builtins.head rootMatch;
      in
        key
        == ""
        || builtins.match "[A-Za-z_][A-Za-z0-9_-]*(\\.[A-Za-z_][A-Za-z0-9_-]*)+" key == null
        || !(builtins.elem root allowedRoots)
    ) (builtins.attrNames (flattenModuleFlags moduleFlags));

  registryTags = registry:
    builtins.attrNames (
      builtins.listToAttrs (
        builtins.concatLists (
          map (
            name:
              map (tag: {
                name = tag;
                value = true;
              }) (registry.${name}.tags or [])
          ) (builtins.attrNames registry)
        )
      )
    );

  existingDataDefs = {
    root,
    names,
  }:
    builtins.filter (entry: entry != null) (
      map (
        name:
          if builtins.pathExists (root + "/${name}.nix")
          then {
            inherit name;
            value = import (root + "/${name}.nix");
          }
          else null
      )
      names
    );

  existingRoleDefs = existingDataDefs;

  allRoleNames = roleRoot:
    map (
      name: builtins.replaceStrings [".nix"] [""] name
    ) (builtins.filter (
      name: builtins.match ".*\\.nix" name != null
    ) (builtins.attrNames (builtins.readDir roleRoot)));

  metadataShapeErrors = {
    defs,
    target,
  }: let
    missingMeta = builtins.filter (entry: !(builtins.isAttrs (entry.value.meta or null))) defs;
    invalidDescriptions =
      builtins.filter (
        entry: let
          desc = entry.value.meta.description or null;
        in
          !(builtins.isString desc && desc != "")
      )
      defs;
    invalidTargets =
      builtins.filter (
        entry: let
          targets = entry.value.meta.targets or [];
        in
          !(builtins.isList targets && builtins.elem target targets)
      )
      defs;
  in {
    missingMetadata = map (entry: entry.name) missingMeta;
    invalidDescriptions = map (entry: entry.name) invalidDescriptions;
    invalidTargets = map (entry: entry.name) invalidTargets;
  };

  roleMetadataErrors = {
    roleDefs,
    target,
    selectedNames,
    knownNames,
  }: let
    shapeErrors = metadataShapeErrors {
      defs = roleDefs;
      inherit target;
    };

    unknownRoleRequires = builtins.concatLists (map (
        entry:
          map (dep: "${entry.name} -> ${dep}") (
            findMissingNames {
              known = knownNames;
              names = roleTargetList {
                meta = entry.value.meta or {};
                field = "requires";
                inherit target;
              };
            }
          )
      )
      roleDefs);

    unknownRoleConflicts = builtins.concatLists (map (
        entry:
          map (dep: "${entry.name} x ${dep}") (
            findMissingNames {
              known = knownNames;
              names = roleTargetList {
                meta = entry.value.meta or {};
                field = "conflicts";
                inherit target;
              };
            }
          )
      )
      roleDefs);

    missingRequiredRoles = builtins.concatLists (map (
        entry:
          map (dep: "${entry.name} requires ${dep}") (
            builtins.filter (dep: !(builtins.elem dep selectedNames)) (
              roleTargetList {
                meta = entry.value.meta or {};
                field = "requires";
                inherit target;
              }
            )
          )
      )
      roleDefs);

    conflictingRoles = builtins.concatLists (map (
        entry:
          map (dep: "${entry.name} conflicts with ${dep}") (
            builtins.filter (dep: builtins.elem dep selectedNames) (
              roleTargetList {
                meta = entry.value.meta or {};
                field = "conflicts";
                inherit target;
              }
            )
          )
      )
      roleDefs);
  in {
    missingRoleMetadata = shapeErrors.missingMetadata;
    invalidRoleDescriptions = shapeErrors.invalidDescriptions;
    invalidRoleTargets = shapeErrors.invalidTargets;
    inherit
      unknownRoleRequires
      unknownRoleConflicts
      missingRequiredRoles
      conflictingRoles
      ;
  };

  collectRolePresetNames = {
    lib,
    roles,
    roleRoot,
    target,
  }:
    lib.unique (
      builtins.concatLists (
        map (
          roleName: let
            role = import (roleRoot + "/${roleName}.nix");
          in
            role.${target}.presets or []
        )
        roles
      )
    );
in {
  validateHost = {
    lib,
    hostRoot,
    roleRoot ? null,
    presetRoot ? null,
    packageRegistry ? null,
    packageData ? null,
  }: let
    rolesFile = hostRoot + "/roles.nix";
    presetsFile = hostRoot + "/presets.nix";
    hostRoles =
      if builtins.pathExists rolesFile
      then import rolesFile
      else [];
    roles = normalizeRoleList hostRoles;
    hostPresets = let
      p =
        if builtins.pathExists presetsFile
        then import presetsFile
        else [];
    in
      if builtins.isList p
      then p
      else [];
    packageInfo =
      if packageData != null
      then packageData
      else {};
    roleDefs =
      if roleRoot != null
      then
        existingRoleDefs {
          root = roleRoot;
          names = roles;
        }
      else [];
    knownRoleNames =
      if roleRoot != null
      then allRoleNames roleRoot
      else [];
    rolePresetNames =
      if roleRoot != null
      then
        collectRolePresetNames {
          inherit lib roles roleRoot;
          target = "host";
        }
      else [];
    allPresetNames = lib.unique (hostPresets ++ rolePresetNames);
    presetDefs =
      if presetRoot != null
      then
        existingDataDefs {
          root = presetRoot;
          names = allPresetNames;
        }
      else [];
    knownPackageNames =
      if packageRegistry != null
      then builtins.attrNames packageRegistry
      else [];
    knownPackageTags =
      if packageRegistry != null
      then registryTags packageRegistry
      else [];
    metaErrors = roleMetadataErrors {
      inherit roleDefs;
      target = "host";
      selectedNames = roles;
      knownNames = knownRoleNames;
    };
    presetMetaErrors = metadataShapeErrors {
      defs = presetDefs;
      target = "host";
    };
  in {
    missingRoles =
      if roleRoot != null
      then
        findMissingFiles {
          root = roleRoot;
          names = roles;
        }
      else [];
    missingPresets =
      if presetRoot != null
      then
        findMissingFiles {
          root = presetRoot;
          names = allPresetNames;
        }
      else [];
    missingBundles = [];
    missingPackageToggles =
      if packageRegistry != null
      then
        findMissingNames {
          known = knownPackageNames;
          names = packageInfo.packageToggles or [];
        }
      else [];
    missingPackageTags =
      if packageRegistry != null
      then
        findMissingNames {
          known = knownPackageTags;
          names = packageInfo.packageTags or [];
        }
      else [];
    inherit
      (metaErrors)
      missingRoleMetadata
      invalidRoleDescriptions
      invalidRoleTargets
      unknownRoleRequires
      unknownRoleConflicts
      missingRequiredRoles
      conflictingRoles
      ;
    missingPresetMetadata = presetMetaErrors.missingMetadata;
    invalidPresetDescriptions = presetMetaErrors.invalidDescriptions;
    invalidPresetTargets = presetMetaErrors.invalidTargets;
  };

  validateHome = {
    lib,
    homeRoot,
    roleRoot ? null,
    bundleRoot ? null,
    packageRegistry ? null,
    packageData ? null,
  }: let
    rolesFile = homeRoot + "/roles.nix";
    homeRoles =
      if builtins.pathExists rolesFile
      then import rolesFile
      else [];
    roles = normalizeRoleList homeRoles;
    packageInfo =
      if packageData != null
      then packageData
      else {};
    roleDefs =
      if roleRoot != null
      then
        existingRoleDefs {
          root = roleRoot;
          names = roles;
        }
      else [];
    knownRoleNames =
      if roleRoot != null
      then allRoleNames roleRoot
      else [];
    resolvedRoles =
      if roleRoot != null
      then map (name: import (roleRoot + "/${name}.nix")) roles
      else [];
    bundleNames = lib.unique (builtins.concatLists (map (role: role.home.bundles or []) resolvedRoles));
    bundleDefs =
      if bundleRoot != null
      then
        existingDataDefs {
          root = bundleRoot;
          names = bundleNames;
        }
      else [];
    knownPackageNames =
      if packageRegistry != null
      then builtins.attrNames packageRegistry
      else [];
    knownPackageTags =
      if packageRegistry != null
      then registryTags packageRegistry
      else [];
    metaErrors = roleMetadataErrors {
      inherit roleDefs;
      target = "home";
      selectedNames = roles;
      knownNames = knownRoleNames;
    };
    bundleMetaErrors = metadataShapeErrors {
      defs = bundleDefs;
      target = "home";
    };
  in {
    missingRoles =
      if roleRoot != null
      then
        findMissingFiles {
          root = roleRoot;
          names = roles;
        }
      else [];
    missingPresets = [];
    missingBundles =
      if bundleRoot != null
      then
        findMissingFiles {
          root = bundleRoot;
          names = bundleNames;
        }
      else [];
    missingPackageToggles =
      if packageRegistry != null
      then
        findMissingNames {
          known = knownPackageNames;
          names = packageInfo.packageToggles or [];
        }
      else [];
    missingPackageTags =
      if packageRegistry != null
      then
        findMissingNames {
          known = knownPackageTags;
          names = packageInfo.packageTags or [];
        }
      else [];
    inherit
      (metaErrors)
      missingRoleMetadata
      invalidRoleDescriptions
      invalidRoleTargets
      unknownRoleRequires
      unknownRoleConflicts
      missingRequiredRoles
      conflictingRoles
      ;
    missingBundleMetadata = bundleMetaErrors.missingMetadata;
    invalidBundleDescriptions = bundleMetaErrors.invalidDescriptions;
    invalidBundleTargets = bundleMetaErrors.invalidTargets;
  };

  assertValid = {
    lib,
    kind ? "configuration",
    missingRoles ? [],
    missingPresets ? [],
    missingBundles ? [],
    missingPackageToggles ? [],
    missingPackageTags ? [],
    duplicateRoles ? [],
    duplicatePresets ? [],
    duplicateBundles ? [],
    conflictingModuleFlags ? [],
    invalidModuleFlags ? [],
    missingRoleMetadata ? [],
    invalidRoleDescriptions ? [],
    invalidRoleTargets ? [],
    missingPresetMetadata ? [],
    invalidPresetDescriptions ? [],
    invalidPresetTargets ? [],
    missingBundleMetadata ? [],
    invalidBundleDescriptions ? [],
    invalidBundleTargets ? [],
    unknownRoleRequires ? [],
    unknownRoleConflicts ? [],
    missingRequiredRoles ? [],
    conflictingRoles ? [],
  }: let
    messages =
      lib.optional (missingRoles != []) "  Missing role files: ${builtins.concatStringsSep ", " (map (n: "data/roles/${n}.nix") missingRoles)}"
      ++ lib.optional (missingPresets != []) "  Missing preset files: ${builtins.concatStringsSep ", " (map (n: "data/presets/${n}.nix") missingPresets)}"
      ++ lib.optional (missingBundles != []) "  Missing bundle files: ${builtins.concatStringsSep ", " (map (n: "data/bundles/${n}.nix") missingBundles)}"
      ++ lib.optional (missingPackageToggles != []) "  Unknown package toggles: ${builtins.concatStringsSep ", " missingPackageToggles}"
      ++ lib.optional (missingPackageTags != []) "  Unknown package tags: ${builtins.concatStringsSep ", " missingPackageTags}"
      ++ lib.optional (duplicateRoles != []) "  Duplicate roles: ${builtins.concatStringsSep ", " duplicateRoles}"
      ++ lib.optional (duplicatePresets != []) "  Duplicate presets: ${builtins.concatStringsSep ", " duplicatePresets}"
      ++ lib.optional (duplicateBundles != []) "  Duplicate bundles: ${builtins.concatStringsSep ", " duplicateBundles}"
      ++ lib.optional (conflictingModuleFlags != []) "  Conflicting module flags: ${builtins.concatStringsSep ", " conflictingModuleFlags}"
      ++ lib.optional (invalidModuleFlags != []) "  Invalid module flag paths: ${builtins.concatStringsSep ", " invalidModuleFlags}"
      ++ lib.optional (missingRoleMetadata != []) "  Roles missing meta blocks: ${builtins.concatStringsSep ", " missingRoleMetadata}"
      ++ lib.optional (invalidRoleDescriptions != []) "  Roles with invalid descriptions: ${builtins.concatStringsSep ", " invalidRoleDescriptions}"
      ++ lib.optional (invalidRoleTargets != []) "  Roles with invalid targets for this context: ${builtins.concatStringsSep ", " invalidRoleTargets}"
      ++ lib.optional (missingPresetMetadata != []) "  Presets missing meta blocks: ${builtins.concatStringsSep ", " missingPresetMetadata}"
      ++ lib.optional (invalidPresetDescriptions != []) "  Presets with invalid descriptions: ${builtins.concatStringsSep ", " invalidPresetDescriptions}"
      ++ lib.optional (invalidPresetTargets != []) "  Presets with invalid targets for this context: ${builtins.concatStringsSep ", " invalidPresetTargets}"
      ++ lib.optional (missingBundleMetadata != []) "  Bundles missing meta blocks: ${builtins.concatStringsSep ", " missingBundleMetadata}"
      ++ lib.optional (invalidBundleDescriptions != []) "  Bundles with invalid descriptions: ${builtins.concatStringsSep ", " invalidBundleDescriptions}"
      ++ lib.optional (invalidBundleTargets != []) "  Bundles with invalid targets for this context: ${builtins.concatStringsSep ", " invalidBundleTargets}"
      ++ lib.optional (unknownRoleRequires != []) "  Unknown role requirements: ${builtins.concatStringsSep ", " unknownRoleRequires}"
      ++ lib.optional (unknownRoleConflicts != []) "  Unknown role conflicts: ${builtins.concatStringsSep ", " unknownRoleConflicts}"
      ++ lib.optional (missingRequiredRoles != []) "  Missing required roles: ${builtins.concatStringsSep ", " missingRequiredRoles}"
      ++ lib.optional (conflictingRoles != []) "  Conflicting selected roles: ${builtins.concatStringsSep ", " conflictingRoles}";
  in
    if messages != []
    then builtins.throw "${kind} validation failed:\n${builtins.concatStringsSep "\n" messages}"
    else null;

  inherit
    collectModuleFlagConflicts
    findDuplicateNames
    flattenModuleFlags
    invalidModuleFlagKeys
    normalizeRoleList
    ;
}
