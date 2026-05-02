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
    h.raw(r#"<script>function submitRoleForm(e,k){var f=document.getElementById(k+'-role-form'),c=f.closest('.card-body'),x=c.querySelectorAll('input[type=checkbox]:checked');f.querySelector('[name=roles]').value=Array.from(x).map(function(a){return a.value}).join(',');htmx.trigger(f,'submit')}</script>"#);
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
            nav_section(h, "Configuration", &[("⌘", "host", "Host Roles"), ("⌂", "home", "User Profile"), ("◆", "packages", "Packages"), ("⚑", "flags", "Module Flags")]);
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
            let expert = if *page == "packages" || *page == "flags" { " expert-only" } else { "" };
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
                role_card(h, &data.host_roles, "host roles", "/roles/host", "host");
            });
            page_block(h, "home", false, |h| {
                page_header(h, "User Profile", "Apps and tools for your user");
                role_card(h, &data.home_roles, "user profile", "/roles/home", "home");
            });
            page_block(h, "packages", true, |h| {
                page_header(h, "Packages", "System tags and user packages");
                packages_section(h, data);
            });
            page_block(h, "flags", true, |h| {
                page_header(h, "Module Flags", "Raw NixOS module toggles");
                flags_section(h, data);
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
    });
    h.elem("div", &[("class", "card")], |h| {
        h.elem("div", &[("class", "card-header")], |h| h.elem("h3", &[], |h| h.raw("Active Host Roles")));
        h.elem("div", &[("class", "card-body")], |h| {
            h.elem("div", &[("class", "chk-grid")], |h| {
                for r in &data.host_roles {
                    h.elem("div", &[("class", "chk-item"), ("style", "cursor:default")], |h| {
                        h.raw("<span style=\"color:var(--green)\">●</span>");
                        h.elem("div", &[], |h| {
                            h.elem("div", &[("class", "chk-name")], |h| h.raw(r));
                            h.elem("div", &[("class", "chk-desc")], |h| h.raw(model::role_desc(r)));
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

fn role_card(h: &mut H, active: &[String], title: &str, endpoint: &str, kind: &str) {
    h.elem("div", &[("class", "card")], |h| {
        h.elem("div", &[("class", "card-header")], |h| h.elem("h3", &[], |h| h.raw(title)));
        h.elem("div", &[("class", "card-body")], |h| {
            h.elem("div", &[("class", "chk-grid")], |h| {
                for role in model::known_roles() {
                    if model::role_desc(&role.name).is_empty() { continue; }
                    let checked = if active.contains(&role.name) { " checked" } else { "" };
                    let onchange = format!("x-on:change=\"submitRoleForm('{}','{}')\"", endpoint, kind);
                    h.elem("label", &[("class", "chk-item")], |h| {
                        h.void("input", &[("type", "checkbox"), ("name", "role"), ("value", &role.name), ("checked", checked), ("onchange", &onchange)]);
                        h.elem("div", &[], |h| {
                            h.elem("div", &[("class", "chk-name")], |h| h.raw(&role.name));
                            h.elem("div", &[("class", "chk-desc")], |h| h.raw(model::role_desc(&role.name)));
                        });
                    });
                }
            });
        });
    });
    h.raw(&format!("<form id=\"{}-role-form\" hx-post=\"{}\" hx-target=\"#{}-roles\" hx-swap=\"innerHTML\" style=\"display:none\"><input type=\"hidden\" name=\"roles\"></form>", kind, endpoint, kind));
    h.raw(&format!("<div id=\"{}-roles\"></div>", kind));
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
        h.elem("div", &[("class", "card-header")], |h| { h.elem("h3", &[], |h| h.raw("validate")); h.elem("span", &[("class", "tag")], |h| h.raw("nix flake check")); });
        h.elem("div", &[("class", "card-body")], |h| {
            h.elem("p", &[("style", "font-size:0.82rem;color:var(--text-dim);margin-bottom:0.8rem")], |h| h.raw("Evaluation, formatting, and pre-commit checks."));
            h.elem("div", &[("class", "btn-group")], |h| h.raw(r##"<button class="btn" hx-post="/validate" hx-target="#validate-output" hx-swap="innerHTML">◇ Check</button>"##));
        });
    });
    h.raw("<div id=\"rebuild-output\" style=\"margin-top:1rem\"></div><div id=\"validate-output\" style=\"margin-top:1rem\"></div>");
}

pub fn render_roles_section(data: &AppData, kind: &str) -> String {
    let mut h = H::new();
    let active = if kind == "host" { &data.host_roles } else { &data.home_roles };
    let title = if kind == "host" { "host roles" } else { "user profile" };
    let endpoint = if kind == "host" { "/roles/host" } else { "/roles/home" };
    role_card(&mut h, active, title, endpoint, kind);
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

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    fn sample_data() -> AppData {
        AppData {
            host_name: "omen".into(),
            host_roles: vec!["desktop".into(), "gaming".into()],
            home_roles: vec!["core".into(), "dev".into()],
            system_tags: vec![("desktop".into(), true), ("chat".into(), false)],
            home_packages: vec![("nautilus".into(), true), ("comma".into(), false)],
            module_flags: vec![
                ("lucy.desktop.enable".into(), "true".into()),
                ("programs.foo.enable".into(), "false".into()),
            ],
            available_roles: vec!["core".into(), "desktop".into(), "dev".into(), "gaming".into()],
            rebuild_running: false,
            rebuild_ok: true,
            rebuild_log: String::new(),
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
        assert!(html.contains("/style.css"));
    }

    #[test]
    fn page_includes_active_role_content() {
        let html = page(&sample_data());
        assert!(html.contains("desktop"));
        assert!(html.contains("gaming"));
        assert!(html.contains("Compositor, terminal, browser, chat"));
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
}
