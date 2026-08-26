//! OmaSync protocol: carry folders between Omarchy hosts and companion phones
//! with no internet. The daemon (`omasyncd`) indexes shares, picks a transport,
//! and copies only the files the sink accepted.

use std::collections::HashSet;
use std::path::{Path, PathBuf};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Role {
    Host,
    Carrier,
    Relay,
    Sink,
    Nas,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Transport {
    Wifi,
    Bluetooth,
    Hotspot,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct FileMeta {
    pub path: String,
    pub size: u64,
    pub mtime: i64,
}

#[derive(Clone, Debug)]
pub struct Share {
    pub id: String,
    pub name: String,
    pub files: Vec<FileMeta>,
}

#[derive(Clone, Debug)]
pub struct Offer {
    pub from: String,
    pub to: String,
    pub files: Vec<FileMeta>,
}

#[derive(Clone, Debug)]
pub struct Config {
    pub role: String,
    pub hotspot_ssid: String,
    pub destination: String,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            role: "host".into(),
            hotspot_ssid: "Dad-A15".into(),
            destination: "~/Incoming/OmaSync".into(),
        }
    }
}

pub fn home_dir() -> PathBuf {
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/tmp"))
}

pub fn config_path() -> PathBuf {
    home_dir().join(".config/omasync/config.toml")
}

pub fn runtime_dir() -> PathBuf {
    std::env::var_os("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/tmp"))
}

pub fn socket_path() -> PathBuf {
    runtime_dir().join("omasync.sock")
}

pub fn load_config(path: &Path) -> Config {
    let mut cfg = Config::default();
    let Ok(text) = std::fs::read_to_string(path) else {
        return cfg;
    };
    for raw in text.lines() {
        let line = raw.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let Some((k, v)) = line.split_once('=') else {
            continue;
        };
        let key = k.trim();
        let val = v.trim().trim_matches('"').trim_matches('\'').to_string();
        match key {
            "role" => cfg.role = val,
            "hotspot_ssid" => cfg.hotspot_ssid = val,
            "destination" => cfg.destination = val,
            _ => {}
        }
    }
    cfg
}

pub fn pick_transport(
    from: Role,
    to: Role,
    proximity: bool,
    same_hotspot: bool,
) -> Option<Transport> {
    match (from, to) {
        (Role::Nas, Role::Host) | (Role::Host, Role::Carrier) => Some(Transport::Wifi),
        (Role::Carrier, Role::Relay) if proximity => Some(Transport::Bluetooth),
        (Role::Relay, Role::Sink) if same_hotspot => Some(Transport::Hotspot),
        _ => None,
    }
}

pub fn plan_copy(local: &[FileMeta], remote: &[FileMeta]) -> Vec<FileMeta> {
    let have: HashSet<(String, u64)> = local
        .iter()
        .map(|f| (f.path.clone(), f.size))
        .collect();
    remote
        .iter()
        .filter(|f| !have.contains(&(f.path.clone(), f.size)))
        .cloned()
        .collect()
}

pub fn accept_offer(offer: &Offer, accepted_paths: &HashSet<String>) -> Vec<FileMeta> {
    offer
        .files
        .iter()
        .filter(|f| accepted_paths.contains(&f.path))
        .cloned()
        .collect()
}

pub fn transport_label(t: Transport) -> &'static str {
    match t {
        Transport::Wifi => "wifi",
        Transport::Bluetooth => "bluetooth",
        Transport::Hotspot => "hotspot",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bluetooth_only_in_proximity() {
        assert!(pick_transport(Role::Carrier, Role::Relay, false, false).is_none());
        assert_eq!(
            pick_transport(Role::Carrier, Role::Relay, true, false),
            Some(Transport::Bluetooth)
        );
    }

    #[test]
    fn hotspot_needs_shared_ap() {
        assert!(pick_transport(Role::Relay, Role::Sink, true, false).is_none());
        assert_eq!(
            pick_transport(Role::Relay, Role::Sink, false, true),
            Some(Transport::Hotspot)
        );
    }

    #[test]
    fn config_parses_role() {
        let dir = std::env::temp_dir().join("omasync-test-cfg");
        let _ = std::fs::create_dir_all(&dir);
        let path = dir.join("config.toml");
        std::fs::write(&path, "role = \"sink\"\nhotspot_ssid = \"Dad-A15\"\n").unwrap();
        let cfg = load_config(&path);
        assert_eq!(cfg.role, "sink");
        assert_eq!(cfg.hotspot_ssid, "Dad-A15");
    }
}
