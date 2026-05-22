import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gerrit_api/gerrit_api.dart';
import 'package:go_router/go_router.dart';

import '../settings/settings_controller.dart';
import '../widgets/change_row.dart';

class _Tab {
  final String label;
  final String? query;
  final bool isCustom;
  final bool isMineHint;
  const _Tab.query(this.label, String this.query)
      : isCustom = false,
        isMineHint = false;
  const _Tab.custom(this.label)
      : query = null,
        isCustom = true,
        isMineHint = false;
  const _Tab.mineHint(this.label)
      : query = null,
        isCustom = false,
        isMineHint = true;
}

List<_Tab> _buildTabs(GerritSettings settings) {
  final project = settings.project;
  final user = settings.user;
  return [
    if (user.isNotEmpty)
      _Tab.query('Mine', 'owner:$user project:$project')
    else
      const _Tab.mineHint('Mine'),
    _Tab.query('Open', 'status:open project:$project'),
    _Tab.query('Merged', 'status:merged project:$project'),
    _Tab.query('Abandoned', 'status:abandoned project:$project'),
    const _Tab.custom('Custom'),
  ];
}

final _queryResultsProvider =
    FutureProvider.family<List<ChangeInfo>, String>((ref, query) async {
  final client = ref.watch(gerritClientProvider);
  return client.queryChanges(
    query,
    options: const {
      ChangeOption.currentRevision,
      ChangeOption.detailedAccounts,
    },
    limit: 50,
  );
});

class OverviewPage extends ConsumerStatefulWidget {
  const OverviewPage({super.key});

  @override
  ConsumerState<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends ConsumerState<OverviewPage>
    with TickerProviderStateMixin {
  TabController? _tabs;
  int _lastLength = 0;
  final _customCtrl = TextEditingController();
  String _customQuery = '';

  TabController _controllerFor(int length) {
    if (_tabs == null || _lastLength != length) {
      _tabs?.dispose();
      _tabs = TabController(length: length, vsync: this);
      _lastLength = length;
    }
    return _tabs!;
  }

  @override
  void dispose() {
    _tabs?.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final tabs = _buildTabs(settings);
    final controller = _controllerFor(tabs.length);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Gerrit Dashboard'),
            Text(
              '${settings.webHost} • ${settings.project}'
              '${settings.user.isEmpty ? '' : ' • @${settings.user}'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: SizedBox(
            height: 36,
            child: TabBar(
              controller: controller,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorSize: TabBarIndicatorSize.label,
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              dividerHeight: 0,
              tabs: [
                for (final t in tabs)
                  Tab(height: 32, text: t.label),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: controller,
        children: [
          for (final t in tabs)
            if (t.isCustom)
              _CustomQueryTab(
                controller: _customCtrl,
                initialProject: settings.project,
                onSubmit: (q) => setState(() => _customQuery = q),
                currentQuery: _customQuery,
              )
            else if (t.isMineHint)
              const _MineHint()
            else
              _QueryView(query: t.query!),
        ],
      ),
    );
  }
}

class _MineHint extends StatelessWidget {
  const _MineHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              'Set a default user in Settings to enable the Mine tab.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
              onPressed: () => context.go('/settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomQueryTab extends StatelessWidget {
  final TextEditingController controller;
  final String initialProject;
  final void Function(String) onSubmit;
  final String currentQuery;

  const _CustomQueryTab({
    required this.controller,
    required this.initialProject,
    required this.onSubmit,
    required this.currentQuery,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Gerrit search',
                    hintText:
                        'owner:alice status:open project:$initialProject',
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: onSubmit,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => onSubmit(controller.text.trim()),
                child: const Text('Search'),
              ),
            ],
          ),
        ),
        Expanded(
          child: currentQuery.isEmpty
              ? const _EmptyHint(
                  message:
                      'Type a Gerrit query above (e.g. `owner:alice status:open`).',
                )
              : _QueryView(query: currentQuery),
        ),
      ],
    );
  }
}

class _QueryView extends ConsumerWidget {
  final String query;
  const _QueryView({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final async = ref.watch(_queryResultsProvider(query));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => _ErrorPanel(
        query: query,
        error: e,
        onRetry: () => ref.invalidate(_queryResultsProvider(query)),
      ),
      data: (changes) {
        if (changes.isEmpty) {
          return _EmptyHint(message: 'No CLs found for `$query`.');
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(_queryResultsProvider(query));
          },
          child: ListView.separated(
            itemCount: changes.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => ChangeRow(
              change: changes[i],
              host: settings.host,
              project: settings.project,
            ),
          ),
        );
      },
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String message;
  const _EmptyHint({required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
}

class _ErrorPanel extends StatelessWidget {
  final String query;
  final Object error;
  final VoidCallback onRetry;

  const _ErrorPanel({
    required this.query,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: scheme.error),
            const SizedBox(height: 12),
            SelectableText(
              'Failed to query Gerrit',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SelectableText(
              error.toString(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SelectableText('Query: $query'),
            const SizedBox(height: 16),
            Text(
              'If you see a CORS error in the browser console, '
              "you'll need a same-origin reverse proxy. See README.md.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
