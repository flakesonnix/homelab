{lib, ...}: let
  inherit (import ../layout.nix {}) head footer;
in ''
  ${head}
  <h2>Host Roles</h2>
  <form method="POST" action="/roles/host">
    <div class="cards">
      <label class="card checkbox-card">
        <input type="checkbox" name="role" value="base" checked>
        <div><h3>base</h3><p>Base system configuration</p></div>
      </label>
      <label class="card checkbox-card">
        <input type="checkbox" name="role" value="desktop" checked>
        <div><h3>desktop</h3><p>Desktop environment</p></div>
      </label>
      <label class="card checkbox-card">
        <input type="checkbox" name="role" value="gaming">
        <div><h3>gaming</h3><p>Gaming optimizations</p></div>
      </label>
      <label class="card checkbox-card">
        <input type="checkbox" name="role" value="dev">
        <div><h3>dev</h3><p>Development tools</p></div>
      </label>
      <label class="card checkbox-card">
        <input type="checkbox" name="role" value="llm">
        <div><h3>llm</h3><p>LLM/AI tools</p></div>
      </label>
    </div>
    <button type="submit" class="btn btn-primary">Save</button>
  </form>
  ${footer}
''
