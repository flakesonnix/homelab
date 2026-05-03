use std::collections::HashSet;
use std::path::{Path, PathBuf};

pub struct RoleInfo {
    pub name: String,
    pub description: String,
    pub targets: Vec<String>,
    pub presets: Vec<String>,
    pub bundles: Vec<String>,
    pub requires_host: Vec<String>,
    pub requires_home: Vec<String>,
    pub conflicts_host: Vec<String>,
    pub conflicts_home: Vec<String>,
}

pub struct PresetInfo {
    pub name: String,
    pub description: String,
    pub targets: Vec<String>,
}

pub struct BundleInfo {
    pub name: String,
    pub description: String,
    pub targets: Vec<String>,
}

pub struct PreviewData {
    pub host_roles: Vec<String>,
    pub host_presets: Vec<String>,
    pub home_roles: Vec<String>,
    pub home_bundles: Vec<String>,
}

pub struct NavItem {
    pub section: String,
    pub page: String,
    pub expert: bool,
    pub icon: String,
    pub label: String,
}

pub struct PageInfo {
    pub name: String,
    pub title: String,
    pub description: String,
}

pub struct ActionInfo {
    pub title: String,
    pub tag: String,
    pub description: String,
    pub endpoint: String,
    pub target: String,
    pub button_class: String,
    pub button_label: String,
}

pub struct AppData {
    pub host_name: String,
    pub host_roles: Vec<String>,
    pub host_presets: Vec<String>,
    pub home_roles: Vec<String>,
    pub home_bundles: Vec<String>,
    pub system_tags: Vec<(String, bool)>,
    pub home_packages: Vec<(String, bool)>,
    pub module_flags: Vec<(String, String)>,
    pub available_roles: Vec<String>,
    pub role_info: Vec<RoleInfo>,
    pub preset_info: Vec<PresetInfo>,
    pub bundle_info: Vec<BundleInfo>,
    pub nav_items: Vec<NavItem>,
    pub page_info: Vec<PageInfo>,
    pub action_info: Vec<ActionInfo>,
    pub style_css: String,
    pub preview: PreviewData,
    pub rebuild_running: bool,
    pub rebuild_ok: bool,
    pub rebuild_log: String,
    pub framework_validation_ok: bool,
    pub framework_validation_errors: Vec<String>,
    pub dotfiles_root: PathBuf,
}

impl AppData {
    pub fn load(root: &Path) -> Self {
        let host_roles = read_roles(&root.join("data/hosts/omen/roles.nix"));
        let home_roles = read_roles(&root.join("data/home/lucy/roles.nix"));
        let system_tags = read_system_tags(&root.join("data/packages/system.nix"), root);
        let home_packages = read_home_packages(&root.join("data/packages/home.nix"), root);
        let module_flags = read_flags(&root.join("data/hosts/omen/module-flags.nix"));
        let available = list_roles(&root.join("data/roles"));
        let metadata = read_framework_metadata(root);
        let chrome = read_webui_chrome(root);
        let host_presets = read_string_list_file(&root.join("data/hosts/omen/presets.nix"));
        let home_bundles = read_string_list_file(&root.join("data/home/lucy/bundles.nix"));
        let preview = read_framework_preview(root);
        let (framework_validation_ok, framework_validation_errors) = read_framework_validation(root);
        Self {
            host_name: "omen".into(), host_roles, host_presets, home_roles, home_bundles, system_tags, home_packages,
            module_flags, available_roles: available, role_info: metadata.roles, preset_info: metadata.presets, bundle_info: metadata.bundles,
            nav_items: chrome.nav_items, page_info: chrome.page_info, action_info: chrome.action_info, style_css: chrome.style_css, preview,
            rebuild_running: false, rebuild_ok: true, rebuild_log: String::new(),
            framework_validation_ok, framework_validation_errors,
            dotfiles_root: root.to_path_buf(),
        }
    }

