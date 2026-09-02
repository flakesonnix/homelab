# Markdown renderer — Document AST → Markdown string.
# Deterministic, no timestamps, sorted lists.
{lib}: let
  inherit (lib) concatStringsSep concatMapStringsSep;
  repeat = n: s: concatStringsSep "" (lib.genList (_: s) n);

  escape = s: s; # TODO: proper escaping for | in tables, etc. Keep simple for now.

  renderInline = inline:
    if inline._type == "link"
    then "[${escape inline.text}](${inline.url})"
    else if inline._type == "inlineCode"
    then "`${inline.code}`"
    else if inline._type == "reference"
    then let
      label =
        if inline.label != null
        then inline.label
        else inline.id;
      # Simple relative link: ../<type>/<id>.md
      url = "../${inline.type}/${inline.id}.md";
    in "[${label}](${url})"
    else if builtins.isString inline
    then escape inline
    else "";

  renderBlock = block:
    if block._type == "heading"
    then "${repeat block.level "#"} ${escape block.text}"
    else if block._type == "paragraph"
    then escape block.text
    else if block._type == "list"
    then let
      prefix =
        if block.ordered
        then "1. "
        else "- ";
    in
      concatMapStringsSep "\n" (item: "${prefix}${renderInline item}") block.items
    else if block._type == "table"
    then let
      header = "| ${concatStringsSep " | " (map escape block.headers)} |";
      sep = "| ${concatStringsSep " | " (map (_: "---") block.headers)} |";
      rows = concatMapStringsSep "\n" (row: "| ${concatStringsSep " | " (map escape row)} |") block.rows;
    in "${header}\n${sep}\n${rows}"
    else if block._type == "codeBlock"
    then "```${block.lang}\n${block.code}\n```"
    else if block._type == "blockquote"
    then "> ${escape block.text}"
    else if block._type == "image"
    then "![${escape block.alt}](${block.url}${
      if block.title != ""
      then " \"${block.title}\""
      else ""
    })"
    else if block._type == "section"
    then let
      heading = "${repeat block.level "#"} ${escape block.title}";
      body = renderBlocks block.blocks;
    in
      if body == ""
      then heading
      else "${heading}\n\n${body}"
    else "";

  renderBlocks = blocks: concatStringsSep "\n\n" (map renderBlock blocks);
in rec {
  renderDocument = doc: let
    titleBlock = "# ${escape doc.title}";
    descBlock =
      if doc.description != ""
      then doc.description
      else "";
    body = renderBlocks doc.blocks;
    parts = lib.filter (s: s != "") [titleBlock descBlock body];
  in
    concatStringsSep "\n\n" parts + "\n";

  render = renderDocument;
}
