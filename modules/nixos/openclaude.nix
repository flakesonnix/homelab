{ lib, stdenv, fetchurl, nodejs, npmConfigHook }:

stdenv.mkDerivation {
  pname = "openclaude";
  version = "0.1.9";

  src = lib.cleanSource (builtins.fetchGit {
    url = "https://github.com/gitlawb/openclaude";
    rev = "HEAD";
  });

  nativeBuildInputs = [ nodejs npmConfigHook ];

  npmDeps = fetchurl {
    url = "https://registry.npmjs.org/@gitlawb/openclaude/-/openclaude-${version}.tgz";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  makeCacheDirs = [ ];

  dontNpmBuild = false;
  installPhase = ''
    mkdir -p $out/lib/node_modules/@gitlawb
    tar -xzf $npmDeps -C $out/lib/node_modules/@gitlawb
    mv $out/lib/node_modules/@gitlawb/package $out/lib/node_modules/@gitlawb/openclaude
    chmod +x $out/lib/node_modules/@gitlawb/openclaude/bin/openclaude.js
    ln -s $out/lib/node_modules/@gitlawb/openclaude/bin/openclaude.js $out/bin/openclaude
  '';

  postPatch = ''
    export HOME=$TMPDIR
  '';
}
