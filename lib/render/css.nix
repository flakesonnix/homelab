let
  renderDeclaration = name: value: "  ${name}: ${value};";
in {
  inherit renderDeclaration;

  renderRule = rule: let
    declarations = builtins.concatStringsSep "\n" (
      map (name: renderDeclaration name rule.declarations.${name}) (builtins.attrNames rule.declarations)
    );
  in "${rule.selector} {\n${declarations}\n}";

  renderSheet = rules:
    builtins.concatStringsSep "\n\n" (map renderRule rules);
}
