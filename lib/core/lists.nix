{
  concatNonEmpty = lists:
    builtins.concatLists (builtins.filter (list: list != []) lists);

  uniqueConcat = lib: lists:
    lib.unique (builtins.concatLists lists);

  optionalList = condition: values:
    if condition
    then values
    else [];

  flattenAttrsPackages = attrs:
    builtins.concatLists (builtins.attrValues attrs);
}
