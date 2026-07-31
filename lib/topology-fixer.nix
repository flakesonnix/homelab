# Standalone pure-Nix topology SVG fixer.
#
# Self-contained (builtins only) so it can be evaluated with `nix eval` at
# build time. `spec` carries every tunable as data; `svg` is the generated
# SVG string, the fixed string is returned.
#
# Large SVGs overflow Nix's regex engine and `split` recursion when split by
# newline, so the SVG is only ever split on short literal strings whose
# occurrence count is small (the label marker, "<svg"): recursion depth
# stays proportional to the number of labels, and every regex runs on a
# small segment only.
{
  spec,
  svg,
}: let
  inherit (builtins)
    concatStringsSep
    elemAt
    filter
    foldl'
    fromJSON
    genList
    head
    isString
    length
    match
    replaceStrings
    sort
    split
    stringLength
    substring
    toString;

  s = spec;
  step = s.labelHeight + s.minSpacing;
  contentHeight = s.labelHeight + s.heightPadding;

  # The marker sits mid-tag, so the tag start and its y attribute are at the
  # tail of the segment preceding the marker occurrence. Only that tail is
  # matched (segments before the first label can be huge).
  segs = filter isString (split s.labelMarker svg);
  markerY = seg: let
    from = if stringLength seg < 2000 then 0 else stringLength seg - 2000;
    tail = substring from 2000 seg;
    m = match "(.*)<text[^>]* y=\"([0-9.]+)\"[^>]*$" tail;
  in
    if m == null
    then null
    else {
      yStr = elemAt m 1;
      y = fromJSON (elemAt m 1);
    };
  labels = filter (l: l != null) (map markerY (genList (i: elemAt segs i) (length segs - 1)));

  zeros = n: concatStringsSep "" (genList (_: "0") n);

  # Render a number with n decimals, preserving the original label format:
  # integers stay "275", floats get padded/trimmed to n decimals ("359.000").
  fmt = v: n: let
    str = toString v;
    int = match "^[0-9]+$" str != null;
    dec = if int then "" else elemAt (filter isString (split "\\." str)) 1;
  in
    if int
    then str + (if n == 0 then "" else "." + zeros n)
    else if stringLength dec < n
    then str + zeros (n - stringLength dec)
    else if stringLength dec > n
    then substring 0 (stringLength str - (stringLength dec - n)) str
    else str;

  decOf = yStr: let
    m = match ".*\\.([0-9]+)$" yStr;
  in
    if m == null then 0 else stringLength (head m);

  # Sort by y, then walk with a cursor enforcing minSpacing between labels.
  sorted = sort (a: b: a.y < b.y) labels;
  adjusted = let
    go = acc: l: let
      new = if l.y < acc.cursor then acc.cursor else l.y;
    in {
      items = acc.items ++ [
        {
          inherit (l) yStr y;
          inherit new;
        }
      ];
      cursor = new + step;
    };
  in (foldl' go {items = []; cursor = 0;} sorted).items;

  # Rewrite moved label positions, then shift their icons by the same delta.
  svgLabels = foldl' (acc: a: let
      newStr = fmt a.new (decOf a.yStr);
    in
      if a.yStr == newStr
      then acc
      else replaceStrings ["y=\"${a.yStr}\""] ["y=\"${newStr}\""] acc)
    svg
    adjusted;
  svgIcons = foldl' (acc: a: let
      n = decOf a.yStr;
      oldIcon = fmt (a.y + s.iconOffset) n;
      newIcon = fmt (a.new + s.iconOffset) n;
    in
      if oldIcon == newIcon
      then acc
      else replaceStrings ["${s.iconPrefix}${oldIcon}${s.iconSuffix}"] ["${s.iconPrefix}${newIcon}${s.iconSuffix}"] acc)
    svgLabels
    adjusted;

  # Grow the root <svg> height if the last label moved past the old height.
  # The segment after "<svg" is the rest of the file, so only its head is
  # matched (the root tag closes within the first chars).
  svgTag = "<svg" + head (match "^([^>]*)>.*" (substring 0 2000 (elemAt (filter isString (split "<svg" svgIcons)) 1))) + ">";
  origHeight = head (match ".*height=\"([0-9.]+)\".*" svgTag);
  lastLabel = if adjusted == [] then null else elemAt adjusted (length adjusted - 1);
  lastNew = if lastLabel == null then null else lastLabel.new;
  lastDec = if lastLabel == null then 0 else decOf lastLabel.yStr;
  newHeight =
    if lastNew == null
    then null
    else fmt (lastNew + contentHeight) (if lastDec == 0 then 3 else lastDec);
  grow = newHeight != null && fromJSON newHeight > fromJSON origHeight;

  svgFixed =
    if !grow
    then svgIcons
    else
      replaceStrings
      [svgTag]
      [
        (replaceStrings ["height=\"${origHeight}\""] ["height=\"${newHeight}\""] svgTag)
      ]
      svgIcons;
in
  svgFixed
