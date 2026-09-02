{
  bar = cfg: cfg;

  module = name: cfg: {
    inherit name cfg;
  };

  rule = selector: declarations: {
    inherit selector declarations;
  };
}
