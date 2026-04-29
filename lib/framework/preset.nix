{
  mergePresets = presets:
    builtins.foldl' (acc: preset: acc // preset) {} presets;
}
