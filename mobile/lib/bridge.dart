import 'dart:convert';

import 'package:webview_flutter/webview_flutter.dart';

/// JS ↔ Dart. The web UI talks to the native shell the way a Rails view
/// talks to the server — except the "server" is this phone (vault, BLE,
/// hotspot) so Dad's house still works with no WAN.
class NativeBridge {
  NativeBridge(this.controller);

  final WebViewController controller;

  static const channel = 'OmaSync';

  String bootstrapJs({
    required String platform,
    required String nativeVersion,
    required String uiVersion,
  }) {
    return '''
      window.OmaSyncNative = {
        platform: ${jsonEncode(platform)},
        nativeVersion: ${jsonEncode(nativeVersion)},
        uiVersion: ${jsonEncode(uiVersion)},
        post: function (name, payload) {
          if (window.OmaSync && window.OmaSync.postMessage) {
            window.OmaSync.postMessage(JSON.stringify({ name: name, payload: payload || {} }));
          }
        }
      };
      document.dispatchEvent(new Event('omasync-native-ready'));
    ''';
  }

  Future<void> handle(String message, {required void Function(String name, Map<String, dynamic> payload) onCommand}) async {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final name = data['name'] as String? ?? '';
      final payload = (data['payload'] as Map?)?.cast<String, dynamic>() ?? {};
      onCommand(name, payload);
    } catch (_) {}
  }
}
