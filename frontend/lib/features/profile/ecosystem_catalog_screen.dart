import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../state/app_state.dart';
import '../../core/widgets/grevidea_app_bar.dart';

/// All registered ecosystem capabilities, using actual authenticated handlers.
class EcosystemCatalogScreen extends StatefulWidget {
  final AppState appState;
  const EcosystemCatalogScreen({super.key, required this.appState});
  @override
  State<EcosystemCatalogScreen> createState() => _EcosystemCatalogScreenState();
}

class _EcosystemCatalogScreenState extends State<EcosystemCatalogScreen> {
  late final Future<List<dynamic>> _catalog;
  @override
  void initState() {
    super.initState();
    _catalog = rootBundle
        .loadString('assets/feature_catalog.json')
        .then((text) => jsonDecode(text) as List);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: GrevideaAppBar(title: 'Features', showBack: true, appState: widget.appState),
    body: SingleChildScrollView(child: EcosystemFeatureGroups(appState: widget.appState)),
  );
}

class EcosystemFeatureGroups extends StatelessWidget {
  final AppState appState;
  const EcosystemFeatureGroups({super.key, required this.appState});
  static final _catalog = rootBundle.loadString('assets/feature_catalog.json')
      .then((text) => jsonDecode(text) as List);
  static const groups = {
    'gci_proxy': 'Climate assistance',
    'footprint': 'Footprint and travel',
    'marketplace': 'Shopping and sharing',
    'civic': 'City and resilience',
    'gamification': 'Points and community',
    'platform': 'Account and learning',
  };
  @override
  Widget build(BuildContext context) => FutureBuilder<List>(
    future: _catalog,
    builder: (context, snapshot) {
      if (snapshot.hasError) return const ListTile(title: Text('Unable to load features'));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      return Column(children: [for (final group in groups.entries)
        ExpansionTile(key: PageStorageKey(group.key), title: Text(group.value), children: [
          for (final feature in snapshot.data!.where((f) => f['group'] == group.key))
            ListTile(title: Text(feature['title']), leading: const Icon(Icons.eco_outlined),
              trailing: const Icon(Icons.chevron_right), onTap: () {
                final navigator = Navigator.of(context);
                if (navigator.canPop() || Scaffold.maybeOf(context)?.isDrawerOpen == true) navigator.pop();
                navigator.push(MaterialPageRoute(builder: (_) => EcosystemFeatureScreen(
                  appState: appState, feature: Map<String, dynamic>.from(feature))));
              }),
        ]),
      ]);
    },
  );
}

class EcosystemFeatureScreen extends StatefulWidget {
  final AppState appState;
  final Map<String, dynamic> feature;
  const EcosystemFeatureScreen({required this.appState, required this.feature});
  @override
  State<EcosystemFeatureScreen> createState() => _FeatureScreenState();
}

class _FeatureScreenState extends State<EcosystemFeatureScreen> {
  final _form = GlobalKey<FormState>();
  final _values = <String, String>{};
  final _controllers = <String, TextEditingController>{};
  @override
  void dispose() { for (final c in _controllers.values) { c.dispose(); } super.dispose(); }
  Future<void> _useGps() async {
    final position = await widget.appState.locationService.getCurrentLocation(forceRefresh: true);
    if (!mounted) return;
    if (position == null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.appState.locationService.error ?? 'GPS unavailable'))); return; }
    for (final field in widget.feature['fields'] as List) {
      final name = field['name'] as String;
      final value = ['lat','latitude','origin_lat'].contains(name) ? position.latitude : ['lon','lng','longitude','origin_lon'].contains(name) ? position.longitude : null;
      if (value != null) _controllers.putIfAbsent(name, () => TextEditingController()).text = value.toString();
    }
    setState(() {});
  }
  bool _busy = false;
  dynamic _result;
  String? _error;
  Future<void> _run() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (widget.feature['destructive'] == true) {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: Text(widget.feature['title']),
                  content:
                      const Text('This action changes account data. Continue?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Confirm'))
                  ]));
      if (confirmed != true) return;
    }
    _form.currentState?.save();
    final body = <String, dynamic>{};
    for (final field in widget.feature['fields'] as List) {
      final name = field['name'] as String;
      final text = (_values[name] ?? '').trim();
      if (text.isEmpty) continue;
      body[name] = switch (field['type']) {
        'number' => num.tryParse(text),
        'boolean' => text.toLowerCase() == 'true',
        'list' => text.split(',').map((s) => s.trim()).toList(),
        'object' => jsonDecode(text),
        _ => text
      };
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.appState.api
        .request('/internal/tools/${widget.feature['tool']}', data: body);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result;
      _error = result == null
          ? 'This action could not be completed. Check your sign-in, required information, connection and service availability.'
          : null;
    });
  }

  Widget _display(dynamic value) {
    if (value is List)
      return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: value
              .map<Widget>((v) => Card(
                  child: Padding(
                      padding: const EdgeInsets.all(12), child: _display(v))))
              .toList());
    if (value is Map)
      return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: value.entries
              .where((e) => !['password_hash', 'token'].contains(e.key))
              .map<Widget>((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.key.toString().replaceAll('_', ' '),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        _display(e.value)
                      ])))
              .toList());
    return SelectableText(value?.toString() ?? 'Unavailable');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: GrevideaAppBar(
          title: widget.feature['title'],
          subtitle: 'Grevidea ecosystem',
          showBack: true,
          appState: widget.appState),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
              key: _form,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((widget.feature['fields'] as List).any((f) => ['lat','latitude','origin_lat'].contains(f['name'])))
                      OutlinedButton.icon(onPressed: _useGps, icon: const Icon(Icons.my_location), label: const Text('Use my GPS location')),
                    for (final field in widget.feature['fields'] as List)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextFormField(
                              controller: _controllers.putIfAbsent(field['name'], () => TextEditingController()),
                              decoration:
                                  InputDecoration(labelText: field['label']),
                              obscureText: field['name'] == 'password',
                              keyboardType: field['type'] == 'number'
                                  ? const TextInputType.numberWithOptions(
                                      decimal: true)
                                  : TextInputType.text,
                              validator: (text) {
                                if (field['required'] == true &&
                                    (text ?? '').trim().isEmpty)
                                  return 'Required';
                                if (field['type'] == 'number' &&
                                    (text ?? '').isNotEmpty &&
                                    (num.tryParse(text!) == null || !num.parse(text).isFinite))
                                  return 'Enter a number';
                                if (field['type'] == 'object' && (text ?? '').isNotEmpty) {
                                  try { if (jsonDecode(text!) is! Map) return 'Enter a JSON object'; } catch (_) { return 'Enter a valid JSON object'; }
                                }
                                if (field['type'] == 'boolean' && (text ?? '').isNotEmpty && !['true','false'].contains(text!.toLowerCase())) return 'Enter true or false';
                                return null;
                              },
                              onSaved: (text) =>
                                  _values[field['name']] = text ?? '')),
                    FilledButton(
                        onPressed: _busy ? null : _run,
                        child: Text(_busy ? 'Working…' : 'Continue')),
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(_error!)),
                    if (_result != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: _display(_result)),
                  ]))));
}
