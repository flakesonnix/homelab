# Generate — Source Data → Domain Model → Document AST → Outputs
{
  lib,
  pkgs,
}: let
  ast = import ./ast.nix;
  domain = import ./domain.nix {inherit lib;};
  validate = import ./validate.nix {inherit lib;};
  markdown = import ./render/markdown.nix {inherit lib;};
  jsonRender = import ./render/json.nix {inherit lib;};

  # Load existing project data (reuse framework data)
  # This is the "Source Data" for the docs framework.
  loadSource = {
    hosts,
    roles,
    bundles,
    presets,
    microvms,
    modules,
  }: let
    # Hosts from data/hosts + hosts/mireo microVMs
    hostEntities =
      lib.mapAttrs (
        name: cfg:
          domain.mkHost {
            id = name;
            title = name;
            description = cfg.description or "";
            hardware = cfg.hardware or {};
            network = cfg.network or {};
            services = cfg.services or [];
            microvms = cfg.microvms or [];
            roles = cfg.roles or [];
            modules = cfg.modules or [];
            tags = cfg.tags or [];
          }
      )
      hosts;

    roleEntities =
      lib.mapAttrs (
        name: r:
          domain.mkRole {
            id = name;
            title = name;
            description = r.meta.description or "";
          }
      )
      roles;

    bundleEntities =
      lib.mapAttrs (
        name: b:
          domain.mkBundle {
            id = name;
            title = name;
            description = b.meta.description or "";
          }
      )
      bundles;

    presetEntities =
      lib.mapAttrs (
        name: p:
          domain.mkPreset {
            id = name;
            title = name;
            description = p.meta.description or "";
          }
      )
      presets;

    microvmEntities =
      lib.mapAttrs (
        name: v:
          domain.mkMicroVM {
            id = name;
            title = name;
            description = v.description or "";
            host = v.host or "mireo";
            ip = v.ip or null;
            mem = v.mem or null;
            vcpu = v.vcpu or null;
            services = v.services or [];
          }
      )
      microvms;

    moduleEntities =
      lib.mapAttrs (
        name: m:
          domain.mkModule {
            id = name;
            title = name;
            description = m.description or "";
          }
      )
      modules;
  in
    hostEntities // roleEntities // bundleEntities // presetEntities // microvmEntities // moduleEntities;

  # Simple template for Host → Document
  hostToDocument = host:
    ast.mkDocument {
      title = host.title;
      description = host.description;
      id = host.id;
      type = "host";
      blocks = [
        (ast.mkSection {
          title = "Overview";
          blocks = [
            (ast.mkParagraph {text = host.description;})
            (ast.mkTable {
              headers = ["Field" "Value"];
              rows = [
                ["ID" host.id]
                ["Hardware" (host.hardware.info or "—")]
                ["Roles" (lib.concatStringsSep ", " host.roles)]
                ["Services" (lib.concatStringsSep ", " host.services)]
                ["MicroVMs" (lib.concatStringsSep ", " host.microvms)]
              ];
            })
          ];
        })
        (ast.mkSection {
          title = "Services";
          blocks = [
            (ast.mkList {
              ordered = false;
              items = map (s:
                ast.mkReference {
                  type = "service";
                  id = s;
                })
              host.services;
            })
          ];
        })
        (ast.mkSection {
          title = "MicroVMs";
          blocks = [
            (ast.mkList {
              ordered = false;
              items = map (v:
                ast.mkReference {
                  type = "microvm";
                  id = v;
                })
              host.microvms;
            })
          ];
        })
      ];
    };

  generate = args @ {
    hosts ? {},
    roles ? {},
    bundles ? {},
    presets ? {},
    microvms ? {},
    modules ? {},
  }: let
    entities = loadSource {inherit hosts roles bundles presets microvms modules;};
    validation = validate.validateAll entities;
    # Documents: one per host + index
    hostDocs = lib.mapAttrs (name: host: hostToDocument host) (lib.filterAttrs (n: v: v.type == "host") entities);
    indexDoc = ast.mkDocument {
      title = "Hosts";
      description = "All hosts in the fleet";
      blocks = [
        (ast.mkList {
          ordered = false;
          items = map (name:
            ast.mkLink {
              text = name;
              url = "hosts/${name}.md";
            }) (lib.attrNames (lib.filterAttrs (n: v: v.type == "host") entities));
        })
      ];
    };
    allDocs = hostDocs // {index = indexDoc;};
    markdownOutputs = lib.mapAttrs (_: doc: markdown.renderDocument doc) allDocs;
    frontendData = jsonRender.renderEntities entities;
    graph = jsonRender.renderGraph entities;
  in {
    inherit entities validation;
    docs = allDocs;
    markdown = markdownOutputs;
    frontend = frontendData;
    inherit graph;
  };
in {
  inherit loadSource hostToDocument generate;
}
