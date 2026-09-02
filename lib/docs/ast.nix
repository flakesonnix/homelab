# Document AST — structured, renderer-agnostic.
# Every piece of documentation is a Document with metadata and blocks.
# Blocks are headings, paragraphs, lists, tables, code, etc.
# This is the intermediate representation between domain data and renderers.
{
  # Constructors
  mkDocument = {
    title,
    description ? "",
    id ? null,
    type ? "document",
    metadata ? {},
    blocks ? [],
  }: {
    inherit title description id type metadata blocks;
    _type = "document";
  };

  mkHeading = {
    level,
    text,
    id ? null,
  }: {
    inherit level text id;
    _type = "heading";
  };

  mkParagraph = {
    text,
  }: {
    inherit text;
    _type = "paragraph";
  };

  mkList = {
    ordered ? false,
    items, # list of strings or inlines
  }: {
    inherit ordered items;
    _type = "list";
  };

  mkTable = {
    headers, # list of strings
    rows,    # list of (list of strings)
  }: {
    inherit headers rows;
    _type = "table";
  };

  mkCodeBlock = {
    lang ? "",
    code,
  }: {
    inherit lang code;
    _type = "codeBlock";
  };

  mkBlockquote = {
    text,
  }: {
    inherit text;
    _type = "blockquote";
  };

  mkImage = {
    alt,
    url,
    title ? "",
  }: {
    inherit alt url title;
    _type = "image";
  };

  mkLink = {
    text,
    url,
  }: {
    inherit text url;
    _type = "link";
  };

  mkInlineCode = {
    code,
  }: {
    inherit code;
    _type = "inlineCode";
  };

  mkReference = {
    type, # entity type: host, service, module, etc.
    id,   # entity id
    label ? null,
  }: {
    inherit type id label;
    _type = "reference";
  };

  mkSection = {
    title,
    level ? 2,
    id ? null,
    blocks ? [],
  }: {
    inherit title level id blocks;
    _type = "section";
  };

  # Helpers
  mkMetadata = attrs: attrs // {_type = "metadata";};

  # Type checks
  isDocument = x: x ? _type && x._type == "document";
  isBlock = x: x ? _type && builtins.elem x._type ["heading" "paragraph" "list" "table" "codeBlock" "blockquote" "image" "section"];
}
