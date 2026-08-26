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
4. Put **OmaSync** on the **right side of the top bar**
5. Add **OmaSync** to the Super-key application menu

If the chip is missing after install:

```bash
omarchy plugin enable wizwam.omasync --section right
```

Drag it on the bar to move it. Super, type `OmaSync` to open the panel.

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
