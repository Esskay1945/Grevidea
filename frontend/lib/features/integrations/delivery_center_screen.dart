import 'dart:async';
import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../core/widgets/grevidea_app_bar.dart';

class DeliveryCenterScreen extends StatefulWidget {
  final AppState appState;
  const DeliveryCenterScreen({super.key, required this.appState});
  @override
  State<DeliveryCenterScreen> createState() => _DeliveryCenterScreenState();
}

class _DeliveryCenterScreenState extends State<DeliveryCenterScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _jobs = [], _contacts = [];
  Map<String, dynamic>? _readiness;
  Timer? _timer;
  String? _error;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    _load();
    _timer ??= Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    final values = await Future.wait([
      widget.appState.api.request('/api/v1/deliveries'),
      widget.appState.api.request('/api/v1/trusted-contacts'),
      widget.appState.api.request('/api/v1/integrations/readiness')
    ]);
    if (mounted)
      setState(() {
        _error = values[0] is List
            ? null
            : 'Sign in and connect to the gateway to view delivery status.';
        if (values[0] is List)
          _jobs = List<Map<String, dynamic>>.from(values[0]);
        if (values[1] is List)
          _contacts = List<Map<String, dynamic>>.from(values[1]);
        if (values[2] is Map) _readiness = Map<String, dynamic>.from(values[2]);
      });
    _loading = false;
  }

  Future<void> _addContact() async {
    final name = TextEditingController(), phone = TextEditingController();
    var consent = false;
    final submit = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, change) => AlertDialog(
                    title: const Text('Trusted emergency contact'),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: name,
                          decoration: const InputDecoration(labelText: 'Name')),
                      TextField(
                          controller: phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                              labelText: 'Phone with country code',
                              hintText: '+919876543210')),
                      CheckboxListTile(
                          value: consent,
                          onChanged: (v) => change(() => consent = v == true),
                          title: const Text(
                              'This person agreed to receive my emergency location alerts.'))
                    ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed:
                              consent ? () => Navigator.pop(ctx, true) : null,
                          child: const Text('Save contact'))
                    ])));
    if (submit == true) {
      final result =
          await widget.appState.api.request('/api/v1/trusted-contacts', data: {
        'name': name.text.trim(),
        'phone': phone.text.trim(),
        'consent_attested': consent
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result == null
                ? 'Contact not saved. Use a valid country-code phone number.'
                : 'Contact saved. Delivery requires an active provider.')));
      await _load();
    }
    name.dispose();
    phone.dispose();
  }

  Future<void> _action(Map<String, dynamic> job, bool cancel) async {
    final result = await widget.appState.api.request(
        cancel
            ? '/api/v1/rewards/${job['entity_id']}/cancel'
            : '/api/v1/deliveries/${job['id']}/retry',
        data: {});
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result == null
              ? 'Action not accepted. Provider handoff may already have started.'
              : cancel
                  ? 'Reward cancelled; points refunded.'
                  : 'Delivery queued for retry.')));
    await widget.appState.syncPendingLedger();
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: GrevideaAppBar(
          title: 'Deliveries & Contacts',
          subtitle: 'Provider receipts and emergency contacts',
          showBack: true,
          appState: widget.appState),
      body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            const Text(
                'A queued request is not a confirmed delivery. For urgent help, contact local emergency services directly.'),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_error!)),
            if (_readiness != null)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                      'Provider setup: SOS ${_readiness!['sos_configured'] == true ? 'connected' : 'needed'} · municipal ${_readiness!['municipal_configured'] == true ? 'connected' : 'needed'} · rewards ${_readiness!['fulfillment_configured'] == true ? 'connected' : 'needed'}')),
            ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Trusted contacts'),
                trailing: IconButton(
                    onPressed: _addContact,
                    icon: const Icon(Icons.person_add_alt))),
            for (final contact in _contacts)
              ListTile(
                  title: Text(contact['name']),
                  subtitle: Text(contact['phone']),
                  trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await widget.appState.api.requestDetailed(
                            '/api/v1/trusted-contacts/${contact['id']}',
                            data: {},
                            method: 'DELETE');
                        await _load();
                      })),
            const Divider(),
            const Text('Delivery status',
                style: TextStyle(fontWeight: FontWeight.bold)),
            if (_jobs.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No SOS, complaint or reward deliveries yet.')),
            for (final job in _jobs)
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${job['kind']} · ${job['status']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text('Reference: ${job['entity_id']}'),
                            if (job['provider_id'] != null)
                              Text('Provider receipt: ${job['provider_id']}'),
                            if (job['last_error'] != null)
                              Text(job['last_error']),
                            if (job['status'] == 'accepted')
                              const Text(
                                  'Provider accepted the request. Confirmation is pending.'),
                            if (job['status'] == 'delivered')
                              const Text(
                                  'Confirmed by the configured provider.'),
                            Wrap(spacing: 8, children: [
                              if (['blocked', 'failed', 'dead_letter']
                                  .contains(job['status']))
                                TextButton(
                                    onPressed: () => _action(job, false),
                                    child: const Text('Retry')),
                              if (job['kind'] == 'reward' &&
                                  ['queued', 'blocked', 'failed', 'dead_letter']
                                      .contains(job['status']))
                                TextButton(
                                    onPressed: () => _action(job, true),
                                    child: const Text('Cancel & refund'))
                            ])
                          ]))),
            if (widget.appState.failedSyncEntries.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                      '${widget.appState.failedSyncEntries.length} local submissions were rejected and need review. Their provisional points are reconciled with the server.')),
          ])));
}
