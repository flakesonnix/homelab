{
  mergeDefinitions = {
    lib,
    parts,
    attrFields ? [],
    listFields ? [],
  }: let
    mergeAttrField = field:
      builtins.foldl' lib.recursiveUpdate {} (map (part: part.${field} or {}) parts);

    mergeListField = field:
      builtins.concatLists (map (part: part.${field} or []) parts);
  in
    builtins.listToAttrs (
      map (field: {
        name = field;
        value = mergeAttrField field;
      })
      attrFields
      ++ map (field: {
        name = field;
        value = mergeListField field;
      })
      listFields
    );

  renderEnabledAttrs = {
    lib,
    path,
    names,
  }:
    lib.setAttrByPath path (builtins.listToAttrs (
      map (name: {
        inherit name;
        value = true;
      })
      names
    ));

  renderOptionalPath = {
    lib,
    path,
    value,
  }:
    lib.optionalAttrs (value != null) (lib.setAttrByPath path value);
}
