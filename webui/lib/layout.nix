{...}: {
  head = ''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width,initial-scale=1.0">
      <title>nixfiles</title>
      <link rel="stylesheet" href="/style.css">
    </head>
    <body>
      <aside class="sidebar">
        <div class="sidebar-brand">
          <h1>nixfiles</h1>
          <div class="host">omen · x86_64-linux</div>
        </div>
        <nav class="sidebar-nav">
          <div class="nav-section">
            <div class="nav-section-title">Overview</div>
            <a class="nav-item" href="/"><span class="nav-icon">⌂</span> Dashboard</a>
          </div>
          <div class="nav-section">
            <div class="nav-section-title">Configuration</div>
            <a class="nav-item" href="/roles/host"><span class="nav-icon">☺</span> Host Roles</a>
            <a class="nav-item" href="/roles/home"><span class="nav-icon">⌂</span> Home Roles</a>
            <a class="nav-item" href="/presets"><span class="nav-icon">⚙</span> Presets</a>
            <a class="nav-item" href="/bundles"><span class="nav-icon">◫</span> Bundles</a>
          </div>
          <div class="nav-section">
            <div class="nav-section-title">System</div>
            <a class="nav-item" href="/system"><span class="nav-icon">⚛</span> System</a>
            <a class="nav-item" href="/packages"><span class="nav-icon">▦</span> Packages</a>
          </div>
        </nav>
      </aside>
      <main class="main">
  '';

  footer = ''
      </main>
    </body>
    </html>
  '';
}