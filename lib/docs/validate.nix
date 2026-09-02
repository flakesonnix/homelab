# Validation — check entities and relations.
{lib}: let
  inherit (lib) attrNames elem;

  validateEntity = entity:
    let
      errors = lib.optional (entity.id == "" || entity.id == null) "missing id"
        ++ lib.optional (entity.title == "" || entity.title == null) "missing title for ${entity.type}:${toString entity.id}"
        ++ lib.optional (entity.type == "" || entity.type == null) "missing type for ${toString entity.id}";
    in errors;

  validateEntities = entities:
    let
      ids = attrNames entities;
      dups = lib.filter (id: lib.length (lib.filter (e: e == id) ids) > 1) ids;
      entityErrors = lib.concatMap (id:
        let e = entities.${id};
            errs = validateEntity e;
        in map (err: "${id}: ${err}") errs
      ) ids;
      dupErrors = map (id: "duplicate ID ${id}") (lib.unique dups);
    in entityErrors ++ dupErrors;

  validateRelations = entities:
    let
      allIds = lib.attrNames entities;
      # All possible target ids are "type:id" strings
      checkTargets = lib.concatMap (id:
        let e = entities.${id};
            rels = e.relations or {};
            targets = lib.concatLists (lib.attrValues rels);
        in lib.concatMap (t:
          let exists = elem t allIds || elem t (map (k: let parts = lib.splitString ":" k; in "${lib.head parts}:${lib.last parts}") allIds);
              # Actually relations store "type:id" which should be a key in entities as "type:id"? But our entities keys are "id" not "type:id".
              # For simplicity, check that the id part exists as an entity id.
              # Extract id part after colon.
              idPart = lib.last (lib.splitString ":" t);
              existsId = elem idPart (map (k: entities.${k}.id) (attrNames entities));
          in lib.optional (!existsId) "${id} references unknown ${t}"
        ) targets
      ) (attrNames entities);
    in checkTargets;

in {
  inherit validateEntity validateEntities validateRelations;

  validateAll = entities:
    let
      e1 = validateEntities entities;
      e2 = validateRelations entities;
      all = e1 ++ e2;
    in if all == [] then { ok = true; errors = []; } else { ok = false; errors = all; };
}
