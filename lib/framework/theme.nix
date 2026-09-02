let
  stripHash = color:
    if builtins.substring 0 1 color == "#"
    then builtins.substring 1 ((builtins.stringLength color) - 1) color
    else color;
in {
  fromStylix = config: let
    colors = config.lib.stylix.colors.withHashtag;
  in rec {
    inherit colors stripHash;
    hexAlpha = color: alpha: "${stripHash color}${alpha}";
    rgba = color: alpha: "#${hexAlpha color alpha}";
    gradient = angle: stops: "linear-gradient(${angle}, ${builtins.concatStringsSep ", " stops})";
  };
}
