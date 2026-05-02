use crate::state::AppData;
use crate::model;

pub struct H { buf: String }

impl H {
    pub fn new() -> Self { Self { buf: String::with_capacity(16384) } }
    pub fn finish(self) -> String { self.buf }
    pub fn raw(&mut self, s: &str) { self.buf.push_str(s); }
    pub fn esc(&mut self, s: &str) {
        for c in s.chars() {
            match c {
                '&' => self.buf.push_str("&amp;"), '<' => self.buf.push_str("&lt;"),
                '>' => self.buf.push_str("&gt;"), '"' => self.buf.push_str("&quot;"),
                _ => self.buf.push(c),
            }
        }
    }
    pub fn elem(&mut self, tag: &str, attrs: &[(&str, &str)], inner: impl FnOnce(&mut H)) {
        self.buf.push('<'); self.buf.push_str(tag);
        for (k, v) in attrs { self.buf.push(' '); self.buf.push_str(k); self.buf.push_str("=\""); self.buf.push_str(v); self.buf.push('"'); }
        self.buf.push('>'); inner(self);
        self.buf.push_str("</"); self.buf.push_str(tag); self.buf.push('>');
    }
    pub fn void(&mut self, tag: &str, attrs: &[(&str, &str)]) {
        self.buf.push('<'); self.buf.push_str(tag);
        for (k, v) in attrs { self.buf.push(' '); self.buf.push_str(k); self.buf.push_str("=\""); self.buf.push_str(v); self.buf.push('"'); }
        self.buf.push_str("/>");
    }
}

