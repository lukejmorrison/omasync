import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'bridge.dart';
import 'update_channel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OmaSyncApp());
}

class OmaSyncApp extends StatelessWidget {
  const OmaSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OmaSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF151613),
          primary: Color(0xFF7D9D8C),
        ),
        scaffoldBackgroundColor: const Color(0xFF0C0D0B),
      ),
      home: const ShellPage(),
    );
  }
}

class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  late final WebViewController _web;
  late final NativeBridge _bridge;
  ShellRelease _release = ShellRelease.offline;
  String _status = 'loading';

  String get _platform => Platform.isIOS ? 'ios' : 'android';

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0C0D0B))
      ..setNavigationDelegate(
        NavigationDelegate(onPageFinished: (_) => _inject()),
      );
    _bridge = NativeBridge(_web);
    _web.addJavaScriptChannel(
      NativeBridge.channel,
      onMessageReceived: (msg) {
        _bridge.handle(msg.message, onCommand: _onNativeCommand);
      },
    );
    _boot();
  }

  Future<void> _boot() async {
    final release = await ShellRelease.pull();
    if (!mounted) return;
    setState(() {
      _release = release;
      _status = release.fromNetwork ? 'live' : 'offline snapshot';
    });
    await _web.loadRequest(Uri.parse(release.uiUrl));
  }

  Future<void> _inject() async {
    await _web.runJavaScript(
      _bridge.bootstrapJs(
        platform: _platform,
        nativeVersion: ShellRelease.nativeVersion,
        uiVersion: _release.uiVersion,
      ),
    );
  }

  void _onNativeCommand(String name, Map<String, dynamic> payload) {
    // Vault / BLE / hotspot land here. The web UI never needs WAN
    // for these — the phone is the node.
    setState(() => _status = name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'OmaSync',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  Text(
                    'native ${ShellRelease.nativeVersion} · ui ${_release.uiVersion} · $_status',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Color(0xFF8F8D84),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: WebViewWidget(controller: _web)),
          ],
        ),
      ),
    );
  }
}
