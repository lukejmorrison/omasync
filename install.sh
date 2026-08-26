#!/usr/bin/env bash
# OmaSync — install daemon + Omarchy plugin on this machine.
# Usage:
#   ./install.sh --role host       # your Omarchy PC
#   ./install.sh --role sink       # Dad's Omarchy laptop
#   ./install.sh --plugin-only     # recopy QML / re-enable bar (no cargo rebuild)
set -euo pipefail

ROLE="host"
DAEMON_ONLY=0
PLUGIN_ONLY=0
ROOT="$(cd "$(dirname "$0")" && pwd)"
# When this file lives in a git clone that also has crates/, use the clone root.
if [[ -d "$ROOT/crates/omasync" ]]; then
  REPO="$ROOT"
  PLUGIN_SRC="$ROOT"
elif [[ -d "$ROOT/../crates/omasync" ]]; then
  REPO="$(cd "$ROOT/.." && pwd)"
  PLUGIN_SRC="$ROOT"
else
  REPO="$ROOT"
  PLUGIN_SRC="$ROOT"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --role) ROLE="${2:-host}"; shift 2 ;;
    --role=*) ROLE="${1#*=}"; shift ;;
    --daemon-only) DAEMON_ONLY=1; shift ;;
    --plugin-only) PLUGIN_ONLY=1; shift ;;
    -h|--help)
      sed -n '2,7p' "$0"
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ "$ROLE" != "host" && "$ROLE" != "sink" ]]; then
  echo "role must be host or sink" >&2
  exit 2
fi

install_plugin() {
  DEST="$HOME/.config/omarchy/plugins/wizwam.omasync"
  mkdir -p "$DEST/qml"
  cp -a "$PLUGIN_SRC/manifest.json" "$DEST/"
  cp -a "$PLUGIN_SRC/qml/." "$DEST/qml/"
  if [[ -f "$PLUGIN_SRC/omasync.svg" ]]; then
    cp -a "$PLUGIN_SRC/omasync.svg" "$DEST/"
  fi
  echo "→ plugin files at $DEST"

  APP_DIR="$HOME/.local/share/applications"
  ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"
  mkdir -p "$APP_DIR" "$ICON_DIR"
  if [[ -f "$PLUGIN_SRC/omasync.svg" ]]; then
    cp "$PLUGIN_SRC/omasync.svg" "$ICON_DIR/omasync.svg"
  elif [[ -f "$REPO/public/favicon.svg" ]]; then
    cp "$REPO/public/favicon.svg" "$ICON_DIR/omasync.svg"
  fi
  cat >"$APP_DIR/omasync.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=OmaSync
Comment=Carry folders without the internet
Exec=omarchy-shell shell toggle wizwam.omasync '{}'
Icon=omasync
Terminal=false
Categories=Utility;Network;
Keywords=sync;nas;bluetooth;hotspot;omarchy;
StartupNotify=false
EOF
  update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true
  echo "→ application menu entry installed"

  if command -v omarchy >/dev/null 2>&1; then
    omarchy plugin validate "$DEST" || true
    omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
    if ! omarchy plugin enable wizwam.omasync --section right --yes 2>/dev/null; then
      echo "→ shell IPC missed — restarting omarchy-shell"
      omarchy-restart-shell >/dev/null 2>&1 || true
      sleep 1
      omarchy plugin enable wizwam.omasync --section right --yes 2>/dev/null \
        || omarchy plugin enable wizwam.omasync --section right || true
    fi
    echo "→ bar widget enabled (right section, icon-only)"
  else
    echo "omarchy CLI not found — open Setup → Plugins and enable wizwam.omasync"
  fi
}

if [[ "$PLUGIN_ONLY" -eq 1 ]]; then
  install_plugin
  echo
  echo "plugin recopy done. Restart the bar if the icon is still the old text chip:"
  echo "  omarchy-restart-shell"
  exit 0
fi

if ! command -v cargo >/dev/null 2>&1; then
  echo "Rust is missing. On Omarchy:  sudo pacman -S rust" >&2
  exit 1
fi

echo "→ building omasyncd"
cargo install --path "$REPO/crates/omasync" --force

BIN="${CARGO_HOME:-$HOME/.cargo}/bin/omasyncd"
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
if [[ -x "$BIN" ]]; then
  ln -sfn "$BIN" "$LOCAL_BIN/omasyncd"
fi

CONF_DIR="$HOME/.config/omasync"
mkdir -p "$CONF_DIR"
if [[ ! -f "$CONF_DIR/config.toml" ]]; then
  if [[ "$ROLE" == "sink" ]]; then
    cat >"$CONF_DIR/config.toml" <<'EOF'
role = "sink"
hotspot_ssid = "Dad-A15"
destination = "~/Incoming/OmaSync"
EOF
  else
    cat >"$CONF_DIR/config.toml" <<'EOF'
role = "host"
hotspot_ssid = "Dad-A15"
destination = "~/Incoming/OmaSync"
EOF
  fi
  echo "→ wrote $CONF_DIR/config.toml  (role=$ROLE)"
fi

UNIT_DIR="$HOME/.config/systemd/user"
mkdir -p "$UNIT_DIR"
cat >"$UNIT_DIR/omasyncd.service" <<EOF
[Unit]
Description=OmaSync mesh daemon
After=default.target

[Service]
ExecStart=$LOCAL_BIN/omasyncd
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now omasyncd.service
echo "→ omasyncd user service running"

if [[ "$DAEMON_ONLY" -eq 0 ]]; then
  install_plugin
fi

echo
echo "done.  omasyncd status:"
omasyncd status || true
echo
echo "Bar: icon-only OmaSync on the right. Hover for alt text, click for the app."
echo "App menu: Super, type OmaSync."