pub fn page(data: &AppData) -> String {
    let mut h = H::new();
    head(&mut h, data);
    h.raw(r#"<body x-data="{mode:localStorage.getItem('uiMode')||'user',page:'overview'}" x-init="$watch('mode',v=>{localStorage.setItem('uiMode',v);document.body.classList.toggle('expert-mode',v==='expert')})">"#);
    sidebar(&mut h, data);
    main_content(&mut h, data);
    h.raw(r#"<script>function submitRoleForm(e,k){var f=document.getElementById(k+'-role-form'),c=f.closest('.card-body'),x=c.querySelectorAll('input[type=checkbox]:checked');f.querySelector('[name=roles]').value=Array.from(x).map(function(a){return a.value}).join(',');htmx.trigger(f,'submit')}function submitPresetForm(){var f=document.getElementById('host-preset-form'),c=f.closest('.card-body'),x=c.querySelectorAll('input[name=preset]:checked');f.querySelector('[name=presets]').value=Array.from(x).map(function(a){return a.value}).join(',');htmx.trigger(f,'submit')}function submitBundleForm(){var f=document.getElementById('home-bundle-form'),c=f.closest('.card-body'),x=c.querySelectorAll('input[name=bundle]:checked');f.querySelector('[name=bundles]').value=Array.from(x).map(function(a){return a.value}).join(',');htmx.trigger(f,'submit')}</script>"#);
    h.raw("</body></html>");
    h.finish()
}

fn head(h: &mut H, data: &AppData) {
    h.raw("<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"UTF-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1.0\"><title>");
    h.esc(&data.host_name);
    h.raw(" — nixfiles</title>");
    h.raw(r#"<script src="https://unpkg.com/htmx.org@1.9.12"></script><script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"></script><link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet"><link rel="stylesheet" href="/style.css"></head>"#);
}

fn sidebar(h: &mut H, data: &AppData) {
    h.elem("aside", &[("class", "sidebar")], |h| {
        h.elem("div", &[("class", "sidebar-brand")], |h| {
            h.elem("h1", &[], |h| h.raw("nixfiles"));
            h.elem("div", &[("class", "host")], |h| { h.esc(&data.host_name); h.raw(" · x86_64-linux"); });
        });
        h.elem("nav", &[("class", "sidebar-nav")], |h| {
            nav_section(h, "System", &[("◉", "overview", "Overview")]);
            nav_section(h, "Configuration", &[("⌘", "host", "Host Roles"), ("⌂", "home", "User Profile"), ("◆", "packages", "Packages"), ("⚑", "flags", "Module Flags"), ("◇", "preview", "Preview")]);
            nav_section(h, "Operations", &[("▶", "actions", "Rebuild & Check")]);
        });
        h.elem("div", &[("class", "sidebar-footer")], |h| {
            h.elem("div", &[("class", "mode-toggle")], |h| {
                h.raw(r#"<button class="mode-btn" :class="{active:mode==='user'}" @click="mode='user'">user</button>"#);
                h.raw(r#"<button class="mode-btn" :class="{active:mode==='expert'}" @click="mode='expert'">expert</button>"#);
            });
        });
    });
}

fn nav_section(h: &mut H, title: &str, items: &[(&str, &str, &str)]) {
    h.elem("div", &[("class", "nav-section")], |h| {
        h.elem("div", &[("class", "nav-section-title")], |h| h.raw(title));
        for (icon, page, label) in items {
            let expert = if *page == "packages" || *page == "flags" || *page == "preview" { " expert-only" } else { "" };
            let cls = format!("nav-item{}", expert);
            let cls_active = format!(":class={{active:page==='{}'}}", page);
            let onclick = format!("@click=\"page='{}'\"", page);
            h.raw(&format!("<a class=\"{}\" {} {}>", cls, cls_active, onclick));
            h.elem("span", &[("class", "nav-icon")], |h| h.raw(icon));
            h.raw(" ");
            h.raw(label);
            h.raw("</a>");
        }
    });
}

fn main_content(h: &mut H, data: &AppData) {
    h.elem("div", &[("class", "main")], |h| {
        // topbar
        h.elem("div", &[("class", "topbar")], |h| {
            h.elem("div", &[("class", "breadcrumb")], |h| {
                h.raw("nixfiles / <span>"); h.esc(&data.host_name); h.raw("</span> / <span x-text=\"page\"></span>");
            });
            h.elem("div", &[("class", "topbar-status")], |h| {
                h.raw("<span><span class=\"status-dot\"></span>online</span><span>");
                h.raw(&data.rebuild_status_html());
                h.raw("</span>");
            });
        });
        // pages
        h.elem("div", &[("class", "content")], |h| {
            page_block(h, "overview", false, |h| overview(h, data));
            page_block(h, "host", false, |h| {
                page_header(h, "Host Roles", "Define what this machine does");
                role_card(h, data, &data.host_roles, "host roles", "/roles/host", "host");
                host_presets_card(h, data);
            });
            page_block(h, "home", false, |h| {
                page_header(h, "User Profile", "Apps and tools for your user");
                role_card(h, data, &data.home_roles, "user profile", "/roles/home", "home");
                bundle_card(h, data);
            });
            page_block(h, "packages", true, |h| {
                page_header(h, "Packages", "System tags and user packages");
                packages_section(h, data);
            });
            page_block(h, "flags", true, |h| {
                page_header(h, "Module Flags", "Raw NixOS module toggles");
                flags_section(h, data);
            });
            page_block(h, "preview", true, |h| {
                page_header(h, "Preview", "Resolved roles, presets, and bundles before rebuild");
                preview_section(h, data);
            });
            page_block(h, "actions", false, |h| {
                page_header(h, "Rebuild & Check", "Apply changes and validate");
                actions_section(h);
            });
        });
    });
}

fn page_block(h: &mut H, name: &str, expert: bool, content: impl FnOnce(&mut H)) {
    h.elem("div", &[("x-show", &format!("page==='{}'", name)), ("class", if expert { "expert-only" } else { "" })], content);
}

fn page_header(h: &mut H, title: &str, desc: &str) {
    h.elem("div", &[("class", "page-header")], |h| {
        h.elem("h2", &[], |h| h.raw(title));
        h.elem("p", &[], |h| h.raw(desc));
    });
}

fn overview(h: &mut H, data: &AppData) {
    page_header(h, "Overview", "System state and active configuration");
    h.elem("div", &[("class", "status-grid")], |h| {
        status_cell(h, "Host Roles", &data.host_roles.join(" "));
        status_cell(h, "User Roles", &data.home_roles.join(" "));
        let n = data.module_flags.iter().filter(|(_, v)| v == "true").count();
        status_cell(h, "Active Flags", &format!("{} enabled", n));
        let n = data.system_tags.iter().filter(|(_, e)| *e).count();
        status_cell(h, "System Packages", &format!("{} tags", n));
        let n = data.home_packages.iter().filter(|(_, e)| *e).count();
        status_cell(h, "User Packages", &format!("{} enabled", n));
        status_cell_html(h, "Build Status", &data.rebuild_status_html());
        status_cell_html(h, "Framework", &data.framework_validation_status_html());
    });
    framework_validation_block(h, data);
    h.elem("div", &[("class", "card")], |h| {
        h.elem("div", &[("class", "card-header")], |h| h.elem("h3", &[], |h| h.raw("Active Host Roles")));
        h.elem("div", &[("class", "card-body")], |h| {
            h.elem("div", &[("class", "chk-grid")], |h| {
                for r in &data.host_roles {
                    h.elem("div", &[("class", "chk-item"), ("style", "cursor:default")], |h| {
                        h.raw("<span style=\"color:var(--green)\">●</span>");
                        h.elem("div", &[], |h| {
                            h.elem("div", &[("class", "chk-name")], |h| h.raw(r));
                            h.elem("div", &[("class", "chk-desc")], |h| h.raw(data.role_info(r).map(|info| info.description.as_str()).unwrap_or("")));
                        });
                    });
                }
            });
        });
    });
    h.elem("div", &[("class", "card")], |h| {
        h.elem("div", &[("class", "card-header")], |h| h.elem("h3", &[], |h| h.raw("Active Package Tags")));
        h.elem("div", &[("class", "card-body")], |h| {
            h.elem("div", &[("class", "chk-grid")], |h| {
                for (tag, _) in data.system_tags.iter().filter(|(_, e)| *e) {
                    h.elem("div", &[("class", "chk-item"), ("style", "cursor:default")], |h| {
                        h.raw("<span style=\"color:var(--green)\">●</span>");
                        h.elem("div", &[], |h| {
                            h.elem("div", &[("class", "chk-name")], |h| h.raw(tag));
                            h.elem("div", &[("class", "chk-desc")], |h| h.raw(model::tag_desc(tag)));
                        });
                    });
                }
            });
        });
    });
    named_metadata_block(h, "Active Presets", &data.preset_names_for_host_roles(), &data.preset_info);
    named_bundle_block(h, "Active Bundles", &data.bundle_names_for_home_roles(), &data.bundle_info);
}

fn status_cell(h: &mut H, label: &str, value: &str) {
    h.elem("div", &[("class", "status-cell")], |h| {
        h.elem("div", &[("class", "status-cell-label")], |h| h.raw(label));
        h.elem("div", &[("class", "status-cell-value mono")], |h| h.raw(value));
    });
}

fn status_cell_html(h: &mut H, label: &str, value: &str) {
    h.elem("div", &[("class", "status-cell")], |h| {
        h.elem("div", &[("class", "status-cell-label")], |h| h.raw(label));
        h.elem("div", &[("class", "status-cell-value")], |h| h.raw(value));
    });
}

fn role_card(h: &mut H, data: &AppData, active: &[String], title: &str, endpoint: &str, kind: &str) {
    h.elem("div", &[("class", "card")], |h| {
        h.elem("div", &[("class", "card-header")], |h| h.elem("h3", &[], |h| h.raw(title)));
        h.elem("div", &[("class", "card-body")], |h| {
            h.elem("div", &[("class", "chk-grid")], |h| {
                for role in data.role_infos_for(kind) {
                    let checked = if active.contains(&role.name) { " checked" } else { "" };
                    let onchange = format!("x-on:change=\"submitRoleForm('{}','{}')\"", endpoint, kind);
                    h.elem("label", &[("class", "chk-item")], |h| {
                        h.void("input", &[("type", "checkbox"), ("name", "role"), ("value", &role.name), ("checked", checked), ("onchange", &onchange)]);
                        h.elem("div", &[], |h| {
                            h.elem("div", &[("class", "chk-name")], |h| h.raw(&role.name));
                            h.elem("div", &[("class", "chk-desc")], |h| h.raw(&role.description));
                            role_hints(h, role, kind, active);
                        });
                    });
                }
            });
        });
    });
    h.raw(&format!("<form id=\"{}-role-form\" hx-post=\"{}\" hx-target=\"#{}-roles\" hx-swap=\"innerHTML\" style=\"display:none\"><input type=\"hidden\" name=\"roles\"></form>", kind, endpoint, kind));
    h.raw(&format!("<div id=\"{}-roles\"></div>", kind));
}

fn host_presets_card(h: &mut H, data: &AppData) {
    h.elem("div", &[("class", "card")], |h| {
        h.elem("div", &[("class", "card-header")], |h| h.elem("h3", &[], |h| h.raw("host presets")));
        h.elem("div", &[("class", "card-body")], |h| {
            h.elem("div", &[("class", "chk-grid")], |h| {
                for preset in data.preset_info.iter().filter(|preset| preset.targets.iter().any(|t| t == "host")) {
                    let checked = if data.host_presets.contains(&preset.name) { " checked" } else { "" };
                    let onchange = "x-on:change=\"submitPresetForm()\"";
                    h.elem("label", &[("class", "chk-item")], |h| {
                        h.void("input", &[("type", "checkbox"), ("name", "preset"), ("value", &preset.name), ("checked", checked), ("onchange", onchange)]);
                        h.elem("div", &[], |h| {
                            h.elem("div", &[("class", "chk-name")], |h| h.raw(&preset.name));
                            h.elem("div", &[("class", "chk-desc")], |h| h.raw(&preset.description));
                        });
                    });
                }
            });
            h.raw(r##"<form id="host-preset-form" hx-post="/presets/host" hx-target="#host-presets" hx-swap="innerHTML" style="display:none"><input type="hidden" name="presets"></form><div id="host-presets"></div>"##);
        });
    });
}

fn bundle_card(h: &mut H, data: &AppData) {
    h.elem("div", &[("class", "card")], |h| {
        h.elem("div", &[("class", "card-header")], |h| h.elem("h3", &[], |h| h.raw("user bundles")));
        h.elem("div", &[("class", "card-body")], |h| {
            h.elem("div", &[("class", "chk-grid")], |h| {
                for bundle in data.bundle_info.iter().filter(|b| b.targets.iter().any(|t| t == "home")) {
                    let checked = if data.home_bundles.contains(&bundle.name) { " checked" } else { "" };
                    let onchange = "x-on:change=\"submitBundleForm()\"";
                    h.elem("label", &[("class", "chk-item")], |h| {
                        h.void("input", &[("type", "checkbox"), ("name", "bundle"), ("value", &bundle.name), ("checked", checked), ("onchange", onchange)]);
                        h.elem("div", &[], |h| {
                            h.elem("div", &[("class", "chk-name")], |h| h.raw(&bundle.name));
                            h.elem("div", &[("class", "chk-desc")], |h| h.raw(&bundle.description));
                        });
                    });
                }
            });
            h.raw(r##"<form id="home-bundle-form" hx-post="/bundles/home" hx-target="#home-bundles" hx-swap="innerHTML" style="display:none"><input type="hidden" name="bundles"></form><div id="home-bundles"></div>"##);
        });
    });
}

fn role_hints(h: &mut H, role: &crate::state::RoleInfo, kind: &str, active: &[String]) {
    let requires = if kind == "host" { &role.requires_host } else { &role.requires_home };
    let conflicts = if kind == "host" { &role.conflicts_host } else { &role.conflicts_home };
    if requires.is_empty() && conflicts.is_empty() { return; }
    let mut hints = vec![];
    if !requires.is_empty() {
        let missing: Vec<&String> = requires.iter().filter(|name| !active.contains(name)).collect();
        if missing.is_empty() {
            hints.push(format!("requires {}", requires.join(", ")));
        } else {
            hints.push(format!("needs {}", missing.iter().map(|s| s.as_str()).collect::<Vec<_>>().join(", ")));
        }
    }
    if !conflicts.is_empty() {
        let selected: Vec<&String> = conflicts.iter().filter(|name| active.contains(name)).collect();
        if selected.is_empty() {
            hints.push(format!("conflicts {}", conflicts.join(", ")));
        } else {
            hints.push(format!("conflicts with {}", selected.iter().map(|s| s.as_str()).collect::<Vec<_>>().join(", ")));
        }
    }
    for hint in hints {
        h.elem("div", &[("class", "chk-desc")], |h| h.raw(&hint));
    }
}

fn named_metadata_block(h: &mut H, title: &str, names: &[String], items: &[crate::state::PresetInfo]) {
    if names.is_empty() { return; }
    h.elem("div", &[("class", "card")], |h| {
        h.elem("div", &[("class", "card-header")], |h| h.elem("h3", &[], |h| h.raw(title)));
        h.elem("div", &[("class", "card-body")], |h| {
            h.elem("div", &[("class", "chk-grid")], |h| {
                for name in names {
                    if let Some(item) = items.iter().find(|item| &item.name == name) {
                        h.elem("div", &[("class", "chk-item"), ("style", "cursor:default")], |h| {
                            h.raw("<span style=\"color:var(--green)\">●</span>");
                            h.elem("div", &[], |h| {
                                h.elem("div", &[("class", "chk-name")], |h| h.raw(&item.name));
                                h.elem("div", &[("class", "chk-desc")], |h| h.raw(&item.description));
                            });
                        });
                    }
                }
            });
        });
    });
}

fn named_bundle_block(h: &mut H, title: &str, names: &[String], items: &[crate::state::BundleInfo]) {
    if names.is_empty() { return; }
    h.elem("div", &[("class", "card")], |h| {
        h.elem("div", &[("class", "card-header")], |h| h.elem("h3", &[], |h| h.raw(title)));
        h.elem("div", &[("class", "card-body")], |h| {
            h.elem("div", &[("class", "chk-grid")], |h| {
                for name in names {
                    if let Some(item) = items.iter().find(|item| &item.name == name) {
                        h.elem("div", &[("class", "chk-item"), ("style", "cursor:default")], |h| {
                            h.raw("<span style=\"color:var(--green)\">●</span>");
                            h.elem("div", &[], |h| {
                                h.elem("div", &[("class", "chk-name")], |h| h.raw(&item.name));
                                h.elem("div", &[("class", "chk-desc")], |h| h.raw(&item.description));
                            });
                        });
                    }
                }
            });
        });
    });
}

fn packages_section(h: &mut H, data: &AppData) {
    h.elem("div", &[("class", "card")], |h| {
        h.elem("div", &[("class", "card-header")], |h| {
            h.elem("h3", &[], |h| h.raw("system packages"));
            h.elem("span", &[("class", "tag")], |h| h.raw("by tag"));
        });
        h.elem("div", &[("class", "card-body")], |h| {
            h.elem("div", &[("class", "chk-grid")], |h| {
                for (tag, enabled) in &data.system_tags {
                    let checked = if *enabled { " checked" } else { "" };
                    let next = if *enabled { "false" } else { "true" };
                    let vals = format!("{{\"tag\":\"{}\",\"enabled\":{}}}", tag, next);
                    h.elem("label", &[("class", "chk-item")], |h| {
                        h.void("input", &[("type", "checkbox"), ("checked", checked), ("hx-post", "/tags/system"), ("hx-vals", &vals), ("hx-target", "#packages"), ("hx-swap", "innerHTML")]);
                        h.elem("div", &[], |h| {
                            h.elem("div", &[("class", "chk-name")], |h| h.raw(tag));
                            h.elem("div", &[("class", "chk-desc")], |h| h.raw(model::tag_desc(tag)));
                        });
                    });
                }
            });
        });
    });
    h.elem("div", &[("class", "card")], |h| {
        h.elem("div", &[("class", "card-header")], |h| {
            h.elem("h3", &[], |h| h.raw("user packages"));
            h.elem("span", &[("class", "tag")], |h| h.raw("home-manager"));
        });
        h.elem("div", &[("class", "card-body")], |h| {
            h.elem("div", &[("class", "chk-grid")], |h| {
                for (name, enabled) in &data.home_packages {
                    let checked = if *enabled { " checked" } else { "" };
                    let next = if *enabled { "false" } else { "true" };
                    let vals = format!("{{\"name\":\"{}\",\"enabled\":{}}}", name, next);
                    h.elem("label", &[("class", "chk-item")], |h| {
                        h.void("input", &[("type", "checkbox"), ("checked", checked), ("hx-post", "/packages/home"), ("hx-vals", &vals), ("hx-target", "#packages"), ("hx-swap", "innerHTML")]);
                        h.elem("div", &[], |h| {
                            h.elem("div", &[("class", "chk-name")], |h| h.raw(name));
                            h.elem("div", &[("class", "chk-desc")], |h| h.raw(model::home_pkg_desc(name)));
                        });
                    });
                }
            });
        });
    });
    h.raw("<div id=\"packages\"></div>");
}

fn flags_section(h: &mut H, data: &AppData) {
    h.elem("div", &[("class", "card")], |h| {
        h.elem("div", &[("class", "card-header")], |h| {
            h.elem("h3", &[], |h| h.raw("module flags"));
            h.elem("span", &[("class", "tag")], |h| h.raw(&data.module_flags.len().to_string()));
        });
        h.elem("div", &[("class", "card-body")], |h| {
            for (path, value) in &data.module_flags {
                h.elem("div", &[("class", "flag-row")], |h| {
                    h.elem("span", &[("class", "flag-path")], |h| h.raw(path));
                    match value.as_str() {
                        "true" => {
                            let vals = format!("{{\"path\":\"{}\",\"value\":\"false\"}}", path);
                            h.elem("button", &[("class", "flag-val bool-true"), ("hx-post", "/flags"), ("hx-vals", &vals), ("hx-target", "#flags"), ("hx-swap", "innerHTML")], |h| h.raw("true"));
                        }
                        "false" => {
                            let vals = format!("{{\"path\":\"{}\",\"value\":\"true\"}}", path);
                            h.elem("button", &[("class", "flag-val bool-false"), ("hx-post", "/flags"), ("hx-vals", &vals), ("hx-target", "#flags"), ("hx-swap", "innerHTML")], |h| h.raw("false"));
                        }
                        _ => { h.elem("span", &[("class", "flag-val")], |h| h.raw(value)); }
                    }
                });
            }
        });
    });
    h.raw("<div id=\"flags\"></div>");
}

fn actions_section(h: &mut H) {
    h.elem("div", &[("class", "card")], |h| {
        h.elem("div", &[("class", "card-header")], |h| { h.elem("h3", &[], |h| h.raw("rebuild")); h.elem("span", &[("class", "tag")], |h| h.raw("nh os switch")); });
        h.elem("div", &[("class", "card-body")], |h| {
            h.elem("p", &[("style", "font-size:0.82rem;color:var(--text-dim);margin-bottom:0.8rem")], |h| h.raw("Evaluate, build, and activate."));
            h.elem("div", &[("class", "btn-group")], |h| h.raw(r##"<button class="btn btn-accent" hx-post="/rebuild" hx-target="#rebuild-output" hx-swap="innerHTML">▶ Rebuild</button>"##));
        });
    });
    h.elem("div", &[("class", "card")], |h| {
        h.elem("div", &[("class", "card-header")], |h| { h.elem("h3", &[], |h| h.raw("framework validate")); h.elem("span", &[("class", "tag")], |h| h.raw("framework rules")); });
        h.elem("div", &[("class", "card-body")], |h| {
            h.elem("p", &[("style", "font-size:0.82rem;color:var(--text-dim);margin-bottom:0.8rem")], |h| h.raw("Role metadata, requires/conflicts, package refs, and module flag rules."));
            h.elem("div", &[("class", "btn-group")], |h| h.raw(r##"<button class="btn" hx-post="/validate/framework" hx-target="#framework-validation-output" hx-swap="innerHTML">⋄ Framework</button>"##));
        });
    });
    h.elem("div", &[("class", "card")], |h| {
        h.elem("div", &[("class", "card-header")], |h| { h.elem("h3", &[], |h| h.raw("validate")); h.elem("span", &[("class", "tag")], |h| h.raw("nix flake check")); });
        h.elem("div", &[("class", "card-body")], |h| {
            h.elem("p", &[("style", "font-size:0.82rem;color:var(--text-dim);margin-bottom:0.8rem")], |h| h.raw("Evaluation, formatting, and pre-commit checks."));
            h.elem("div", &[("class", "btn-group")], |h| h.raw(r##"<button class="btn" hx-post="/validate" hx-target="#validate-output" hx-swap="innerHTML">◇ Check</button>"##));
        });
    });
    h.raw("<div id=\"rebuild-output\" style=\"margin-top:1rem\"></div><div id=\"framework-validation-output\" style=\"margin-top:1rem\"></div><div id=\"validate-output\" style=\"margin-top:1rem\"></div>");
}

fn preview_section(h: &mut H, data: &AppData) {
    h.elem("div", &[("class", "status-grid")], |h| {
        status_cell(h, "Host Roles", &data.preview.host_roles.join(" "));
        status_cell(h, "Host Presets", &data.preview.host_presets.join(" "));
        status_cell(h, "Home Roles", &data.preview.home_roles.join(" "));
        status_cell(h, "Home Bundles", &data.preview.home_bundles.join(" "));
    });
    h.elem("div", &[("class", "card")], |h| {
        h.elem("div", &[("class", "card-header")], |h| h.elem("h3", &[], |h| h.raw("resolution details")));
        h.elem("div", &[("class", "card-body")], |h| {
            preview_compare_block(h, "Host presets", &data.host_presets, &data.preview.host_presets, "Direct host preset picks merge with role-derived presets.");
            preview_compare_block(h, "Home bundles", &data.home_bundles, &data.preview.home_bundles, "Explicit home bundles override role-derived bundle resolution when set.");
        });
    });
    named_metadata_block(h, "Resolved Host Presets", &data.preview.host_presets, &data.preset_info);
    named_bundle_block(h, "Resolved Home Bundles", &data.preview.home_bundles, &data.bundle_info);
}

fn preview_compare_block(h: &mut H, title: &str, direct: &[String], resolved: &[String], note: &str) {
    h.elem("div", &[("class", "preview-compare")], |h| {
        h.elem("div", &[("class", "preview-compare-head")], |h| {
            h.elem("div", &[("class", "chk-name")], |h| h.raw(title));
            h.elem("div", &[("class", "chk-desc")], |h| h.raw(note));
        });
        h.elem("div", &[("class", "chk-grid")], |h| {
            preview_selection_card(h, "direct", direct);
            preview_selection_card(h, "resolved", resolved);
        });
    });
}

fn preview_selection_card(h: &mut H, label: &str, values: &[String]) {
    h.elem("div", &[("class", "preview-selection")], |h| {
        h.elem("div", &[("class", "status-cell-label")], |h| h.raw(label));
        if values.is_empty() {
            h.elem("div", &[("class", "status-cell-value mono")], |h| h.raw("none"));
        } else {
            h.elem("div", &[("class", "preview-pill-row")], |h| {
                for value in values {
                    h.elem("span", &[("class", "tag")], |h| h.raw(value));
                }
            });
        }
    });
}

fn framework_validation_block(h: &mut H, data: &AppData) {
    h.raw(&render_framework_validation_section(data));
}

pub fn render_framework_validation_section(data: &AppData) -> String {
    let mut h = H::new();
    h.elem("div", &[("class", "card")], |h| {
        h.elem("div", &[("class", "card-header")], |h| {
            h.elem("h3", &[], |h| h.raw("framework validation"));
            h.elem("span", &[("class", "tag")], |h| h.raw(if data.framework_validation_ok { "ok" } else { "issues" }));
        });
        h.elem("div", &[("class", "card-body")], |h| {
            if data.framework_validation_ok {
                h.elem("div", &[("class", "chk-desc")], |h| h.raw("Role metadata, dependencies, conflicts, package refs, and module flags are valid."));
            } else {
                h.elem("div", &[("class", "chk-grid")], |h| {
                    for msg in &data.framework_validation_errors {
                        h.elem("div", &[("class", "chk-item"), ("style", "cursor:default")], |h| {
                            h.raw("<span style=\"color:var(--red)\">●</span>");
                            h.elem("div", &[], |h| {
                                h.elem("div", &[("class", "chk-name")], |h| h.raw("Validation error"));
                                h.elem("div", &[("class", "chk-desc")], |h| h.esc(msg));
                            });
                        });
                    }
                });
            }
        });
    });
    h.finish()
}

pub fn render_roles_section(data: &AppData, kind: &str) -> String {
    let mut h = H::new();
    let active = if kind == "host" { &data.host_roles } else { &data.home_roles };
    let title = if kind == "host" { "host roles" } else { "user profile" };
    let endpoint = if kind == "host" { "/roles/host" } else { "/roles/home" };
    role_card(&mut h, data, active, title, endpoint, kind);
    h.finish()
}

pub fn render_host_presets_section(data: &AppData) -> String {
    let mut h = H::new();
    host_presets_card(&mut h, data);
    h.finish()
}

pub fn render_bundle_section(data: &AppData) -> String {
    let mut h = H::new();
    bundle_card(&mut h, data);
    h.finish()
}

pub fn render_packages_section(data: &AppData) -> String {
    let mut h = H::new();
    packages_section(&mut h, data);
    h.finish()
}

pub fn render_flags_section(data: &AppData) -> String {
    let mut h = H::new();
    flags_section(&mut h, data);
    h.finish()
}

pub fn render_preview_section(data: &AppData) -> String {
    let mut h = H::new();
    preview_section(&mut h, data);
    h.finish()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    fn sample_data() -> AppData {
        AppData {
            host_name: "omen".into(),
            host_roles: vec!["desktop".into(), "gaming".into()],
            host_presets: vec!["gaming-base".into()],
            home_roles: vec!["core".into(), "dev".into()],
            home_bundles: vec!["core".into(), "dev".into()],
            system_tags: vec![("desktop".into(), true), ("chat".into(), false)],
            home_packages: vec![("nautilus".into(), true), ("comma".into(), false)],
            module_flags: vec![
                ("lucy.desktop.enable".into(), "true".into()),
                ("programs.foo.enable".into(), "false".into()),
            ],
            available_roles: vec!["core".into(), "desktop".into(), "dev".into(), "gaming".into()],
            role_info: vec![
                crate::state::RoleInfo { name: "core".into(), description: "Base shell, editor, git, and Nix tooling".into(), targets: vec!["home".into()], presets: vec![], bundles: vec!["core".into()], requires_host: vec![], requires_home: vec![], conflicts_host: vec![], conflicts_home: vec![] },
                crate::state::RoleInfo { name: "desktop".into(), description: "Desktop environment, GUI apps, and compositor integration".into(), targets: vec!["host".into(), "home".into()], presets: vec![], bundles: vec!["desktop".into()], requires_host: vec![], requires_home: vec!["core".into()], conflicts_host: vec![], conflicts_home: vec![] },
                crate::state::RoleInfo { name: "dev".into(), description: "Development tools, IDEs, and device tooling".into(), targets: vec!["host".into(), "home".into()], presets: vec![], bundles: vec!["dev".into()], requires_host: vec![], requires_home: vec!["core".into()], conflicts_host: vec![], conflicts_home: vec![] },
                crate::state::RoleInfo { name: "gaming".into(), description: "Gaming stack with Steam, GameMode, and performance presets".into(), targets: vec!["host".into()], presets: vec!["gaming-base".into(), "gaming-performance".into(), "gaming-steam".into()], bundles: vec![], requires_host: vec!["desktop".into()], requires_home: vec![], conflicts_host: vec![], conflicts_home: vec![] },
            ],
            preset_info: vec![
                crate::state::PresetInfo { name: "gaming-base".into(), description: "Enable the shared gaming module baseline".into(), targets: vec!["host".into()] },
                crate::state::PresetInfo { name: "gaming-performance".into(), description: "Apply gaming performance tuning and low-latency sysctl settings".into(), targets: vec!["host".into()] },
                crate::state::PresetInfo { name: "gaming-steam".into(), description: "Enable Steam, GameMode, Gamescope, and MangoHud".into(), targets: vec!["host".into()] },
            ],
            bundle_info: vec![
                crate::state::BundleInfo { name: "core".into(), description: "Base shell, editor, SSH, and Nix workflow configuration".into(), targets: vec!["home".into()] },
                crate::state::BundleInfo { name: "desktop".into(), description: "Desktop GUI apps, stylix, and flatpak desktop integrations".into(), targets: vec!["home".into()] },
                crate::state::BundleInfo { name: "dev".into(), description: "Extra development applications for the home profile".into(), targets: vec!["home".into()] },
            ],
            preview: crate::state::PreviewData {
                host_roles: vec!["desktop".into(), "gaming".into()],
                host_presets: vec!["gaming-base".into(), "gaming-performance".into(), "gaming-steam".into()],
                home_roles: vec!["core".into(), "dev".into()],
                home_bundles: vec!["core".into(), "dev".into()],
            },
            rebuild_running: false,
            rebuild_ok: true,
            rebuild_log: String::new(),
            framework_validation_ok: true,
            framework_validation_errors: vec![],
            dotfiles_root: PathBuf::from("/tmp/dotfiles"),
        }
    }

    #[test]
    fn escape_html_entities() {
        let mut h = H::new();
        h.esc("<tag attr=\"x\">&");
        assert_eq!(h.finish(), "&lt;tag attr=&quot;x&quot;&gt;&amp;");
    }

    #[test]
    fn page_contains_core_sections() {
        let html = page(&sample_data());
        assert!(html.contains("<!DOCTYPE html>"));
        assert!(html.contains("Host Roles"));
        assert!(html.contains("User Profile"));
        assert!(html.contains("Rebuild & Check"));
        assert!(html.contains("framework validation"));
        assert!(html.contains("Active Presets"));
        assert!(html.contains("Active Bundles"));
        assert!(html.contains("/style.css"));
    }

    #[test]
    fn page_includes_active_role_content() {
        let html = page(&sample_data());
        assert!(html.contains("desktop"));
        assert!(html.contains("gaming"));
        assert!(html.contains("Desktop environment, GUI apps, and compositor integration"));
    }

    #[test]
    fn render_roles_section_targets_kind() {
        let data = sample_data();
        let host = render_roles_section(&data, "host");
        let home = render_roles_section(&data, "home");
        assert!(host.contains("hx-post=\"/roles/host\""));
        assert!(host.contains("id=\"host-role-form\""));
        assert!(home.contains("hx-post=\"/roles/home\""));
        assert!(home.contains("id=\"home-role-form\""));
    }

    #[test]
    fn render_roles_section_shows_dependency_hints() {
        let data = sample_data();
        let host = render_roles_section(&data, "host");
        let home = render_roles_section(&data, "home");
        assert!(host.contains("requires desktop"));
        assert!(home.contains("requires core"));
    }

    #[test]
    fn render_host_presets_section_contains_presets() {
        let html = render_host_presets_section(&sample_data());
        assert!(html.contains("host presets"));
        assert!(html.contains("gaming-performance"));
    }

    #[test]
    fn render_bundle_section_contains_bundles() {
        let html = render_bundle_section(&sample_data());
        assert!(html.contains("user bundles"));
        assert!(html.contains("hx-post=\"/bundles/home\""));
        assert!(html.contains("Desktop GUI apps"));
    }

    #[test]
    fn render_packages_section_contains_toggle_endpoints() {
        let html = render_packages_section(&sample_data());
        assert!(html.contains("hx-post=\"/tags/system\""));
        assert!(html.contains("hx-post=\"/packages/home\""));
        assert!(html.contains("system packages"));
        assert!(html.contains("user packages"));
    }

    #[test]
    fn render_flags_section_contains_boolean_toggles() {
        let html = render_flags_section(&sample_data());
        assert!(html.contains("lucy.desktop.enable"));
        assert!(html.contains("hx-post=\"/flags\""));
        assert!(html.contains("bool-true"));
        assert!(html.contains("bool-false"));
    }

    #[test]
    fn render_preview_section_contains_resolved_state() {
        let html = render_preview_section(&sample_data());
        assert!(html.contains("Resolved Host Presets"));
        assert!(html.contains("Resolved Home Bundles"));
        assert!(html.contains("resolution details"));
        assert!(html.contains("Direct host preset picks merge with role-derived presets."));
        assert!(html.contains("gaming-performance"));
        assert!(html.contains("core"));
    }
}
