use omasync::{config_path, load_config, runtime_dir, socket_path, Config};
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
        "omasyncd 0.1.0 — offline mesh file carry\n\ncommands\n  omasyncd           run the daemon (socket $XDG_RUNTIME_DIR/omasync.sock)\n  omasyncd status    print JSON status\n  omasyncd role      print configured role (host|sink)\n\nconfig\n  ~/.config/omasync/config.toml\n",
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
            println!("{}", status_json(&cfg, false, "offline"));
            std::process::exit(1);
        }
    }
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
    println!(
        "omasyncd 0.1.0 listening on {} · config {}",
        sock.display(),
        config_path().display()
    );
    for incoming in listener.incoming() {
        let Ok(mut stream) = incoming else { continue };
        let mut buf = String::new();
        let _ = stream.read_to_string(&mut buf);
        let cfg = load_config(&config_path());
        let body = status_json(&cfg, true, "idle");
        let _ = stream.write_all(body.as_bytes());
        let _ = stream.write_all(b"\n");
    }
}

fn status_json(cfg: &Config, online: bool, state: &str) -> String {
    let ts = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    format!(
        "{{\"ok\":{},\"version\":\"0.1.0\",\"plugin\":\"wizwam.omasync\",\"role\":\"{}\",\"state\":\"{}\",\"online\":{},\"hotspot\":\"{}\",\"destination\":\"{}\",\"ts\":{}}}",
        if online { "true" } else { "false" },
        escape(&cfg.role),
        escape(state),
        if online { "true" } else { "false" },
        escape(&cfg.hotspot_ssid),
        escape(&cfg.destination),
        ts,
    )
}

fn escape(s: &str) -> String {
    s.replace('\\', "\\\\").replace('"', "\\\"")
}
