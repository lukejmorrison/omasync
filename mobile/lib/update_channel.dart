import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Rails-style release channel.
///
/// The App Store binary is [nativeVersion] and almost never changes.
/// [uiVersion] + [uiUrl] come from shell.json. Phones pull that file whenever
/// they have WAN; offline they keep the last snapshot.
class ShellRelease {
  static const nativeVersion = '1.0.0';
  static const fallbackUi = 'https://omasync.grok.me/';
  static const manifests = [
    'https://omasync.grok.me/shell.json',
    'https://omasync.wizwam.com/shell.json',
  ];

  final String uiVersion;
  final String uiUrl;
  final bool fromNetwork;

  const ShellRelease({
    required this.uiVersion,
    required this.uiUrl,
    required this.fromNetwork,
  });

  static const offline = ShellRelease(
    uiVersion: '0.1.3',
    uiUrl: fallbackUi,
    fromNetwork: false,
  );

  static Future<ShellRelease> pull() async {
    final prefs = await SharedPreferences.getInstance();
    for (final raw in manifests) {
      try {
        final res = await http.get(Uri.parse(raw)).timeout(
          const Duration(seconds: 4),
        );
        if (res.statusCode != 200) continue;
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final ui = json['ui'] as Map<String, dynamic>? ?? {};
        final version = ui['version'] as String? ?? offline.uiVersion;
        final url = ui['url'] as String? ?? fallbackUi;
        await prefs.setString('uiVersion', version);
        await prefs.setString('uiUrl', url);
        return ShellRelease(
          uiVersion: version,
          uiUrl: url,
          fromNetwork: true,
        );
      } catch (_) {
        continue;
      }
    }
    final cachedV = prefs.getString('uiVersion');
    final cachedU = prefs.getString('uiUrl');
    if (cachedV != null && cachedU != null) {
      return ShellRelease(
        uiVersion: cachedV,
        uiUrl: cachedU,
        fromNetwork: false,
      );
    }
    return offline;
  }
}
