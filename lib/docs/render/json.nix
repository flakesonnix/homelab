# JSON renderer — Entity / Document → JSON for frontend.
# Produces stable, deterministic JSON (sorted keys, no timestamps).
{lib}: let
  inherit (lib) mapAttrs;

  # Entity → JSON object for frontend
  renderEntity = entity:
    {
      type = entity.type;
      id = entity.id;
      title = entity.title;
      description = entity.description;
      tags = entity.tags;
      metadata = entity.metadata;
      relations = entity.relations or {};
    }
    // lib.optionalAttrs (entity ? hardware) {hardware = entity.hardware;};
  # Include domain-specific fields if present
  # Use hasAttr to avoid leaking nulls.

  # Document → JSON (for search index, etc.)
  renderDocument = doc: {
    title = doc.title;
    description = doc.description;
    id = doc.id;
    type = doc.type;
    metadata = doc.metadata;
    blocks = doc.blocks;
  };

  # Collection of entities → JSON map
  renderEntities = entities: mapAttrs (_: renderEntity) entities;

  # Graph: entities → { nodes, edges } for frontend
  renderGraph = entities: let
    nodes = map (e: {
      id = "${e.type}:${e.id}";
      type = e.type;
      label = e.title;
    }) (lib.attrValues entities);
    edges = lib.concatLists (map (
      e: let
        rels = e.relations or {};
      in
        lib.concatLists (lib.mapAttrsToList (
            rel: targets:
              map (t: {
                from = "${e.type}:${e.id}";
                to = t;
                label = rel;
              })
              targets
          )
          rels)
    ) (lib.attrValues entities));
  in {
    nodes = lib.sort (a: b: a.id < b.id) nodes;
    edges = lib.sort (a: b: a.from < b.from || (a.from == b.from && a.to < b.to)) edges;
  };
in {
  inherit renderEntity renderDocument renderEntities renderGraph;
}
