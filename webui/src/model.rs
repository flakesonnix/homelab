pub struct RoleDef { pub name: String, pub desc: String }
impl RoleDef { pub fn new(n: &str, d: &str) -> Self { Self { name: n.into(), desc: d.into() } } }

pub fn known_roles() -> Vec<RoleDef> {
    vec![
        RoleDef::new("desktop", "Compositor, terminal, browser, chat"),
        RoleDef::new("dev", "Compilers, IDEs, monitoring"),
        RoleDef::new("gaming", "Steam, GameMode, Gamescope"),
        RoleDef::new("llm", "LM Studio, Ollama"),
        RoleDef::new("core", "Shell, git, nvim, essentials"),
    ]
}

pub fn role_desc(name: &str) -> &'static str {
    match name {
        "desktop" => "Compositor, terminal, browser, chat",
        "dev" => "Compilers, IDEs, monitoring",
        "gaming" => "Steam, GameMode, Gamescope",
        "llm" => "LM Studio, Ollama",
        "core" => "Shell, git, nvim, essentials",
        _ => "",
    }
}

pub fn tag_desc(tag: &str) -> &'static str {
    match tag {
        "desktop" => "Firefox, Discord, LM Studio",
        "browser" => "Firefox",
        "chat" => "Discord",
        "llm" => "LM Studio, Ollama",
        "gpu" => "Ollama (CUDA)",
        "wayland" => "swaybg",
        "dev" => "GCC, GDB, CMake, Ninja",
        "jetbrains" => "CLion",
        "cli" => "nload, iotop, iftop",
        "network" => "nload, iftop",
        "monitoring" => "iotop, iftop",
        "audio" => "pwvucontrol",
        "android" => "scrcpy",
        _ => "",
    }
}

pub fn home_pkg_desc(name: &str) -> &'static str {
    match name {
        "jetbrains-mono" => "Monospace font",
        "nautilus" => "GNOME file manager",
        "comma" => "Run nixpkgs packages ad-hoc",
        "manix" => "NixOS doc search",
        "nix-output-monitor" => "Pretty build output",
        "android-studio" => "Android IDE",
        _ => "",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn known_roles_count() {
        let roles = known_roles();
        assert_eq!(roles.len(), 5);
    }

    #[test]
    fn known_roles_have_descriptions() {
        for role in known_roles() {
            assert!(!role.desc.is_empty(), "role '{}' has empty desc", role.name);
        }
    }

    #[test]
    fn role_desc_known() {
        assert_eq!(role_desc("desktop"), "Compositor, terminal, browser, chat");
        assert_eq!(role_desc("gaming"), "Steam, GameMode, Gamescope");
        assert_eq!(role_desc("llm"), "LM Studio, Ollama");
    }

    #[test]
    fn role_desc_unknown() {
        assert_eq!(role_desc("nonexistent"), "");
    }

    #[test]
    fn tag_desc_all_known_tags() {
        assert!(!tag_desc("desktop").is_empty());
        assert!(!tag_desc("browser").is_empty());
        assert!(!tag_desc("chat").is_empty());
        assert!(!tag_desc("llm").is_empty());
        assert!(!tag_desc("gpu").is_empty());
        assert!(!tag_desc("wayland").is_empty());
        assert!(!tag_desc("dev").is_empty());
        assert!(!tag_desc("jetbrains").is_empty());
        assert!(!tag_desc("cli").is_empty());
        assert!(!tag_desc("network").is_empty());
        assert!(!tag_desc("monitoring").is_empty());
        assert!(!tag_desc("audio").is_empty());
        assert!(!tag_desc("android").is_empty());
    }

    #[test]
    fn tag_desc_unknown() {
        assert_eq!(tag_desc("fake-tag"), "");
    }

    #[test]
    fn home_pkg_desc_all_known() {
        assert!(!home_pkg_desc("jetbrains-mono").is_empty());
        assert!(!home_pkg_desc("nautilus").is_empty());
        assert!(!home_pkg_desc("comma").is_empty());
        assert!(!home_pkg_desc("manix").is_empty());
        assert!(!home_pkg_desc("nix-output-monitor").is_empty());
        assert!(!home_pkg_desc("android-studio").is_empty());
    }

    #[test]
    fn home_pkg_desc_unknown() {
        assert_eq!(home_pkg_desc("unknown-pkg"), "");
    }
}
