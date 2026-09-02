let
  renderValue = value:
    if builtins.isBool value
    then
      if value
      then "true"
      else "false"
    else if builtins.isInt value || builtins.isFloat value
    then toString value
    else builtins.toJSON value;

  renderAttrs = attrs:
    builtins.concatStringsSep " " (
      map (name: "${name}=${renderValue attrs.${name}}") (builtins.attrNames attrs)
    );

  renderLines = lines:
    builtins.concatStringsSep "\n" lines;
in rec {
  inherit renderValue renderAttrs renderLines;

  renderBind = renderCommand: bind: let
    attrText =
      if bind.attrs == {}
      then ""
      else " ${renderAttrs bind.attrs}";
  in "${bind.key}${attrText} { ${renderCommand bind.action}; }";

  renderSection = name: lines: "${name} {\n${builtins.concatStringsSep "\n" lines}\n}";

  renderLeaf = name: value:
    if value == null
    then name
    else "${name} ${renderValue value}";

  renderCommandBlock = name: argv: "${name} ${builtins.concatStringsSep " " (map builtins.toJSON argv)}";

  renderPropsBlock = name: props:
  # Allow mixing pre-rendered KDL lines with structured { name, value } leaves.
    renderSection name (
      map (
        prop:
          if builtins.isString prop
          then prop
          else renderLeaf prop.name prop.value
      )
      props
    );
}
