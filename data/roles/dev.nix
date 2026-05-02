{
  meta = {
    description = "Development tools, IDEs, and device tooling";
    requires = {
      host = [];
      home = ["core"];
    };
    conflicts = {
      host = [];
      home = [];
    };
    targets = ["host" "home"];
  };

  host = {
    packageTags = [
      "dev"
      "network"
      "monitoring"
    ];
  };

  home = {
    bundles = ["dev"];
  };
}
