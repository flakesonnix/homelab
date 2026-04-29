{symbols}: {
  builtin = name: {
    kind = "builtin";
    inherit name;
  };

  spawn = argv: {
    kind = "spawn";
    inherit argv;
  };

  shell = script: {
    kind = "spawn-sh";
    inherit script;
  };

  named = {
    toggleOverview = {
      kind = "builtin";
      name = symbols.actions.toggleOverview;
    };
    closeWindow = {
      kind = "builtin";
      name = symbols.actions.closeWindow;
    };
    quit = {
      kind = "builtin";
      name = symbols.actions.quit;
    };
    powerOffMonitors = {
      kind = "builtin";
      name = symbols.actions.powerOffMonitors;
    };
  };
}
