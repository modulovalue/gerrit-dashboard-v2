import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../settings/settings_controller.dart';

const _repoUrl = 'https://github.com/modulovalue/gerrit-dashboard-v2';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _user;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _user = TextEditingController(text: settings.user);
  }

  @override
  void dispose() {
    _user.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    await ref.read(settingsProvider.notifier).update(
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
            'This deployment is hardcoded to dart-review.googlesource.com, '
            'sdk project. Other Gerrits or other projects need their own '
            'deployments.',
            style: text.bodySmall,
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
          Text('About', style: text.titleMedium),
          const SizedBox(height: 6),
          const Text(
            'gerrit-dashboard-v2, read-only Gerrit dashboard built in Flutter '
            '(Wasm). Anonymous endpoints, Dart SDK only.',
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: Alignment.centerLeft,
            ),
            icon: const Icon(Icons.code, size: 18),
            label: const Text(_repoUrl),
            onPressed: () => launchUrl(
              Uri.parse(_repoUrl),
              webOnlyWindowName: '_blank',
            ),
          ),
        ],
      ),
    );
  }
}
