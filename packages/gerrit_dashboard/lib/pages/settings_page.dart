import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../settings/settings_controller.dart';

/// Curated host/project presets surfaced as quick chips. This deployment
/// is Dart-SDK only; other Gerrit instances need their own deployments
/// (the same-origin CORS proxy on lab.modulovalue.com only forwards to
/// dart-review.googlesource.com).
const _presets = <_Preset>[
  _Preset(
    name: 'Dart SDK',
    project: 'sdk',
    host: 'dart-review.googlesource.com',
    description: 'github.com/dart-lang/sdk mirror',
  ),
];

class _Preset {
  final String name;
  final String host;
  final String project;
  final String description;
  const _Preset({
    required this.name,
    required this.host,
    required this.project,
    required this.description,
  });
}

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _scheme;
  late final TextEditingController _host;
  late final TextEditingController _webHost;
  late final TextEditingController _project;
  late final TextEditingController _user;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _scheme = TextEditingController(text: settings.scheme);
    _host = TextEditingController(text: settings.host);
    _webHost = TextEditingController(text: settings.webHost);
    _project = TextEditingController(text: settings.project);
    _user = TextEditingController(text: settings.user);
  }

  @override
  void dispose() {
    _scheme.dispose();
    _host.dispose();
    _webHost.dispose();
    _project.dispose();
    _user.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    await ref.read(settingsProvider.notifier).update(
          scheme: _scheme.text.trim(),
          host: _host.text.trim(),
          webHost: _webHost.text.trim(),
          project: _project.text.trim(),
          user: _user.text.trim(),
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  void _applyPreset(_Preset preset) {
    // Resets to the auto-detected defaults, same-origin proxy in web
    // release, localhost:8080 dev proxy in debug, direct upstream on
    // native. webHost stays as the real Gerrit so "Open in Gerrit"
    // links work.
    setState(() {
      _scheme.text = defaultScheme;
      _host.text = defaultHost;
      _webHost.text = preset.host;
      _project.text = preset.project;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          Text('Gerrit server', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Anonymous read-only Gerrit endpoint. '
            'In debug builds the default points at the local dev CORS proxy '
            '(http://localhost:8080); the proxy forwards to '
            'dart-review.googlesource.com.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _scheme,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Scheme',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _host,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Host',
                    hintText: 'localhost:8080',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _webHost,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Gerrit web UI host',
              hintText: 'dart-review.googlesource.com',
              helperText:
                  'Used by "Open in Gerrit" links. The upstream Gerrit '
                  'site, not the (possibly proxied) API endpoint above.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _project,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Default project',
              hintText: 'sdk',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _user,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Default user (for the Mine tab)',
              hintText: 'username or email',
              helperText:
                  'Used as `owner:<user>` in the Mine tab. '
                  'Leave blank to hide the Mine tab.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text('Presets', style: text.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in _presets)
                ActionChip(
                  label: Text(preset.name),
                  tooltip: '${preset.host} / ${preset.project}',
                  onPressed: () => _applyPreset(preset),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              icon: const Icon(Icons.save),
              onPressed: _apply,
              label: const Text('Save'),
            ),
          ),
          const Divider(height: 48),
          Text('Appearance', style: text.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (set) =>
                ref.read(settingsProvider.notifier).update(themeMode: set.first),
          ),
          const Divider(height: 48),
          Text('About', style: text.titleMedium),
          const SizedBox(height: 6),
          const Text(
            'gerrit-dashboard-v2, read-only Gerrit dashboard built in Flutter '
            '(Wasm). Anonymous endpoints only. To talk to *.googlesource.com '
            'hosts from a browser you need a CORS proxy; the bundled '
            '`dart run gerrit_dashboard:dev_proxy` does the job for local '
            'development.',
          ),
        ],
      ),
    );
  }
}
