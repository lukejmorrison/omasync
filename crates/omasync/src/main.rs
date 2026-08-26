use omasync::inbox::WaitingOffer;
use omasync::{
    config_path, demo_inbox, expand_dest, inbox_path, load_config, load_or_seed, runtime_dir,
    save_inbox, socket_path, write_receipt, Config, Inbox,
};
use serde::Serialize;
use std::io::{Read, Write};
use std::os::unix::net::{UnixListener, UnixStream};
use std::time::{SystemTime, UNIX_EPOCH};

fn main() {
    let mut args = std::env::args().skip(1);
    let cmd = args.next().unwrap_or_default();
    match cmd.as_str() {
        "status" | "-s" => cmd_status(),
        "role" => {
            let cfg = load_config(&config_path());
            println!("{}", cfg.role);
        }
        "demo-offer" | "demo" => {
            let inbox = demo_inbox();
            let path = inbox_path();
            if let Err(err) = save_inbox(&path, &inbox) {
                eprintln!("omasyncd: cannot write {}: {err}", path.display());
                std::process::exit(1);
            }
            println!("{}", status_from(&load_config(&config_path()), true, &inbox));
        }
        "toggle" => {
            let id = args.next().unwrap_or_default();
            let path = args.next().unwrap_or_default();
            mutate(|inbox| inbox.toggle(&id, &path));
        }
        "select-all" => {
            let id = args.next().unwrap_or_default();
            let on = args.next().unwrap_or_else(|| "1".into());
            let on = on != "0" && on != "false";
            mutate(|inbox| inbox.select_all(&id, on));
        }
        "accept" => {
            let id = args.next().unwrap_or_default();
            cmd_accept(&id);
        }
        "dismiss" => {
            let id = args.next().unwrap_or_default();
            mutate(|inbox| inbox.dismiss(&id));
        }
        "help" | "--help" | "-h" => print_help(),
        "" | "daemon" | "--daemon" => run_daemon(),
        other => {
            eprintln!("omasyncd: unknown command '{other}'");
            print_help();
            std::process::exit(2);
        }
    }
}

fn print_help() {
    eprintln!(
        "omasyncd 0.1.3 — offline mesh file carry

commands
  omasyncd              run the daemon (socket $XDG_RUNTIME_DIR/omasync.sock)
  omasyncd status       JSON status, including waiting folders
  omasyncd demo-offer   seed a Videos + For Dad inbox (flashes the bar chip)
  omasyncd toggle ID PATH
  omasyncd select-all ID 1|0
  omasyncd accept ID
  omasyncd dismiss ID

config
  ~/.config/omasync/config.toml
inbox
  ~/.local/share/omasync/inbox.json
"
    );
}

fn cmd_status() {
    match ask("status") {
        Ok(body) => {
            print!("{body}");
            if !body.ends_with('\n') {
                println!();
            }
        }
        Err(_) => {
            let cfg = load_config(&config_path());
            let inbox = load_or_seed(&inbox_path());
            println!("{}", status_from(&cfg, false, &inbox));
            std::process::exit(1);
        }
    }
}

fn mutate(f: impl FnOnce(&mut Inbox) -> bool) {
    let path = inbox_path();
    let mut inbox = load_or_seed(&path);
    let _ = f(&mut inbox);
    let _ = save_inbox(&path, &inbox);
    let cfg = load_config(&config_path());
    println!("{}", status_from(&cfg, true, &inbox));
}

fn cmd_accept(id: &str) {
    let path = inbox_path();
    let mut inbox = load_or_seed(&path);
    let cfg = load_config(&config_path());
    if let Some(taken) = inbox.accept(id) {
        let dest = expand_dest(&cfg.destination);
        match write_receipt(&dest, &taken) {
            Ok(receipt) => eprintln!(
                "omasyncd: accepted {} file(s) from \"{}\" → {}",
                taken.files.len(),
                taken.name,
                receipt.display()
            ),
            Err(err) => eprintln!("omasyncd: receipt failed: {err}"),
        }
    }
    let _ = save_inbox(&path, &inbox);
    println!("{}", status_from(&cfg, true, &inbox));
}

fn ask(msg: &str) -> std::io::Result<String> {
    let mut stream = UnixStream::connect(socket_path())?;
    stream.write_all(msg.as_bytes())?;
    stream.write_all(b"\n")?;
    stream.shutdown(std::net::Shutdown::Write)?;
    let mut buf = String::new();
    stream.read_to_string(&mut buf)?;
    Ok(buf)
}

