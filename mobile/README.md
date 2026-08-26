# OmaSync phone shell

One Flutter binary for **iPhone** and **Android**.

The store build is the passenger (Bluetooth, hotspot, on-device vault, notifications). The UI deploys like Rails: publish [omasync.grok.me](https://omasync.grok.me) / [omasync.wizwam.com](https://omasync.wizwam.com), phones pull `shell.json` the next time they see Wi-Fi. No App Store wait. At Dad's house there is no WAN — they keep the last snapshot and talk over Bluetooth + his hotspot.

```
  App Store binary     rarely changes     native 1.0.0
  shell.json + web UI  push anytime       ui 0.1.3, 0.1.4, …
```

## First run

Do this from **OmaSync**, not FishHook / omamusic. `flutter create .` inside another app will overwrite `lib/main.dart` and can leave **Android v1 embedding** (that build error).

```bash
cd ~/dev/omasync
git pull
chmod +x mobile/bootstrap.sh
./mobile/bootstrap.sh
cd ~/dev/omasync-phone
flutter devices
flutter run -d 57250DLAQ0020D    # your Pixel 9 over USB
```

`bootstrap.sh` creates a **fresh** project at `~/dev/omasync-phone` (v2 embedding), then copies this `lib/` and `pubspec.yaml` on top.

Android package: `com.wizwam.omasync`  
iOS bundle: `com.wizwam.omasync`

iOS still needs a Mac + Xcode. The Pixel is enough for Android.

## How an update ships

1. Change the web app. Publish it (Grok / wizwam.com).
2. Bump `ui.version` in `public/shell.json` (or `shell.json` in this repo).
3. Any phone that later joins home Wi-Fi fetches `shell.json` and loads the new UI.
4. Dad's house: no fetch. Last UI + local vault + BLE + hotspot still work.

The Flutter shell is not resubmitted unless you need a new native API (new BLE permission, etc.) — same as not rebuilding Apache when you `cap deploy`.
