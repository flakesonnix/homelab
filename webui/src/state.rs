use std::collections::HashSet;
use std::path::{Path, PathBuf};

pub struct RoleInfo {
    pub name: String,
    pub description: String,
    pub targets: Vec<String>,
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

pub struct AppData {
    pub host_name: String,
    pub host_roles: Vec<String>,
    pub home_roles: Vec<String>,
    pub system_tags: Vec<(String, bool)>,
    pub home_packages: Vec<(String, bool)>,
    pub module_flags: Vec<(String, String)>,
    pub available_roles: Vec<String>,
    pub role_info: Vec<RoleInfo>,
    pub preset_info: Vec<PresetInfo>,
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
        let role_info = read_role_info(root);
        let preset_info = read_preset_info(root);
        let (framework_validation_ok, framework_validation_errors) = read_framework_validation(root);
        Self {
            host_name: "omen".into(), host_roles, home_roles, system_tags, home_packages,
            module_flags, available_roles: available, role_info, preset_info,
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
        self.role_info = read_role_info(&self.dotfiles_root);
        self.preset_info = read_preset_info(&self.dotfiles_root);
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
}

fn read_role_info(root: &Path) -> Vec<RoleInfo> {
    let expr = format!(r#"
let
  root = {root};
  roleDir = root + "/data/roles";
  roleNames = map (name: builtins.replaceStrings [".nix"] [""] name)
    (builtins.filter (name: builtins.match ".*\\.nix" name != null) (builtins.attrNames (builtins.readDir roleDir)));
  field = meta: attr: target:
    let value = meta.${{attr}} or [];
    in if builtins.isList value then value else if builtins.isAttrs value then value.${{target}} or [] else [];
  join = xs: builtins.concatStringsSep "," xs;
  render = name:
    let
      role = import (roleDir + "/${{name}}.nix");
      meta = role.meta or {{}};
    in builtins.concatStringsSep "\t" [
      name
      (meta.description or "")
      (join (meta.targets or []))
      (join (field meta "requires" "host"))
      (join (field meta "requires" "home"))
      (join (field meta "conflicts" "host"))
      (join (field meta "conflicts" "home"))
    ];
in builtins.concatStringsSep "\n" (map render roleNames)
"#, root = root.display());
    match std::process::Command::new("nix").args(["eval", "--raw", "--impure", "--expr", &expr]).current_dir(root).output() {
        Ok(o) if o.status.success() => {
            String::from_utf8_lossy(&o.stdout)
                .lines()
                .filter(|line| !line.trim().is_empty())
                .filter_map(|line| {
                    let parts: Vec<&str> = line.split('\t').collect();
                    if parts.len() != 7 { return None; }
                    Some(RoleInfo {
                        name: parts[0].to_string(),
                        description: parts[1].to_string(),
                        targets: parse_csv(parts[2]),
                        requires_host: parse_csv(parts[3]),
                        requires_home: parse_csv(parts[4]),
                        conflicts_host: parse_csv(parts[5]),
                        conflicts_home: parse_csv(parts[6]),
                    })
                })
                .collect()
        }
        _ => vec![],
    }
}

fn read_preset_info(root: &Path) -> Vec<PresetInfo> {
    let expr = format!(r#"
let
  root = {root};
  presetDir = root + "/data/presets";
  presetNames = map (name: builtins.replaceStrings [".nix"] [""] name)
    (builtins.filter (name: builtins.match ".*\\.nix" name != null) (builtins.attrNames (builtins.readDir presetDir)));
  join = xs: builtins.concatStringsSep "," xs;
  render = name:
    let
      preset = import (presetDir + "/${{name}}.nix");
      meta = preset.meta or {{}};
    in builtins.concatStringsSep "\t" [
      name
      (meta.description or "")
      (join (meta.targets or []))
    ];
in builtins.concatStringsSep "\n" (map render presetNames)
"#, root = root.display());
    match std::process::Command::new("nix").args(["eval", "--raw", "--impure", "--expr", &expr]).current_dir(root).output() {
        Ok(o) if o.status.success() => {
            String::from_utf8_lossy(&o.stdout)
                .lines()
                .filter(|line| !line.trim().is_empty())
                .filter_map(|line| {
                    let parts: Vec<&str> = line.split('\t').collect();
                    if parts.len() != 3 { return None; }
                    Some(PresetInfo {
                        name: parts[0].to_string(),
                        description: parts[1].to_string(),
                        targets: parse_csv(parts[2]),
                    })
                })
                .collect()
        }
        _ => vec![],
    }
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
