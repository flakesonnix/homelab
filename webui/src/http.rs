use std::io::BufRead;
use std::collections::HashMap;

#[derive(Debug, Clone, PartialEq)]
pub enum Method { Get, Post }

#[derive(Debug, Clone)]
pub struct Request {
    method: Method,
    path: String,
    query: HashMap<String, String>,
    form: HashMap<String, String>,
}

impl Request {
    pub fn parse<R: BufRead>(reader: &mut R) -> Result<Self, String> {
        let mut line = String::new();
        reader.read_line(&mut line).map_err(|e| e.to_string())?;
        let parts: Vec<&str> = line.trim().split_whitespace().collect();
        if parts.len() < 2 { return Err("bad request".into()); }

        let method = match parts[0] {
            "GET" => Method::Get,
            "POST" => Method::Post,
            other => return Err(format!("unsupported: {}", other)),
        };
        let (path, query) = split_path_and_query(parts[1]);

        loop {
            line.clear();
            reader.read_line(&mut line).map_err(|e| e.to_string())?;
            if line.trim().is_empty() { break; }
        }

        let mut form = HashMap::new();
        if method == Method::Post {
            let mut body = String::new();
            reader.read_to_string(&mut body).map_err(|e| e.to_string())?;
            for pair in body.split('&') {
                if let Some((k, v)) = pair.split_once('=') {
                    form.insert(url_decode(k), url_decode(v));
                }
            }
        }
        Ok(Self { method, path, query, form })
    }

    pub fn method(&self) -> &Method { &self.method }
    pub fn path(&self) -> &str { &self.path }
    pub fn form_value(&self, key: &str) -> Option<String> { self.form.get(key).cloned() }
    pub fn query_value(&self, key: &str) -> Option<String> { self.query.get(key).cloned() }
}

fn split_path_and_query(raw: &str) -> (String, HashMap<String, String>) {
    let mut query = HashMap::new();
    let (path, qs) = match raw.split_once('?') {
        Some((p, q)) => (p, Some(q)),
        None => (raw, None),
    };

    if let Some(qs) = qs {
        for pair in qs.split('&') {
            if pair.is_empty() { continue; }
            if let Some((k, v)) = pair.split_once('=') {
                query.insert(url_decode(k), url_decode(v));
            } else {
                query.insert(url_decode(pair), String::new());
            }
        }
    }

    (path.to_string(), query)
}

fn url_decode(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut chars = s.bytes();
    while let Some(b) = chars.next() {
        if b == b'%' {
            let h = chars.next().unwrap_or(0);
            let l = chars.next().unwrap_or(0);
            if let Ok(val) = u8::from_str_radix(&format!("{}{}", h as char, l as char), 16) {
                out.push(val as char);
            }
        } else if b == b'+' { out.push(' '); }
        else { out.push(b as char); }
    }
    out
}

pub struct Response {
    status: u16,
    content_type: String,
    body: String,
}

impl Response {
    pub fn html(body: impl Into<String>) -> Self {
        Self { status: 200, content_type: "text/html; charset=utf-8".into(), body: body.into() }
    }
    pub fn css(body: impl Into<String>) -> Self {
        Self { status: 200, content_type: "text/css; charset=utf-8".into(), body: body.into() }
    }
    pub fn not_found() -> Self {
        Self { status: 404, content_type: "text/plain".into(), body: "not found".into() }
    }
    pub fn write<W: std::io::Write>(self, w: &mut W) -> std::io::Result<()> {
        let st = match self.status { 200 => "OK", 404 => "Not Found", _ => "Error" };
        write!(w, "HTTP/1.1 {} {}\r\nContent-Type: {}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}", self.status, st, self.content_type, self.body.len(), self.body)?;
        w.flush()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_get(path: &str) -> Request {
        let raw = format!("GET {} HTTP/1.1\r\nHost: localhost\r\n\r\n", path);
        Request::parse(&mut raw.as_bytes()).unwrap()
    }

    fn make_post(path: &str, body: &str) -> Request {
        let raw = format!("POST {} HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: {}\r\n\r\n{}", path, body.len(), body);
        Request::parse(&mut raw.as_bytes()).unwrap()
    }

    #[test]
    fn parse_get_root() {
        let req = make_get("/");
        assert_eq!(req.method(), &Method::Get);
        assert_eq!(req.path(), "/");
    }

    #[test]
    fn parse_get_with_path() {
        let req = make_get("/roles/host");
        assert_eq!(req.path(), "/roles/host");
    }

    #[test]
    fn parse_get_ignores_query() {
        let req = make_get("/rebuild?foo=bar");
        assert_eq!(req.path(), "/rebuild");
        assert_eq!(req.query_value("foo"), Some("bar".into()));
    }

    #[test]
    fn parse_get_query_empty_value() {
        let req = make_get("/search?q=");
        assert_eq!(req.path(), "/search");
        assert_eq!(req.query_value("q"), Some("".into()));
    }

    #[test]
    fn parse_post_with_form() {
        let req = make_post("/flags", "path=lucy.secrets.enable&value=true");
        assert_eq!(req.method(), &Method::Post);
        assert_eq!(req.path(), "/flags");
        assert_eq!(req.form_value("path"), Some("lucy.secrets.enable".into()));
        assert_eq!(req.form_value("value"), Some("true".into()));
    }

    #[test]
    fn parse_post_empty_body() {
        let req = make_post("/rebuild", "");
        assert_eq!(req.method(), &Method::Post);
        assert_eq!(req.form_value("x"), None);
    }

    #[test]
    fn form_value_missing() {
        let req = make_post("/tags/system", "tag=desktop");
        assert_eq!(req.form_value("nope"), None);
    }

    #[test]
    fn url_decode_spaces() {
        assert_eq!(url_decode("hello+world"), "hello world");
    }

    #[test]
    fn url_decode_percent() {
        assert_eq!(url_decode("%2Froles%2Fhost"), "/roles/host");
    }

    #[test]
    fn url_decode_noop() {
        assert_eq!(url_decode("plain"), "plain");
    }

    #[test]
    fn parse_bad_request() {
        assert!(Request::parse(&mut "BADLINE\n".as_bytes()).is_err());
    }

    #[test]
    fn parse_unsupported_method() {
        assert!(Request::parse(&mut "DELETE /foo HTTP/1.1\r\n\r\n".as_bytes()).is_err());
    }

    #[test]
    fn response_html() {
        let resp = Response::html("<h1>hi</h1>");
        let mut buf = Vec::new();
        resp.write(&mut buf).unwrap();
        let s = String::from_utf8(buf).unwrap();
        assert!(s.starts_with("HTTP/1.1 200 OK\r\n"));
        assert!(s.contains("Content-Type: text/html; charset=utf-8\r\n"));
        assert!(s.contains("<h1>hi</h1>"));
    }

    #[test]
    fn response_css() {
        let resp = Response::css("body {}");
        let mut buf = Vec::new();
        resp.write(&mut buf).unwrap();
        let s = String::from_utf8(buf).unwrap();
        assert!(s.contains("Content-Type: text/css"));
    }

    #[test]
    fn response_not_found() {
        let resp = Response::not_found();
        let mut buf = Vec::new();
        resp.write(&mut buf).unwrap();
        let s = String::from_utf8(buf).unwrap();
        assert!(s.starts_with("HTTP/1.1 404"));
    }
}
