import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../settings/settings_controller.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _project;
  late final TextEditingController _user;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _project = TextEditingController(text: settings.project);
    _user = TextEditingController(text: settings.user);
  }

  @override
  void dispose() {
    _project.dispose();
    _user.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    await ref.read(settingsProvider.notifier).update(
          project: _project.text.trim(),
          user: _user.text.trim(),
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
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
          Text('Defaults', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'This deployment is hardcoded to dart-review.googlesource.com '
            '(Dart SDK Gerrit). Other Gerrit instances need their own '
            'deployments.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _project,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Default project',
              hintText: 'sdk',
              helperText:
                  'Gerrit project name. Examples: sdk, linter, dart_style, '
                  'tools.',
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
            '(Wasm). Anonymous endpoints, Dart SDK only.',
          ),
        ],
      ),
    );
  }
}