    pub fn save_host_roles(&mut self, roles: &[String]) {
        let path = self.dotfiles_root.join("data/hosts/omen/roles.nix");
        let _ = std::fs::write(&path, format_role_list(roles));
        self.host_roles = roles.to_vec();
        self.refresh_framework_validation();
    }
    pub fn save_home_roles(&mut self, roles: &[String]) {
        let path = self.dotfiles_root.join("data/home/lucy/roles.nix");
        let _ = std::fs::write(&path, format_role_list(roles));
        self.home_roles = roles.to_vec();
        self.refresh_framework_validation();
    }
    pub fn save_host_presets(&mut self, presets: &[String]) {
        let path = self.dotfiles_root.join("data/hosts/omen/presets.nix");
        let _ = std::fs::write(&path, format_role_list(presets));
        self.host_presets = presets.to_vec();
        self.refresh_framework_validation();
    }
    pub fn save_home_bundles(&mut self, bundles: &[String]) {
        let path = self.dotfiles_root.join("data/home/lucy/bundles.nix");
        let _ = std::fs::write(&path, format_role_list(bundles));
        self.home_bundles = bundles.to_vec();
        self.refresh_framework_validation();
    }
    pub fn save_system_tag(&mut self, tag: &str, enabled: bool) {
        let path = self.dotfiles_root.join("data/hosts/omen/services.nix");
        if let Ok(content) = std::fs::read_to_string(&path) {
            let mut lines: Vec<String> = content.lines().map(String::from).collect();
            let entry = format!("    \"{}\"", tag);
            let mut in_block = false;
            let mut found = false;
            for line in &lines {
                if line.contains("packageTags") { in_block = true; }
                if in_block && line.contains(&entry) {
                    if !enabled { lines.retain(|l| !l.contains(&entry)); }
                    found = true; break;
                }
                if in_block && line.contains(']') { break; }
            }
            if enabled && !found {
                for (i, line) in lines.iter().enumerate() {
                    if line.contains("packageTags") {
                        for j in (i..lines.len()).rev() {
                            if lines[j].contains(']') { lines.insert(j, entry); break; }
                        }
                        break;
                    }
                }
            }
            let _ = std::fs::write(&path, lines.join("\n"));
        }
        self.system_tags = read_system_tags(&self.dotfiles_root.join("data/packages/system.nix"), &self.dotfiles_root);
        self.refresh_framework_validation();
    }
    pub fn save_home_package(&mut self, name: &str, enabled: bool) {
        let dir = self.dotfiles_root.join("data/bundles");
        if let Ok(entries) = std::fs::read_dir(&dir) {
            for entry in entries.flatten() {
                if entry.path().extension().map_or(false, |e| e == "nix") {
                    toggle_in_bundle(&entry.path(), name, enabled);
                }
            }
        }
        self.home_packages = read_home_packages(&self.dotfiles_root.join("data/packages/home.nix"), &self.dotfiles_root);
        self.refresh_framework_validation();
    }
    pub fn save_flag(&mut self, path: &str, value: &str) {
        let file = self.dotfiles_root.join("data/hosts/omen/module-flags.nix");
        if let Ok(content) = std::fs::read_to_string(&file) {
            let mut lines: Vec<String> = content.lines().map(String::from).collect();
            let new_line = format!("  {} = {};", path, value);
            let mut found = false;
            for line in &mut lines {
                if line.trim().starts_with(path) { *line = new_line.clone(); found = true; }
            }
            if !found {
                if let Some(idx) = lines.iter().rposition(|l| l.trim() == "}") {
                    lines.insert(idx, new_line);
                }
            }
            let _ = std::fs::write(&file, lines.join("\n"));
        }
        self.module_flags = read_flags(&self.dotfiles_root.join("data/hosts/omen/module-flags.nix"));
        let metadata = read_framework_metadata(&self.dotfiles_root);
        self.role_info = metadata.roles;
        self.preset_info = metadata.presets;
        self.bundle_info = metadata.bundles;
        self.refresh_framework_validation();
    }
    pub fn reload(&mut self) {
        self.host_roles = read_roles(&self.dotfiles_root.join("data/hosts/omen/roles.nix"));
        self.home_roles = read_roles(&self.dotfiles_root.join("data/home/lucy/roles.nix"));
        self.system_tags = read_system_tags(&self.dotfiles_root.join("data/packages/system.nix"), &self.dotfiles_root);
        self.home_packages = read_home_packages(&self.dotfiles_root.join("data/packages/home.nix"), &self.dotfiles_root);
        self.module_flags = read_flags(&self.dotfiles_root.join("data/hosts/omen/module-flags.nix"));
        self.refresh_framework_validation();
    }
    pub fn rebuild_status_html(&self) -> String {
        if self.rebuild_running { "<span class=\"rb-running\">building…</span>".into() }
        else if self.rebuild_ok { "<span class=\"rb-ok\">success</span>".into() }
        else { "<span class=\"rb-fail\">failed</span>".into() }
    }
    pub fn framework_validation_status_html(&self) -> String {
        if self.framework_validation_ok {
            "<span class=\"rb-ok\">framework ok</span>".into()
        } else {
            format!("<span class=\"rb-fail\">{} issue(s)</span>", self.framework_validation_errors.len())
        }
    }
    pub fn refresh_framework_validation(&mut self) {
        self.preview = read_framework_preview(&self.dotfiles_root);
        let (ok, errors) = read_framework_validation(&self.dotfiles_root);
        self.framework_validation_ok = ok;
        self.framework_validation_errors = errors;
    }
    pub fn role_infos_for(&self, target: &str) -> Vec<&RoleInfo> {
        let mut roles: Vec<&RoleInfo> = self.role_info.iter()
            .filter(|role| role.targets.iter().any(|t| t == target))
            .collect();
        roles.sort_by(|a, b| a.name.cmp(&b.name));
        roles
    }
    pub fn role_info(&self, name: &str) -> Option<&RoleInfo> {
        self.role_info.iter().find(|role| role.name == name)
    }
    pub fn nav_sections(&self) -> Vec<String> {
        let mut sections = vec![];
        for item in &self.nav_items {
            if !sections.contains(&item.section) {
                sections.push(item.section.clone());
            }
        }
        sections
    }
    pub fn nav_items_for_section(&self, section: &str) -> Vec<&NavItem> {
        self.nav_items.iter().filter(|item| item.section == section).collect()
    }
    pub fn page_info_for(&self, name: &str) -> Option<&PageInfo> {
        self.page_info.iter().find(|page| page.name == name)
    }
    pub fn preset_names_for_host_roles(&self) -> Vec<String> {
        self.preview.host_presets.clone()
    }
    pub fn bundle_names_for_home_roles(&self) -> Vec<String> {
        self.preview.home_bundles.clone()
    }
}

