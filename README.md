# OmaSync

Offline folder carry for [Omarchy](https://omarchy.org): NAS/PC → phone → Bluetooth → Dad's Android hotspot → his Omarchy laptop. No internet.

## Install

**Your Omarchy PC** (has internet):

```bash
git clone https://github.com/lukejmorrison/omasync.git
cd omasync
chmod +x install.sh
./install.sh --role host
```

**Dad's Omarchy laptop** — if it has no WAN, copy this folder over USB (or clone while the laptop is on a hotspot), then:

```bash
chmod +x install.sh
./install.sh --role sink
```

`install.sh` will:

1. Build `omasyncd` (Rust daemon) into `~/.local/bin`
2. Enable a systemd user service
3. Install the Omarchy 4 plugin `wizwam.omasync`
4. Put an **OmaSync icon** on the **right side of the top bar** (hover for alt text, click for the app dropdown)
5. Add **OmaSync** to the Super-key application menu

When someone nearby shares a folder, the bar icon **breathes green** (a stronger flash once a minute). Hover shows the folder names. Click the icon to pick which files to keep.

```
Files waiting
You have a folder called Videos
click a file to keep it, then Accept
```

Seed a demo offer on this machine (so you can see the pulse without going to Dad's):

```bash
omasyncd demo-offer
```

Middle-click (or press `o` in the panel) opens [omasync.grok.me](https://omasync.grok.me/) in a window. Right-click refreshes daemon status.

### Update the bar plugin only

```bash
cd ~/dev/omasync
git pull
./install.sh --plugin-only
omarchy-restart-shell
```

If the chip is missing after install:

```bash
omarchy plugin enable wizwam.omasync --section right
```

To embed the app inside the dropdown (not just “Open in window”), install WebEngine once:

```bash
sudo pacman -S qt6-webengine
omarchy-restart-shell
```

Drag the icon on the bar to move it. Super, type `OmaSync` to open the panel.

## Config

`~/.config/omasync/config.toml`

```toml
role = "host"          # host on your PC, sink on Dad's laptop
hotspot_ssid = "Dad-A15"
destination = "~/Incoming/OmaSync"
```

## Roles

| Machine | `--role` | What it does |
|---|---|---|
| Your Omarchy PC | `host` | Indexes NAS/local shares, mirrors to your phone |
| Dad's Omarchy laptop | `sink` | Joins his Android hotspot, asks which files to land |
