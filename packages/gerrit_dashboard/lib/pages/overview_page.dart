import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gerrit_api/gerrit_api.dart';
import 'package:go_router/go_router.dart';
import 'package:web/web.dart' as web;

import '../settings/settings_controller.dart';
import '../widgets/change_row.dart';

class _Tab {
  final String label;
  final String? query;
  final bool isCustom;
  const _Tab.query(this.label, String this.query) : isCustom = false;
  const _Tab.custom(this.label)
      : query = null,
        isCustom = true;
}

/// Build the tab list. `statusClause` is what the filter chips produce
/// for the server query; when it is `null` (no status chips active),
/// the All / Mine tabs render an empty hint.
List<_Tab> _buildTabs(
  GerritSettings effective, {
  required bool scoped,
  required String? statusClause,
}) {
  final project = effective.project;
  final user = effective.user;

  String? composeQuery({required bool withOwner}) {
    if (statusClause == null) return null;
    final parts = <String>[statusClause, 'project:$project'];
    if (withOwner && user.isNotEmpty) parts.add('owner:$user');
    return parts.join(' ');
  }

  return [
    // Mine tab: only when there's a user and we're not already scoped
    // (a `/u/:user` URL already implies "mine for that user").
    if (!scoped && user.isNotEmpty)
      _Tab.query('Mine', composeQuery(withOwner: true) ?? ''),
    _Tab.query('All', composeQuery(withOwner: scoped) ?? ''),
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
  final ScopeOverride? scope;
  const OverviewPage({super.key, this.scope});

  @override
  ConsumerState<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends ConsumerState<OverviewPage>
    with TickerProviderStateMixin {
  TabController? _tabs;
  int _lastLength = 0;
  final _customCtrl = TextEditingController();
  String _customQuery = '';

  @override
  void dispose() {
    _tabs?.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  TabController _controllerFor(int length) {
    if (_tabs == null || _lastLength != length) {
      _tabs?.dispose();
      _tabs = TabController(length: length, vsync: this);
      _lastLength = length;
    }
    return _tabs!;
  }

  /// Absolute URL of the app's mount point (e.g.
  /// `https://lab.modulovalue.com/gerrit-dashboard-v2/`), independent of
  /// the current route.
  Uri _appBase() {
    if (kIsWeb) return Uri.parse(web.document.baseURI);
    return Uri.base;
  }

  Future<void> _share(GerritSettings effective) async {
    final base = _appBase();
    final path = base.path.endsWith('/') ? base.path : '${base.path}/';
    final url = base.replace(
      path: '${path}u/${Uri.encodeComponent(effective.user)}',
      queryParameters: {'project': effective.project},
    ).toString();
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied: $url')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final scope = widget.scope;
    final scoped = scope != null && !scope.isEmpty;
    final effective = scoped ? scope.applyTo(settings) : settings;

    final selectedFilters = ref.watch(filterProvider);
    final statusClause = buildStatusClause(selectedFilters);

    final tabs = _buildTabs(
      effective,
      scoped: scoped,
      statusClause: statusClause,
    );
    final controller = _controllerFor(tabs.length);
    final shareEnabled = effective.user.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Gerrit Dashboard'),
            Text(
              '${effective.webHost} • ${effective.project}'
              '${effective.user.isEmpty ? '' : ' • @${effective.user}'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: shareEnabled
                ? 'Copy shareable link'
                : 'Set a user to enable sharing',
            icon: const Icon(Icons.share),
            onPressed: shareEnabled ? () => _share(effective) : null,
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight((scoped ? 28 : 0) + 36 + 40),
          child: Column(
            children: [
              if (scoped) _ScopeBanner(effective: effective),
              SizedBox(
                height: 36,
                child: TabBar(
                  controller: controller,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(fontSize: 13),
                  dividerHeight: 0,
                  tabs: [
                    for (final t in tabs) Tab(height: 32, text: t.label),
                  ],
                ),
              ),
              const _FilterChipsRow(),
            ],
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
                initialProject: effective.project,
                onSubmit: (q) => setState(() => _customQuery = q),
                currentQuery: _customQuery,
                selected: selectedFilters,
              )
            else if (t.query!.isEmpty)
              const _NoStatusHint()
            else
              _QueryView(
                query: t.query!,
                effective: effective,
                selected: selectedFilters,
              ),
        ],
      ),
    );
  }
}

class _FilterChipsRow extends ConsumerWidget {
  const _FilterChipsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(filterProvider);
    final controller = ref.read(filterProvider.notifier);
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          for (final f in DashboardFilter.values) ...[
            _ChipTile(
              filter: f,
              selected: selected.contains(f),
              onTap: () {
                final hk = HardwareKeyboard.instance;
                final modifier = hk.isMetaPressed || hk.isControlPressed;
                if (modifier) {
                  controller.selectOnly(f);
                } else {
                  controller.toggle(f);
                }
              },
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _ChipTile extends StatelessWidget {
  final DashboardFilter filter;
  final bool selected;
  final VoidCallback onTap;
  const _ChipTile({
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Custom InkWell wrapping a chip-styled container, because
    // FilterChip's onSelected/onTap doesn't expose modifier state.
    // The visual is intentionally close to a Material FilterChip.
    final scheme = Theme.of(context).colorScheme;
    final bg = selected ? scheme.secondaryContainer : scheme.surface;
    final fg =
        selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;
    final border = selected ? scheme.secondary : scheme.outlineVariant;

    return Tooltip(
      message: selected
          ? 'Hide ${filter.label}  (Cmd+click: only this)'
          : 'Show ${filter.label}  (Cmd+click: only this)',
      child: Material(
        color: bg,
        shape: StadiumBorder(side: BorderSide(color: border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Icon(Icons.check, size: 14, color: fg),
                  const SizedBox(width: 4),
                ],
                Text(
                  filter.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: fg,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoStatusHint extends StatelessWidget {
  const _NoStatusHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_alt_off, size: 48),
            const SizedBox(height: 12),
            Text(
              'No status filters enabled.\nTurn on Open, Merged, or Abandoned above.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeBanner extends StatelessWidget {
  final GerritSettings effective;
  const _ScopeBanner({required this.effective});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      child: InkWell(
        onTap: () => context.go('/'),
        child: SizedBox(
          height: 28,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.person,
                    size: 16, color: scheme.onSecondaryContainer),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Viewing @${effective.user} on ${effective.project}',
                    style: TextStyle(
                      color: scheme.onSecondaryContainer,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Tooltip(
                  message: 'Clear scope',
                  child: Icon(Icons.close,
                      size: 16, color: scheme.onSecondaryContainer),
                ),
              ],
            ),
          ),
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
  final Set<DashboardFilter> selected;

  const _CustomQueryTab({
    required this.controller,
    required this.initialProject,
    required this.onSubmit,
    required this.currentQuery,
    required this.selected,
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
              : _QueryView(
                  query: currentQuery,
                  effective: null,
                  selected: selected,
                ),
        ),
      ],
    );
  }
}

class _QueryView extends ConsumerWidget {
  final String query;
  final GerritSettings? effective;
  final Set<DashboardFilter> selected;
  const _QueryView({
    required this.query,
    required this.effective,
    required this.selected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GerritSettings eff = effective ?? ref.watch(settingsProvider);
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
        final filtered = [
          for (final c in changes)
            if (passesAttributeFilters(c, selected)) c,
        ];
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(_queryResultsProvider(query));
          },
          child: filtered.isEmpty
              ? ListView(children: [
                  _EmptyHint(
                    message: '${changes.length} CL(s) hidden by filters.',
                  ),
                ])
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => ChangeRow(
                    change: filtered[i],
                    host: eff.host,
                    project: eff.project,
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
