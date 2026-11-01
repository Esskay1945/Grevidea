import 'package:flutter/material.dart';
import '../network/api_service.dart';
import '../../state/app_state.dart';

class ConnectionSettingsDialog extends StatefulWidget {
  final AppState appState;
  const ConnectionSettingsDialog({super.key, required this.appState});
  @override State<ConnectionSettingsDialog> createState() => _ConnectionSettingsDialogState();
}
class _ConnectionSettingsDialogState extends State<ConnectionSettingsDialog> {
  final _form = GlobalKey<FormState>();
  late final _url = TextEditingController(text: widget.appState.api.baseUrl);
  bool _busy = false;
  String? _message;
  @override void dispose() { _url.dispose(); super.dispose(); }
  Future<void> _connect() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() { _busy = true; _message = null; });
    final probe = ApiService.forEndpoint(_url.text.trim());
    try {
      final result = await probe.inspectConnection();
      if (!mounted) return;
      if (result['ready'] != true) { setState(() => _message = result['message']); return; }
      await widget.appState.saveGatewayUrl(probe.baseUrl);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(result['message'])));
    } catch (_) {
      if (mounted) setState(() => _message = 'Connection could not be saved. Check the server address and retry.');
    } finally { probe.close(); if (mounted) setState(() => _busy = false); }
  }
  @override Widget build(BuildContext context) => AlertDialog(
    title: const Text('Connect to your app server'),
    content: SingleChildScrollView(child: Form(key: _form, child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Keep Axum running on your laptop. For USB, run adb reverse tcp:3000 tcp:3000 and use http://localhost:3000. For Wi-Fi, use your laptop’s IPv4 address and port 3000 on the same network.'),
        const SizedBox(height: 16),
        TextFormField(controller: _url, enabled: !_busy, keyboardType: TextInputType.url,
          autocorrect: false, validator: (v) => ApiService.validateBaseUrl(v ?? ''),
          decoration: const InputDecoration(labelText: 'Axum server URL', hintText: 'http://192.168.1.10:3000')),
        const SizedBox(height: 8),
        const Text('Use the Axum server address, not the Supabase project URL.'),
        if (_message != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_message!)),
      ],
    ))),
    actions: [
      TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _busy ? null : _connect, child: Text(_busy ? 'Checking…' : 'Test and save')),
    ],
  );
}