struct FrameworkMetadata {
    roles: Vec<RoleInfo>,
    presets: Vec<PresetInfo>,
    bundles: Vec<BundleInfo>,
}

struct WebUiChrome {
    nav_items: Vec<NavItem>,
    page_info: Vec<PageInfo>,
    action_info: Vec<ActionInfo>,
    style_css: String,
}

fn read_framework_metadata(root: &Path) -> FrameworkMetadata {
    let expr = format!(r#"
let
  root = {root};
  dot = (builtins.getFlake (toString root)).lib;
in dot.framework.export.exportMetadata root
"#, root = root.display());
    match std::process::Command::new("nix").args(["eval", "--raw", "--impure", "--expr", &expr]).current_dir(root).output() {
        Ok(o) if o.status.success() => {
            parse_framework_metadata(&String::from_utf8_lossy(&o.stdout))
        }
        _ => FrameworkMetadata { roles: vec![], presets: vec![], bundles: vec![] },
    }
}

fn read_framework_preview(root: &Path) -> PreviewData {
    let expr = format!(r#"
let
  root = {root};
  dot = (builtins.getFlake (toString root)).lib;
in dot.framework.export.exportPreview root
"#, root = root.display());
    match std::process::Command::new("nix").args(["eval", "--raw", "--impure", "--expr", &expr]).current_dir(root).output() {
        Ok(o) if o.status.success() => parse_framework_preview(&String::from_utf8_lossy(&o.stdout)),
        _ => PreviewData { host_roles: vec![], host_presets: vec![], home_roles: vec![], home_bundles: vec![] },
    }
}

fn read_webui_chrome(root: &Path) -> WebUiChrome {
    let chrome_expr = format!(r#"
let
  root = {root};
  dot = (builtins.getFlake (toString root)).lib;
in dot.framework.webui.exportChrome root
"#, root = root.display());
    let style_expr = format!(r#"
let
  root = {root};
  dot = (builtins.getFlake (toString root)).lib;
in dot.framework.webui.exportStyle root
"#, root = root.display());

    let nav_and_pages = match std::process::Command::new("nix").args(["eval", "--raw", "--impure", "--expr", &chrome_expr]).current_dir(root).output() {
        Ok(o) if o.status.success() => parse_webui_chrome(&String::from_utf8_lossy(&o.stdout)),
        _ => (vec![], vec![], vec![]),
    };

    let style_css = match std::process::Command::new("nix").args(["eval", "--raw", "--impure", "--expr", &style_expr]).current_dir(root).output() {
        Ok(o) if o.status.success() => String::from_utf8_lossy(&o.stdout).to_string(),
        _ => String::new(),
    };

    WebUiChrome { nav_items: nav_and_pages.0, page_info: nav_and_pages.1, action_info: nav_and_pages.2, style_css }
}

fn parse_framework_metadata(input: &str) -> FrameworkMetadata {
    let mut roles = vec![];
    let mut presets = vec![];
    let mut bundles = vec![];
    for line in input.lines() {
        if let Some(rest) = line.strip_prefix("role\t") {
            let parts: Vec<&str> = rest.split('\t').collect();
            if parts.len() == 9 {
                roles.push(RoleInfo {
                    name: parts[0].to_string(),
                    description: parts[1].to_string(),
                    targets: parse_csv(parts[2]),
                    presets: parse_csv(parts[3]),
                    bundles: parse_csv(parts[4]),
                    requires_host: parse_csv(parts[5]),
                    requires_home: parse_csv(parts[6]),
                    conflicts_host: parse_csv(parts[7]),
                    conflicts_home: parse_csv(parts[8]),
                });
            }
        } else if let Some(rest) = line.strip_prefix("preset\t") {
            let parts: Vec<&str> = rest.split('\t').collect();
            if parts.len() == 3 {
                presets.push(PresetInfo {
                    name: parts[0].to_string(),
                    description: parts[1].to_string(),
                    targets: parse_csv(parts[2]),
                });
            }
        } else if let Some(rest) = line.strip_prefix("bundle\t") {
            let parts: Vec<&str> = rest.split('\t').collect();
            if parts.len() == 3 {
                bundles.push(BundleInfo {
                    name: parts[0].to_string(),
                    description: parts[1].to_string(),
                    targets: parse_csv(parts[2]),
                });
            }
        }
    }
    FrameworkMetadata { roles, presets, bundles }
}

fn parse_framework_preview(input: &str) -> PreviewData {
    let mut preview = PreviewData { host_roles: vec![], host_presets: vec![], home_roles: vec![], home_bundles: vec![] };
    for line in input.lines() {
        if let Some(rest) = line.strip_prefix("preview-host-roles\t") {
            preview.host_roles = parse_csv(rest);
        } else if let Some(rest) = line.strip_prefix("preview-host-presets\t") {
            preview.host_presets = parse_csv(rest);
        } else if let Some(rest) = line.strip_prefix("preview-home-roles\t") {
            preview.home_roles = parse_csv(rest);
        } else if let Some(rest) = line.strip_prefix("preview-home-bundles\t") {
            preview.home_bundles = parse_csv(rest);
        }
    }
    preview
}

fn parse_webui_chrome(input: &str) -> (Vec<NavItem>, Vec<PageInfo>, Vec<ActionInfo>) {
    let mut nav_items = vec![];
    let mut page_info = vec![];
    let mut action_info = vec![];
    for line in input.lines() {
        if let Some(rest) = line.strip_prefix("nav\t") {
            let parts: Vec<&str> = rest.split('\t').collect();
            if parts.len() == 5 {
                nav_items.push(NavItem {
                    section: parts[0].to_string(),
                    page: parts[1].to_string(),
                    expert: parts[2] == "true",
                    icon: parts[3].to_string(),
                    label: parts[4].to_string(),
                });
            }
        } else if let Some(rest) = line.strip_prefix("page\t") {
            let parts: Vec<&str> = rest.split('\t').collect();
            if parts.len() == 3 {
                page_info.push(PageInfo {
                    name: parts[0].to_string(),
                    title: parts[1].to_string(),
                    description: parts[2].to_string(),
                });
            }
        } else if let Some(rest) = line.strip_prefix("action\t") {
            let parts: Vec<&str> = rest.split('\t').collect();
            if parts.len() == 7 {
                action_info.push(ActionInfo {
                    title: parts[0].to_string(),
                    tag: parts[1].to_string(),
                    description: parts[2].to_string(),
                    endpoint: parts[3].to_string(),
                    target: parts[4].to_string(),
                    button_class: parts[5].to_string(),
                    button_label: parts[6].to_string(),
                });
            }
        }
    }
    (nav_items, page_info, action_info)
}

fn parse_csv(input: &str) -> Vec<String> {
    if input.trim().is_empty() { return vec![]; }
    input.split(',').map(|s| s.trim().to_string()).filter(|s| !s.is_empty()).collect()
}

fn read_framework_validation(root: &Path) -> (bool, Vec<String>) {
    let output = std::process::Command::new("nix")
        .args(["build", ".#checks.x86_64-linux.framework-validation", "--no-link"])
        .current_dir(root)
        .output();
    match output {
        Ok(o) if o.status.success() => (true, vec![]),
        Ok(o) => {
            let stderr = String::from_utf8_lossy(&o.stderr);
            let mut errors = vec![];
            let mut capture = false;
            for line in stderr.lines() {
                let trimmed = line.trim();
                if trimmed.contains("validation failed:") {
                    capture = true;
                    continue;
                }
                if capture && !trimmed.is_empty() {
                    let msg = trimmed.trim_start_matches('>').trim().trim_start_matches('-').trim();
                    if !msg.is_empty() {
                        errors.push(msg.to_string());
                    }
                }
            }
            if errors.is_empty() {
                errors.push(stderr.lines().last().unwrap_or("framework validation failed").trim().to_string());
            }
            (false, errors)
        }
        Err(e) => (false, vec![e.to_string()]),
    }
}

fn read_string_list_file(path: &Path) -> Vec<String> {
    if !path.exists() { return vec![]; }
    parse_string_list(&std::fs::read_to_string(path).unwrap_or_default())
}

fn read_roles(path: &Path) -> Vec<String> {
    if !path.exists() { return vec![]; }
    parse_string_list(&std::fs::read_to_string(path).unwrap_or_default())
}
fn parse_string_list(content: &str) -> Vec<String> {
    let mut result = vec![];
    let mut in_list = false;
    for line in content.lines() {
        let t = line.trim();
        if t.contains('[') { in_list = true; }
        if in_list {
            for part in t.split_whitespace() {
                let clean = part.trim_matches(|c| c == '"' || c == ']' || c == '[');
                if !clean.is_empty() && clean != "]" { result.push(clean.into()); }
            }
        }
        if t.contains(']') { in_list = false; }
    }
    result
}
fn read_system_tags(registry: &Path, root: &Path) -> Vec<(String, bool)> {
    if !registry.exists() { return vec![]; }
    let content = std::fs::read_to_string(registry).unwrap_or_default();
    let all = extract_tags(&content);
    let active = collect_active_tags(root);
    all.into_iter().map(|t| (t.clone(), active.contains(&t))).collect()
}
fn extract_tags(content: &str) -> Vec<String> {
    let mut tags = HashSet::new();
    for line in content.lines() {
        let t = line.trim();
        if t.contains("tags") && t.contains('[') {
            let inner: String = t.chars().skip_while(|c| *c != '[').skip(1).take_while(|c| *c != ']').collect();
            for tag in parse_nix_list_items(&inner) {
                if !tag.is_empty() { tags.insert(tag.to_string()); }
            }
        }
    }
    let mut sorted: Vec<_> = tags.into_iter().collect();
    sorted.sort();
    sorted
}
fn collect_active_tags(host_dir: &Path) -> HashSet<String> {
    let mut active = HashSet::new();
    if let Ok(entries) = std::fs::read_dir(host_dir) {
        for entry in entries.flatten() {
            if entry.path().extension().map_or(false, |e| e == "nix") {
                if let Ok(content) = std::fs::read_to_string(entry.path()) {
                    for line in content.lines() {
                        let t = line.trim();
                        if t.starts_with("packageTags") && t.contains('[') {
                            let inner: String = t.chars().skip_while(|c| *c != '[').skip(1).take_while(|c| *c != ']').collect();
                            for tag in parse_nix_list_items(&inner) {
                                if !tag.is_empty() { active.insert(tag.to_string()); }
                            }
                        }
                    }
                }
            }
        }
    }
    active
}
fn read_home_packages(registry: &Path, root: &Path) -> Vec<(String, bool)> {
    if !registry.exists() { return vec![]; }
    let content = std::fs::read_to_string(registry).unwrap_or_default();
    let names = extract_names(&content);
    let toggled = collect_toggles(root);
    names.into_iter().map(|n| (n.clone(), toggled.contains(&n))).collect()
}
fn extract_names(content: &str) -> Vec<String> {
    let mut result = vec![];
    let mut current: Option<String> = None;
    for line in content.lines() {
        let t = line.trim();
        if t.ends_with('=') && !t.contains('{') && !t.starts_with('#') && !t.starts_with("let") && !t.starts_with("in") && !t.starts_with("with") {
            current = Some(t.trim_end_matches('=').to_string());
        }
        if let Some(ref name) = current {
            if t.starts_with("name") || t.starts_with("description") { result.push(name.clone()); current = None; }
        }
    }
    result
}
fn collect_toggles(root: &Path) -> HashSet<String> {
    let mut toggled = HashSet::new();
    let dir = root.join("data/bundles");
    if let Ok(entries) = std::fs::read_dir(&dir) {
        for entry in entries.flatten() {
            if entry.path().extension().map_or(false, |e| e == "nix") {
                if let Ok(content) = std::fs::read_to_string(entry.path()) { toggled.extend(parse_toggles(&content)); }
            }
        }
    }
    toggled
}
fn parse_toggles(content: &str) -> Vec<String> {
    let mut result = vec![];
    for line in content.lines() {
        let t = line.trim();
        if t.starts_with("packageToggles") && t.contains('[') {
            let inner: String = t.chars().skip_while(|c| *c != '[').skip(1).take_while(|c| *c != ']').collect();
            for pkg in parse_nix_list_items(&inner) {
                if !pkg.is_empty() { result.push(pkg.to_string()); }
            }
        }
    }
    result
}

fn parse_nix_list_items(inner: &str) -> Vec<&str> {
    inner
        .split(|c: char| c == ',' || c.is_whitespace())
        .map(|s| s.trim().trim_matches('"'))
        .filter(|s| !s.is_empty())
        .collect()
}
fn toggle_in_bundle(path: &Path, name: &str, enabled: bool) {
    if let Ok(content) = std::fs::read_to_string(path) {
        let toggles = parse_toggles(&content);
        let has = toggles.iter().any(|t| t == name);
        if enabled && !has {
            let mut lines: Vec<String> = content.lines().map(String::from).collect();
            for (i, line) in lines.iter().enumerate() {
                if line.contains("packageToggles") {
                    for j in (i..lines.len()).rev() { if lines[j].contains(']') { lines.insert(j, format!("      \"{}\"", name)); break; } }
                    break;
                }
            }
            let _ = std::fs::write(path, format!("{}\n", lines.join("\n")));
        } else if !enabled && has {
            let mut lines: Vec<String> = content.lines().map(String::from).collect();
            lines.retain(|l| !l.contains(&format!("\"{}\"", name)));
            let _ = std::fs::write(path, format!("{}\n", lines.join("\n")));
        }
    }
}
fn read_flags(path: &Path) -> Vec<(String, String)> {
    if !path.exists() { return vec![]; }
    let content = std::fs::read_to_string(path).unwrap_or_default();
    let mut flags = vec![];
    for line in content.lines() {
        let t = line.trim();
        if t.starts_with("//") || t.is_empty() { continue; }
        if let Some(eq) = t.find('=') {
            let key = t[..eq].trim();
            let val = t[eq + 1..].trim().trim_end_matches(';');
            if key.starts_with("lucy.") || key.starts_with("programs.") { flags.push((key.into(), val.into())); }
        }
    }
    flags
}
fn list_roles(dir: &Path) -> Vec<String> {
    if !dir.exists() { return vec![]; }
    let mut roles = vec![];
    if let Ok(entries) = std::fs::read_dir(dir) {
        for entry in entries.flatten() {
            if let Some(name) = entry.file_name().to_str() {
                if name.ends_with(".nix") { roles.push(name.trim_end_matches(".nix").to_string()); }
            }
        }
    }
    roles.sort(); roles
}
fn format_role_list(roles: &[String]) -> String {
    if roles.is_empty() { return "[]\n".into(); }
    let items = roles.iter().map(|r| format!("  \"{}\"", r)).collect::<Vec<_>>().join("\n");
    format!("[\n{}\n]\n", items)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_string_list_simple() {
        let input = "[\n  \"desktop\"\n  \"gaming\"\n]";
        let result = parse_string_list(input);
        assert_eq!(result, vec!["desktop", "gaming"]);
    }

    #[test]
    fn parse_string_list_inline() {
        let input = "[ \"core\" \"dev\" ]";
        let result = parse_string_list(input);
        assert_eq!(result, vec!["core", "dev"]);
    }

    #[test]
    fn parse_string_list_empty() {
        let result = parse_string_list("[]");
        assert!(result.is_empty());
    }

    #[test]
    fn parse_string_list_empty_file() {
        let result = parse_string_list("");
        assert!(result.is_empty());
    }

    #[test]
    fn format_role_list_nonempty() {
        let roles = vec!["desktop".into(), "gaming".into()];
        let out = format_role_list(&roles);
        assert_eq!(out, "[\n  \"desktop\"\n  \"gaming\"\n]\n");
    }

    #[test]
    fn format_role_list_empty() {
        assert_eq!(format_role_list(&[]), "[]\n");
    }

    #[test]
    fn format_roundtrip() {
        let original = vec!["core".into(), "dev".into(), "desktop".into()];
        let formatted = format_role_list(&original);
        let parsed = parse_string_list(&formatted);
        assert_eq!(parsed, original);
    }

    #[test]
    fn extract_tags_from_nix() {
        let input = r#"
{
  packages = [
    { name = "firefox"; tags = ["browser" "desktop"]; }
    { name = "discord"; tags = ["chat" "desktop"]; }
  ];
}"#;
        let tags = extract_tags(input);
        assert!(tags.contains(&"browser".to_string()));
        assert!(tags.contains(&"desktop".to_string()));
        assert!(tags.contains(&"chat".to_string()));
    }

    #[test]
    fn extract_tags_sorted() {
        let input = r#"{ foo.tags = ["zeta" "alpha" "mida"]; }"#;
        let tags = extract_tags(input);
        assert_eq!(tags, vec!["alpha", "mida", "zeta"]);
    }

    #[test]
    fn extract_tags_empty() {
        let result = extract_tags("");
        assert!(result.is_empty());
    }

    #[test]
    fn parse_toggles_single_line() {
        let input = r#"    packageToggles = [ "firefox" "discord" ];"#;
        let toggles = parse_toggles(input);
        assert_eq!(toggles, vec!["firefox", "discord"]);
    }

    #[test]
    fn parse_toggles_empty() {
        let input = "    packageToggles = [ ];";
        let result = parse_toggles(input);
        // produces empty string from split, filtered out
        assert!(result.is_empty());
    }

    #[test]
    fn parse_toggles_no_match() {
        let input = "somethingElse = [ \"foo\" ];";
        let result = parse_toggles(input);
        assert!(result.is_empty());
    }

    #[test]
    fn parse_framework_metadata_role_preset_bundle_lines() {
        let input = "role\tdesktop\tDesktop env\thost,home\tgaming-base\tdesktop-bundle\tdev\tcore\tnone\t\npreset\tgaming-base\tGaming base\thost\nbundle\tcore\tCore bundle\thome\n";
        let meta = parse_framework_metadata(input);
        assert_eq!(meta.roles.len(), 1);
        assert_eq!(meta.roles[0].name, "desktop");
        assert_eq!(meta.roles[0].targets, vec!["host", "home"]);
        assert_eq!(meta.roles[0].presets, vec!["gaming-base"]);
        assert_eq!(meta.roles[0].bundles, vec!["desktop-bundle"]);
        assert_eq!(meta.roles[0].requires_host, vec!["dev"]);
        assert_eq!(meta.roles[0].requires_home, vec!["core"]);
        assert_eq!(meta.roles[0].conflicts_host, vec!["none"]);
        assert_eq!(meta.roles[0].conflicts_home, Vec::<String>::new());
        assert_eq!(meta.presets.len(), 1);
        assert_eq!(meta.presets[0].name, "gaming-base");
        assert_eq!(meta.bundles.len(), 1);
        assert_eq!(meta.bundles[0].name, "core");
    }

    #[test]
    fn parse_framework_preview_lines() {
        let input = "preview-host-roles\tdesktop,gaming\npreview-host-presets\tgaming-base,gaming-steam\npreview-home-roles\tcore,dev\npreview-home-bundles\tcore,dev\n";
        let preview = parse_framework_preview(input);
        assert_eq!(preview.host_roles, vec!["desktop", "gaming"]);
        assert_eq!(preview.host_presets, vec!["gaming-base", "gaming-steam"]);
        assert_eq!(preview.home_roles, vec!["core", "dev"]);
        assert_eq!(preview.home_bundles, vec!["core", "dev"]);
    }

    #[test]
    fn parse_webui_chrome_lines() {
        let input = "nav\tSystem\toverview\tfalse\t◉\tOverview\npage\toverview\tOverview\tSystem state\naction\trebuild\tnh os switch\tEvaluate\t/rebuild\t#rebuild-output\tbtn btn-accent\t▶ Rebuild\n";
        let (nav, pages, actions) = parse_webui_chrome(input);
        assert_eq!(nav.len(), 1);
        assert_eq!(nav[0].section, "System");
        assert_eq!(nav[0].page, "overview");
        assert!(!nav[0].expert);
        assert_eq!(nav[0].label, "Overview");
        assert_eq!(pages.len(), 1);
        assert_eq!(pages[0].name, "overview");
        assert_eq!(pages[0].title, "Overview");
        assert_eq!(pages[0].description, "System state");
        assert_eq!(actions.len(), 1);
        assert_eq!(actions[0].endpoint, "/rebuild");
        assert_eq!(actions[0].button_label, "▶ Rebuild");
    }

    #[test]
    fn read_flags_basic() {
        let tmp = std::env::temp_dir().join("test_flags.nix");
        let content = r#"{
  lucy.secrets.enable = true;
  programs.gaming.enable = false;
  // comment = true;
  lucy.desktop.enable = true;
}"#;
        std::fs::write(&tmp, content).unwrap();
        let flags = read_flags(&tmp);
        let map: std::collections::HashMap<_, _> = flags.into_iter().collect();
        assert_eq!(map.get("lucy.secrets.enable"), Some(&"true".to_string()));
        assert_eq!(map.get("programs.gaming.enable"), Some(&"false".to_string()));
        assert_eq!(map.get("lucy.desktop.enable"), Some(&"true".to_string()));
        assert_eq!(map.len(), 3);
        let _ = std::fs::remove_file(&tmp);
    }

    #[test]
    fn read_flags_missing_file() {
        let flags = read_flags(Path::new("/nonexistent/path/file.nix"));
        assert!(flags.is_empty());
    }

    #[test]
    fn read_flags_skips_comments() {
        let tmp = std::env::temp_dir().join("test_comments.nix");
        std::fs::write(&tmp, "// comment = true;\n").unwrap();
        let flags = read_flags(&tmp);
        assert!(flags.is_empty());
        let _ = std::fs::remove_file(&tmp);
    }
}
