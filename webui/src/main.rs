mod http;
mod model;
mod state;
mod views;

use http::{Request, Response, Method};
use state::ServerState;
use std::io::{BufRead, BufReader, Write};
use std::net::TcpListener;
use std::sync::{Arc, Mutex};
use std::thread;

fn main() {
    let root = std::env::current_dir().expect("cwd");
    let state = Arc::new(Mutex::new(ServerState::load(&root)));
    let listener = TcpListener::bind("127.0.0.1:8080").expect("bind");
    eprintln!("nixfiles webui -> http://127.0.0.1:8080");
    for stream in listener.incoming() {
        let stream = match stream { Ok(s) => s, Err(_) => continue };
        let state = Arc::clone(&state);
        thread::spawn(move || handle(state, stream));
    }
}

fn handle(state: Arc<Mutex<ServerState>>, stream: std::net::TcpStream) {
    let mut reader = BufReader::new(stream.try_clone().expect("clone"));
    let mut writer = stream;
    let req = match Request::parse(&mut reader) { Ok(r) => r, Err(_) => return };
    let resp = route(state, &req);
    let _ = resp.write(&mut writer);
}

fn route(state: Arc<Mutex<ServerState>>, req: &Request) -> Response {
    match (req.method(), req.path()) {
        (Method::Get, "/") | (Method::Get, "/index.html") => {
            let s = state.lock().unwrap();
            Response::html(views::html::page(&s.data))
        }
        (Method::Post, "/roles/host") => {
            if let Some(roles) = req.form_value("roles") {
                let list: Vec<String> = roles.split(',').map(|s| s.trim().to_string()).filter(|s| !s.is_empty()).collect();
                state.lock().unwrap().data.save_host_roles(&list);
            }
            Response::html(views::html::render_roles_section(&state.lock().unwrap().data, "host"))
        }
        (Method::Post, "/roles/home") => {
            if let Some(roles) = req.form_value("roles") {
                let list: Vec<String> = roles.split(',').map(|s| s.trim().to_string()).filter(|s| !s.is_empty()).collect();
                state.lock().unwrap().data.save_home_roles(&list);
            }
            Response::html(views::html::render_roles_section(&state.lock().unwrap().data, "home"))
        }
        (Method::Post, "/presets/host") => {
            if let Some(presets) = req.form_value("presets") {
                let list: Vec<String> = presets.split(',').map(|s| s.trim().to_string()).filter(|s| !s.is_empty()).collect();
                state.lock().unwrap().data.save_host_presets(&list);
            }
            Response::html(views::html::render_host_presets_section(&state.lock().unwrap().data))
        }
        (Method::Post, "/bundles/home") => {
            if let Some(bundles) = req.form_value("bundles") {
                let list: Vec<String> = bundles.split(',').map(|s| s.trim().to_string()).filter(|s| !s.is_empty()).collect();
                state.lock().unwrap().data.save_home_bundles(&list);
            }
            Response::html(views::html::render_bundle_section(&state.lock().unwrap().data))
        }
        (Method::Post, "/tags/system") => {
            let tag = req.form_value("tag").unwrap_or_default();
            let enabled = req.form_value("enabled") == Some("true".into());
            { let mut s = state.lock().unwrap(); s.data.save_system_tag(&tag, enabled); }
            Response::html(views::html::render_packages_section(&state.lock().unwrap().data))
        }
        (Method::Post, "/packages/home") => {
            let name = req.form_value("name").unwrap_or_default();
            let enabled = req.form_value("enabled") == Some("true".into());
            { let mut s = state.lock().unwrap(); s.data.save_home_package(&name, enabled); }
            Response::html(views::html::render_packages_section(&state.lock().unwrap().data))
        }
        (Method::Post, "/flags") => {
            let path = req.form_value("path").unwrap_or_default();
            let value = req.form_value("value").unwrap_or_default();
            { let mut s = state.lock().unwrap(); s.data.save_flag(&path, &value); }
            Response::html(views::html::render_flags_section(&state.lock().unwrap().data))
        }
        (Method::Post, "/rebuild") => {
            let root = { let s = state.lock().unwrap(); s.data.dotfiles_root.clone() };
            let s2 = Arc::clone(&state);
            thread::spawn(move || {
                { let mut s = s2.lock().unwrap(); s.data.rebuild_running = true; }
                let out = std::process::Command::new("nh").args(["os", "switch"]).current_dir(&root).output();
                let mut s = s2.lock().unwrap();
                s.data.rebuild_running = false;
                s.data.rebuild_ok = out.as_ref().map(|o| o.status.success()).unwrap_or(false);
                s.data.rebuild_log = out.map(|o| String::from_utf8_lossy(&o.stderr).to_string()).unwrap_or_default();
            });
            Response::html("<span class=\"rb-running\">building…</span>")
        }
        (Method::Post, "/validate") => {
            let root = { let s = state.lock().unwrap(); s.data.dotfiles_root.clone() };
            match std::process::Command::new("nix").args(["flake", "check"]).current_dir(&root).output() {
                Ok(o) if o.status.success() => Response::html("<span class=\"rb-ok\">passed</span>"),
                Ok(o) => Response::html(format!("<pre>{}</pre>", esc(&String::from_utf8_lossy(&o.stderr)))),
                Err(e) => Response::html(format!("<span class=\"rb-fail\">{}</span>", esc(&e.to_string()))),
            }
        }
        (Method::Post, "/validate/framework") => {
            let mut s = state.lock().unwrap();
            s.data.refresh_framework_validation();
            Response::html(views::html::render_framework_validation_section(&s.data))
        }
        (Method::Get, "/rebuild/status") => {
            let s = state.lock().unwrap();
            Response::html(s.data.rebuild_status_html())
        }
        (Method::Get, "/style.css") => Response::css(views::style::CSS),
        _ => Response::not_found(),
    }
}

fn esc(s: &str) -> String {
    s.replace('&', "&amp;").replace('<', "&lt;").replace('>', "&gt;").replace('"', "&quot;")
}
