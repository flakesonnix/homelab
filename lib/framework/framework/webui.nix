{
  exportChrome = root: let
    nav = [
      {
        section = "System";
        page = "overview";
        expert = false;
        icon = "◉";
        label = "Overview";
      }
      {
        section = "Configuration";
        page = "host";
        expert = false;
        icon = "⌘";
        label = "Host Roles";
      }
      {
        section = "Configuration";
        page = "home";
        expert = false;
        icon = "⌂";
        label = "User Profile";
      }
      {
        section = "Configuration";
        page = "packages";
        expert = true;
        icon = "◆";
        label = "Packages";
      }
      {
        section = "Configuration";
        page = "flags";
        expert = true;
        icon = "⚑";
        label = "Module Flags";
      }
      {
        section = "Configuration";
        page = "preview";
        expert = true;
        icon = "◇";
        label = "Preview";
      }
      {
        section = "Operations";
        page = "actions";
        expert = false;
        icon = "▶";
        label = "Rebuild & Check";
      }
    ];

    pages = [
      {
        name = "overview";
        title = "Overview";
        description = "System state and active configuration";
      }
      {
        name = "host";
        title = "Host Roles";
        description = "Define what this machine does";
      }
      {
        name = "home";
        title = "User Profile";
        description = "Apps and tools for your user";
      }
      {
        name = "packages";
        title = "Packages";
        description = "System tags and user packages";
      }
      {
        name = "flags";
        title = "Module Flags";
        description = "Raw NixOS module toggles";
      }
      {
        name = "preview";
        title = "Preview";
        description = "Resolved roles, presets, and bundles before rebuild";
      }
      {
        name = "actions";
        title = "Rebuild & Check";
        description = "Apply changes and validate";
      }
    ];

    actions = [
      {
        title = "rebuild";
        tag = "nh os switch";
        description = "Evaluate, build, and activate.";
        endpoint = "/rebuild";
        target = "#rebuild-output";
        buttonClass = "btn btn-accent";
        buttonLabel = "▶ Rebuild";
      }
      {
        title = "framework validate";
        tag = "framework rules";
        description = "Role metadata, requires/conflicts, package refs, and module flag rules.";
        endpoint = "/validate/framework";
        target = "#framework-validation-output";
        buttonClass = "btn";
        buttonLabel = "⋄ Framework";
      }
      {
        title = "validate";
        tag = "nix flake check";
        description = "Evaluation, formatting, and pre-commit checks.";
        endpoint = "/validate";
        target = "#validate-output";
        buttonClass = "btn";
        buttonLabel = "◇ Check";
      }
    ];

    renderNav = item:
      builtins.concatStringsSep "\t" [
        "nav"
        item.section
        item.page
        (
          if item.expert
          then "true"
          else "false"
        )
        item.icon
        item.label
      ];

    renderPage = item:
      builtins.concatStringsSep "\t" [
        "page"
        item.name
        item.title
        item.description
      ];

    renderAction = item:
      builtins.concatStringsSep "\t" [
        "action"
        item.title
        item.tag
        item.description
        item.endpoint
        item.target
        item.buttonClass
        item.buttonLabel
      ];
  in
    builtins.concatStringsSep "\n" ((map renderNav nav) ++ (map renderPage pages) ++ (map renderAction actions));

  exportStyle = _root: ''
    :root{--bg-deep:#0d0d12;--bg-main:#111118;--bg-surface:#16161f;--bg-elevated:#1c1c27;--bg-hover:#22222f;--border:#2a2a3a;--border-bright:#3a3a4f;--accent:#00d4ff;--accent-dim:#0099bb;--accent-glow:rgba(0,212,255,.08);--red:#e94560;--green:#00b894;--amber:#f0a500;--text:#e8e8f0;--text-dim:#8888a0;--text-muted:#55556a;--mono:'JetBrains Mono','Fira Code',monospace;--sans:'Inter',-apple-system,sans-serif;--sidebar-w:220px}
    body.expert-mode{--accent:#f0a500;--accent-dim:#cc8800;--accent-glow:rgba(240,165,0,.08)}
    *{margin:0;padding:0;box-sizing:border-box}
    html{font-size:14px}
    body{font-family:var(--sans);background:var(--bg-deep);color:var(--text);min-height:100vh}
    .sidebar{position:fixed;top:0;left:0;width:var(--sidebar-w);height:100vh;background:var(--bg-main);border-right:1px solid var(--border);display:flex;flex-direction:column;z-index:100}
    .sidebar-brand{padding:1.2rem 1rem;border-bottom:1px solid var(--border)}
    .sidebar-brand h1{font-family:var(--mono);font-size:1rem;font-weight:600;color:var(--accent);letter-spacing:-.02em}
    .sidebar-brand .host{font-size:.72rem;color:var(--text-muted);font-family:var(--mono);margin-top:.2rem}
    .sidebar-nav{flex:1;padding:.5rem 0;overflow-y:auto}
    .nav-section-title{font-size:.65rem;font-weight:600;text-transform:uppercase;letter-spacing:.08em;color:var(--text-muted);padding:.4rem 1rem}
    .nav-item{display:flex;align-items:center;gap:.6rem;padding:.5rem 1rem;color:var(--text-dim);text-decoration:none;font-size:.85rem;font-weight:500;cursor:pointer;transition:all .15s;border-left:2px solid transparent}
    .nav-item:hover{color:var(--text);background:var(--bg-hover)}
    .nav-item.active{color:var(--accent);background:var(--accent-glow);border-left-color:var(--accent)}
    .nav-icon{width:16px;text-align:center;font-size:.8rem;opacity:.7}
    .nav-item.active .nav-icon{opacity:1}
    .sidebar-footer{padding:.8rem 1rem;border-top:1px solid var(--border)}
    .mode-toggle{display:flex;background:var(--bg-deep);border-radius:4px;overflow:hidden;border:1px solid var(--border)}
    .mode-btn{flex:1;padding:.35rem;border:none;cursor:pointer;font-size:.7rem;font-weight:600;font-family:var(--mono);background:transparent;color:var(--text-muted);transition:all .15s;text-transform:uppercase;letter-spacing:.05em}
    .mode-btn.active{background:var(--accent);color:var(--bg-deep)}
    .main{margin-left:var(--sidebar-w);min-height:100vh}
    .topbar{position:sticky;top:0;z-index:50;background:rgba(13,13,18,.85);backdrop-filter:blur(12px);border-bottom:1px solid var(--border);padding:.6rem 1.5rem;display:flex;align-items:center;justify-content:space-between}
    .breadcrumb{font-family:var(--mono);font-size:.78rem;color:var(--text-dim)}
    .breadcrumb span{color:var(--accent)}
    .topbar-status{display:flex;align-items:center;gap:1.5rem;font-family:var(--mono);font-size:.72rem;color:var(--text-muted)}
    .status-dot{display:inline-block;width:6px;height:6px;border-radius:50%;background:var(--green);margin-right:.3rem}
    .content{padding:1.5rem;max-width:1000px}
    .page-header{margin-bottom:1.5rem}
    .page-header h2{font-size:1.3rem;font-weight:700;margin-bottom:.3rem}
    .page-header p{font-size:.82rem;color:var(--text-dim)}
    .card{background:var(--bg-surface);border:1px solid var(--border);border-radius:6px;margin-bottom:1rem;overflow:hidden}
    .card-header{padding:.7rem 1rem;border-bottom:1px solid var(--border);display:flex;align-items:center;justify-content:space-between}
    .card-header h3{font-size:.82rem;font-weight:600;font-family:var(--mono)}
    .card-body{padding:.5rem}
    .chk-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:.3rem}
    .chk-item{display:flex;align-items:center;gap:.6rem;padding:.5rem .7rem;border-radius:4px;cursor:pointer;transition:background .12s}
    .chk-item:hover{background:var(--bg-hover)}
    .chk-item input[type=checkbox]{accent-color:var(--accent);width:14px;height:14px}
    .chk-name{font-size:.85rem;font-weight:500}
    .chk-desc{font-size:.7rem;color:var(--text-muted);margin-top:.1rem}
    .status-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:.5rem}
    .status-cell{background:var(--bg-surface);border:1px solid var(--border);border-radius:6px;padding:1rem}
    .status-cell-label{font-size:.68rem;font-weight:600;text-transform:uppercase;letter-spacing:.06em;color:var(--text-muted);margin-bottom:.4rem}
    .status-cell-value{font-family:var(--mono);font-size:.88rem;color:var(--accent)}
    .status-cell-value.mono{font-size:.8rem;color:var(--text)}
    .preview-compare{padding:.6rem .7rem}
    .preview-compare + .preview-compare{border-top:1px solid var(--border)}
    .preview-compare-head{margin-bottom:.6rem}
    .preview-selection{background:var(--bg-deep);border:1px solid var(--border);border-radius:6px;padding:.75rem}
    .preview-pill-row{display:flex;flex-wrap:wrap;gap:.4rem}
    .flag-row{display:flex;align-items:center;justify-content:space-between;padding:.45rem .7rem;border-radius:4px;transition:background .12s}
    .flag-row:hover{background:var(--bg-hover)}
    .flag-path{font-family:var(--mono);font-size:.76rem;color:var(--accent-dim)}
    .flag-val{font-family:var(--mono);font-size:.76rem;padding:.15rem .5rem;border-radius:3px;background:var(--bg-deep);border:1px solid var(--border)}
    .flag-val.bool-true{color:var(--green);border-color:var(--green)}
    .flag-val.bool-false{color:var(--red);border-color:var(--red)}
    .btn{display:inline-flex;align-items:center;gap:.4rem;padding:.5rem 1.2rem;border:1px solid var(--border);border-radius:4px;cursor:pointer;font-size:.8rem;font-weight:600;font-family:var(--mono);transition:all .15s;background:var(--bg-surface);color:var(--text-dim)}
    .btn:hover{border-color:var(--border-bright);color:var(--text)}
    .btn-accent{background:var(--accent);border-color:var(--accent);color:var(--bg-deep)}
    .btn-accent:hover{background:var(--accent-dim)}
    .btn-group{display:flex;gap:.5rem;margin-top:1rem}
    .rb-idle{color:var(--text-muted)}.rb-running{color:var(--accent);animation:pulse 1s infinite}.rb-ok{color:var(--green)}.rb-fail{color:var(--red)}
    @keyframes pulse{0%,100%{opacity:1}50%{opacity:.4}}
    .expert-only{display:none}
    body.expert-mode .expert-only{display:block}
    .tag{display:inline-block;padding:.1rem .4rem;background:var(--bg-deep);border:1px solid var(--border);border-radius:3px;font-size:.65rem;font-family:var(--mono);color:var(--text-muted)}
    pre{white-space:pre-wrap;font-family:var(--mono);font-size:.76rem;color:var(--red);max-height:300px;overflow-y:auto;padding:.8rem;background:var(--bg-deep);border-radius:4px;border:1px solid var(--border)}
  '';
}
