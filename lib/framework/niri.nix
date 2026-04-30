{
  bind = key: action: {
    inherit key action;
    attrs = {};
  };

  bindWith = key: attrs: action: {
    inherit key attrs action;
  };

  startupSpawn = argv: {
    kind = "spawn";
    inherit argv;
  };

  startupShell = script: {
    kind = "spawn-sh";
    inherit script;
  };

  windowRule = lines: {inherit lines;};

  leaf = name: value: {
    inherit name value;
  };

  workspaceBindTriplet = {
    focusKey,
    moveColumnKey,
    moveWindowKey,
    workspace,
    actions,
    symbols,
  }: [
    {
      key = focusKey;
      attrs = {};
      action = (actions.builtin symbols.actions.focusWorkspace) // {arg = workspace;};
    }
    {
      key = moveColumnKey;
      attrs = {};
      action = (actions.builtin symbols.actions.moveColumnToWorkspace) // {arg = workspace;};
    }
    {
      key = moveWindowKey;
      attrs = {};
      action = (actions.builtin symbols.actions.moveWindowToWorkspace) // {arg = workspace;};
    }
  ];
}
