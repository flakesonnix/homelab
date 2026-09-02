let
  renderArgv = argv:
    builtins.concatStringsSep " " (map builtins.toJSON argv);
in {
  inherit renderArgv;

  renderShell = script:
    builtins.toJSON script;

  render = action:
    if action.kind == "spawn"
    then "spawn ${renderArgv action.argv}"
    else if action.kind == "spawn-sh"
    then "spawn-sh ${builtins.toJSON action.script}"
    else if action.kind == "builtin" && action ? arg
    then "${action.name} ${toString action.arg}"
    else if action.kind == "builtin"
    then action.name
    else throw "Unknown command action kind";
}
