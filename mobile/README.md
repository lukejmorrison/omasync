# OmaSync phone shell

One Flutter binary for **iPhone** and **Android**.

The store build is the passenger (Bluetooth, hotspot, on-device vault, notifications). The UI is a Rails deploy: publish [omasync.grok.me](https://omasync.grok.me) / [omasync.wizwam.com](https://omasync.wizwam.com), phones pull `shell.json` the next time they see Wi-Fi. No App Store wait. At Dad's house there is no WAN — they keep the last snapshot and talk over Bluetooth + his hotspot.

```
  App Store binary     rarely changes     native 1.0.0
  shell.json + web UI  push anytime       ui 0.1.3, 0.1.4, …
```

## First run (Mac or Omarchy with Flutter)

```bash
cd mobile
flutter create --org com.wizwam --project-name omasync --platforms=ios,android .
# this keeps lib/ and pubspec.yaml
flutter pub get
flutter run
```

Android package: `com.wizwam.omasync`  
iOS bundle: `com.wizwam.omasync`

## How an update ships

1. Change the web app. Publish it (Grok / wizwam.com).
2. Bump `ui.version` in `public/shell.json`.
3. Any phone that later joins home Wi-Fi (or any WAN) fetches `shell.json` and loads the new UI.
4. Dad's house: no fetch. Last UI + local vault + BLE + hotspot still work.

The Flutter shell is not resubmitted unless you need a new native API (new BLE permission, etc.) — same as not rebuilding Apache when you `cap deploy`.
