{lib, ...}: let
  inherit (import ../layout.nix {}) head footer;
in ''
  ${head}
  <h2>Home Roles</h2>
  <form method="POST" action="/roles/home">
    <div class="cards">
      <label class="card checkbox-card">
        <input type="checkbox" name="role" value="base" checked>
        <div><h3>base</h3><p>Base home configuration</p></div>
      </label>
      <label class="card checkbox-card">
        <input type="checkbox" name="role" value="desktop" checked>
        <div><h3>desktop</h3><p>Desktop applications</p></div>
      </label>
    </div>
    <button type="submit" class="btn btn-primary">Save</button>
  </form>
  ${footer}
''