fn run_daemon() {
    let sock = socket_path();
    let _ = std::fs::create_dir_all(runtime_dir());
    let _ = std::fs::remove_file(&sock);
    let listener = match UnixListener::bind(&sock) {
        Ok(l) => l,
        Err(err) => {
            eprintln!("omasyncd: already running or cannot bind {sock:?}: {err}");
            std::process::exit(1);
        }
    };
    // Seed a demo inbox the first time so the chip has something to pulse.
    let _ = load_or_seed(&inbox_path());
    println!(
        "omasyncd 0.1.3 listening on {} · config {}",
        sock.display(),
        config_path().display()
    );
    for incoming in listener.incoming() {
        let Ok(mut stream) = incoming else { continue };
        let mut buf = String::new();
        let _ = stream.read_to_string(&mut buf);
        let reply = handle_line(buf.trim());
        let _ = stream.write_all(reply.as_bytes());
        let _ = stream.write_all(b"\n");
    }
}

fn handle_line(line: &str) -> String {
    let cfg = load_config(&config_path());
    let path = inbox_path();
    let mut inbox = load_or_seed(&path);
    let mut parts = line.splitn(3, ' ');
    let cmd = parts.next().unwrap_or("status");
    match cmd {
        "status" | "" => {}
        "demo-offer" | "demo" => {
            inbox = demo_inbox();
            let _ = save_inbox(&path, &inbox);
        }
        "toggle" => {
            let id = parts.next().unwrap_or("");
            let file = parts.next().unwrap_or("");
            inbox.toggle(id, file);
            let _ = save_inbox(&path, &inbox);
        }
        "select-all" => {
            let id = parts.next().unwrap_or("");
            let on = parts.next().unwrap_or("1");
            inbox.select_all(id, on != "0" && on != "false");
            let _ = save_inbox(&path, &inbox);
        }
        "accept" => {
            let id = parts.next().unwrap_or("");
            if let Some(taken) = inbox.accept(id) {
                let dest = expand_dest(&cfg.destination);
                let _ = write_receipt(&dest, &taken);
            }
            let _ = save_inbox(&path, &inbox);
        }
        "dismiss" => {
            let id = parts.next().unwrap_or("");
            inbox.dismiss(id);
            let _ = save_inbox(&path, &inbox);
        }
        _ => {}
    }
    status_from(&cfg, true, &inbox)
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct StatusFile<'a> {
    path: &'a str,
    name: &'a str,
    size: u64,
    on: bool,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct StatusOffer<'a> {
    id: &'a str,
    name: &'a str,
    from: &'a str,
    file_count: usize,
    selected: usize,
    size: u64,
    files: Vec<StatusFile<'a>>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct StatusBody<'a> {
    ok: bool,
    version: &'a str,
    plugin: &'a str,
    role: &'a str,
    state: &'a str,
    online: bool,
    hotspot: &'a str,
    destination: &'a str,
    waiting_count: usize,
    waiting_files: usize,
    waiting_names: Vec<String>,
    waiting: Vec<StatusOffer<'a>>,
    ts: u64,
}

fn status_from(cfg: &Config, online: bool, inbox: &Inbox) -> String {
    let ts = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let state = if !online {
        "offline"
    } else if inbox.waiting_count() > 0 {
        "waiting"
    } else {
        "idle"
    };
    let waiting: Vec<StatusOffer> = inbox
        .offers
        .iter()
        .map(status_offer)
        .collect();
    let body = StatusBody {
        ok: online,
        version: "0.1.3",
        plugin: "wizwam.omasync",
        role: &cfg.role,
        state,
        online,
        hotspot: &cfg.hotspot_ssid,
        destination: &cfg.destination,
        waiting_count: inbox.waiting_count(),
        waiting_files: inbox.waiting_files(),
        waiting_names: inbox.names(),
        waiting,
        ts,
    };
    serde_json::to_string(&body).unwrap_or_else(|_| "{\"ok\":false}".into())
}

fn status_offer(o: &WaitingOffer) -> StatusOffer<'_> {
    StatusOffer {
        id: &o.id,
        name: &o.name,
        from: &o.from,
        file_count: o.file_count(),
        selected: o.selected_count(),
        size: o.size(),
        files: o
            .files
            .iter()
            .map(|f| StatusFile {
                path: &f.path,
                name: &f.name,
                size: f.size,
                on: f.on,
            })
            .collect(),
    }
}
