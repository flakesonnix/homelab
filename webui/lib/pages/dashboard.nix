{lib, ...}: let
  inherit (import ../layout.nix {}) head footer;
in ''
  ${head}
  <h2>Dashboard</h2>
  <div class="cards">
    <div class="card">
      <h3>Host Roles</h3>
      <p>base, desktop</p>
      <a href="/roles/host" class="btn">Configure</a>
    </div>
    <div class="card">
      <h3>Home Roles</h3>
      <p>base, desktop</p>
      <a href="/roles/home" class="btn">Configure</a>
    </div>
    <div class="card">
      <h3>Presets</h3>
      <p>gaming-base, gaming-steam</p>
      <a href="/presets" class="btn">Configure</a>
    </div>
    <div class="card">
      <h3>Bundles</h3>
      <p>core, desktop</p>
      <a href="/bundles" class="btn">Configure</a>
    </div>
  </div>
  ${footer}
''
