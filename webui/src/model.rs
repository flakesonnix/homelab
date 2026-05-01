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
