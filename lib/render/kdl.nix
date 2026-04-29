let
  renderAttrs = attrs:
    builtins.concatStringsSep " " (
      map (name: "${name}=${builtins.toJSON attrs.${name}}") (builtins.attrNames attrs)
    );
in {
  inherit renderAttrs;

  renderBind = renderCommand: bind: let
    attrText =
      if bind.attrs == {}
      then ""
      else " ${renderAttrs bind.attrs}";
  in "${bind.key}${attrText} { ${renderCommand bind.action}; }";

  renderSection = name: lines: "${name} {\n${builtins.concatStringsSep "\n" lines}\n}";

  renderLines = lines:
    builtins.concatStringsSep "\n" lines;
}
