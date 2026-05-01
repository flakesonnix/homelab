let
  dashify = name:
    builtins.replaceStrings ["_"] ["-"] name;

  renderValue = value:
    if builtins.isList value
    then builtins.concatStringsSep ", " value
    else toString value;

  renderDeclaration = name: value: "  ${dashify name}: ${renderValue value};";
in rec {
  inherit dashify renderValue renderDeclaration;

  renderRule = rule: let
    declarations = builtins.concatStringsSep "\n" (
      map (name: renderDeclaration name rule.declarations.${name}) (builtins.attrNames rule.declarations)
    );
  in "${rule.selector} {\n${declarations}\n}";

  renderSheet = rules:
    builtins.concatStringsSep "\n\n" (map renderRule rules);
}
