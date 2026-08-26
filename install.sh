#!/usr/bin/env bash
# OmaSync — install daemon + Omarchy plugin on this machine.
# Usage:
#   ./install.sh --role host       # your Omarchy PC (fetches 0.1.3 if the tree is stale)
#   ./install.sh --role sink       # Dad's Omarchy laptop
#   ./install.sh --plugin-only     # recopy QML / re-enable bar (no cargo rebuild)
#   ./install.sh --no-update       # do not git stash/pull
set -euo pipefail

NEED_VERSION="0.1.3"
ROLE="host"
DAEMON_ONLY=0
PLUGIN_ONLY=0
DO_UPDATE=1
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
    --no-update) DO_UPDATE=0; shift ;;
    --update) DO_UPDATE=1; shift ;;
    -h|--help)
      sed -n '2,8p' "$0"
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ "$ROLE" != "host" && "$ROLE" != "sink" ]]; then
  echo "role must be host or sink" >&2
  exit 2
fi

crate_version() {
  grep -m1 '^version' "$REPO/crates/omasync/Cargo.toml" 2>/dev/null \
    | sed -E 's/.*"([^"]+)".*/\1/' || echo "0.0.0"
}

sync_repo() {
  if [[ "$DO_UPDATE" -ne 1 ]]; then
    return
  fi
  if [[ ! -d "$REPO/.git" ]]; then
    return
  fi
  echo "→ fetching origin"
  git -C "$REPO" fetch origin --quiet 2>/dev/null || true
  local dirty=0
  if ! git -C "$REPO" diff --quiet || ! git -C "$REPO" diff --cached --quiet; then
    dirty=1
  fi
  if [[ -n "$(git -C "$REPO" ls-files --others --exclude-standard)" ]]; then
    dirty=1
  fi
  if [[ "$dirty" -eq 1 ]]; then
    echo "→ local edits in the way of git pull — stashing"
    git -C "$REPO" stash push -u -m "omasync-install auto-stash $(date -Iseconds)" || true
  fi
  local branch
  branch="$(git -C "$REPO" rev-parse --abbrev-ref HEAD)"
  if git -C "$REPO" pull --ff-only origin "$branch"; then
    echo "→ git tree is $(git -C "$REPO" rev-parse --short HEAD) ($branch)"
  else
    echo "warn: git pull failed — building whatever is in $REPO" >&2
  fi
}

stop_daemons() {
  echo "→ stopping any running omasyncd (systemd + stray shells)"
  systemctl --user stop omasyncd.service 2>/dev/null || true
  # the `omasyncd &` from a terminal holds the socket and shadows the new binary
  pkill -u "$USER" -x omasyncd 2>/dev/null || true
  pkill -u "$USER" -f '[/]omasyncd$' 2>/dev/null || true
  local sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/omasync.sock"
  rm -f "$sock"
  sleep 0.3
}

install_plugin() {
  DEST="$HOME/.config/omarchy/plugins/wizwam.omasync"
  mkdir -p "$DEST/qml"
  cp -a "$PLUGIN_SRC/manifest.json" "$DEST/"
  cp -a "$PLUGIN_SRC/qml/." "$DEST/qml/"
  if [[ -f "$PLUGIN_SRC/omasync.svg" ]]; then
    cp -a "$PLUGIN_SRC/omasync.svg" "$DEST/"
  fi
  if ! grep -q 'BarIconButton' "$DEST/qml/BarWidget.qml" 2>/dev/null; then
    echo "error: copied BarWidget.qml is the old text chip, not the icon widget" >&2
    echo "       $DEST/qml/BarWidget.qml" >&2
    exit 1
  fi
  echo "→ plugin files at $DEST  (icon-only BarIconButton)"

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

sync_repo

HAVE_VERSION="$(crate_version)"
echo "→ crate in $REPO is omasync $HAVE_VERSION"
if [[ "$HAVE_VERSION" != "$NEED_VERSION" ]]; then
  echo "error: this tree is $HAVE_VERSION, need $NEED_VERSION" >&2
  echo "       cd $REPO && git stash -u && git pull && $0 --role $ROLE" >&2
  exit 1
fi

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

stop_daemons

echo "→ building omasyncd $NEED_VERSION"
cargo install --path "$REPO/crates/omasync" --force --locked 2>/dev/null \
  || cargo install --path "$REPO/crates/omasync" --force

BIN="${CARGO_HOME:-$HOME/.cargo}/bin/omasyncd"
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
if [[ -x "$BIN" ]]; then
  ln -sfn "$BIN" "$LOCAL_BIN/omasyncd"
fi
hash -r 2>/dev/null || true
export PATH="$LOCAL_BIN:${CARGO_HOME:-$HOME/.cargo}/bin:$PATH"

BIN_VER="$("$BIN" version 2>/dev/null || true)"
echo "→ installed $BIN_VER"
if [[ "$BIN_VER" != *"$NEED_VERSION"* ]]; then
  echo "error: cargo installed something other than $NEED_VERSION:" >&2
  echo "       $BIN_VER" >&2
  echo "       which -a omasyncd" >&2
  which -a omasyncd || true
  exit 1
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
systemctl --user enable omasyncd.service
systemctl --user restart omasyncd.service
sleep 0.4
echo "→ omasyncd user service running"

if [[ "$DAEMON_ONLY" -eq 0 ]]; then
  install_plugin
fi

# Seed the Videos demo so the chip has something to pulse on first run.
"$BIN" demo-offer >/dev/null || true

echo
echo "done.  binary:  $("$BIN" version)"
echo "       status:  $("$BIN" status)"
echo
echo "Bar should now be an icon (no 'OmaSync' label). Hover = alt text. Click = picker."
echo "If the old text chip is still there:"
echo "  omarchy-restart-shell"
echo "App menu: Super, type OmaSync."
