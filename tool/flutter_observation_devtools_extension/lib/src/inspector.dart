import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import 'models.dart';
import 'service_client.dart';

class ObservationInspector extends StatefulWidget {
  const ObservationInspector({super.key, this.client});

  final ObservationServiceClient? client;

  @override
  State<ObservationInspector> createState() => _ObservationInspectorState();
}

class _ObservationInspectorState extends State<ObservationInspector>
    with SingleTickerProviderStateMixin {
  static const _supportedProtocolVersion = 2;

  late final ObservationServiceClient _client;
  late final TabController _tabController;
  final List<ObservationEventRecord> _events = [];
  final TextEditingController _queryController = TextEditingController();
  Timer? _timer;
  Timer? _navigationTimer;
  ObservationSnapshot? _snapshot;
  _InspectorNavigation? _navigation;
  String _query = '';
  String? _error;
  int _afterSequence = 0;
  bool _loading = true;
  bool _refreshing = false;
  bool _recording = true;
  bool _includeAccessEvents = false;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? createVmObservationServiceClient();
    _tabController = TabController(length: 4, vsync: this);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await _client.setValueInspection(enabled: true);
      final value = await _client.setRecording(enabled: true);
      _snapshot = _decodeSnapshot(value);
      await _refresh();
      _timer = Timer.periodic(
        const Duration(milliseconds: 700),
        (_) => unawaited(_refresh()),
      );
    } catch (error) {
      _setError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final responses = await Future.wait([
        _client.getSnapshot(),
        _client.getEvents(afterSequence: _afterSequence),
      ]);
      final snapshot = _decodeSnapshot(responses[0]);
      final eventValues = responses[1]['events'];
      final newEvents = eventValues is List
          ? eventValues
                .whereType<Map>()
                .map(
                  (event) => ObservationEventRecord.fromJson(
                    event.map((key, value) => MapEntry('$key', value)),
                  ),
                )
                .toList(growable: false)
          : const <ObservationEventRecord>[];
      if (newEvents.isNotEmpty) {
        _afterSequence = newEvents.last.sequence;
        _events.addAll(newEvents);
        if (_events.length > snapshot.capacity) {
          _events.removeRange(0, _events.length - snapshot.capacity);
        }
      }
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _recording = snapshot.recording;
        _includeAccessEvents = snapshot.includeAccessEvents;
        _error = null;
      });
    } catch (error) {
      _setError(error);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _setRecording(bool enabled) async {
    try {
      final value = await _client.setRecording(
        enabled: enabled,
        includeAccessEvents: _includeAccessEvents,
      );
      final snapshot = _decodeSnapshot(value);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _recording = enabled;
        _error = null;
      });
    } catch (error) {
      _setError(error);
    }
  }

  Future<void> _setIncludeAccessEvents(bool enabled) async {
    _includeAccessEvents = enabled;
    if (!_recording) {
      setState(() {});
      return;
    }
    await _setRecording(true);
  }

  Future<void> _clearEvents() async {
    try {
      await _client.clearEvents();
      if (!mounted) return;
      setState(() {
        _events.clear();
        _error = null;
      });
    } catch (error) {
      _setError(error);
    }
  }

  void _setError(Object error) {
    if (!mounted) return;
    setState(() {
      _error = '$error';
      _loading = false;
    });
  }

  ObservationSnapshot _decodeSnapshot(Map<String, Object?> value) {
    final snapshot = ObservationSnapshot.fromJson(value);
    if (snapshot.protocolVersion != _supportedProtocolVersion) {
      throw StateError(
        'Unsupported Observation protocol ${snapshot.protocolVersion}; '
        'expected $_supportedProtocolVersion.',
      );
    }
    return snapshot;
  }

  void _showSource(int sourceId) {
    _navigate(_InspectorNavigation(tabIndex: 1, sourceId: sourceId));
  }

  void _showProperty(int sourceId, int propertyId) {
    _navigate(
      _InspectorNavigation(
        tabIndex: 2,
        sourceId: sourceId,
        propertyId: propertyId,
      ),
    );
  }

  Future<void> _inspectObserver(ObservationObserverSnapshot observer) async {
    try {
      final selected = await _client.showInFlutterInspector(
        observerId: observer.id,
      );
      if (!selected) {
        throw StateError('${observer.label} is no longer mounted.');
      }
    } catch (error) {
      _setError(error);
    }
  }

  void _navigate(_InspectorNavigation navigation) {
    _navigationTimer?.cancel();
    setState(() => _navigation = navigation);
    _tabController.animateTo(navigation.tabIndex);
    _navigationTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted && identical(_navigation, navigation)) {
        setState(() => _navigation = null);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _navigationTimer?.cancel();
    _tabController.dispose();
    _queryController.dispose();
    unawaited(_stopDebugging());
    super.dispose();
  }

  Future<void> _stopDebugging() async {
    try {
      await Future.wait([
        _client.setRecording(enabled: false),
        _client.setValueInspection(enabled: false),
      ]);
    } catch (_) {
      // The VM service may already be disconnected while the tab is closing.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _InspectorToolbar(
            recording: _recording,
            hasEvents: _events.isNotEmpty,
            onRecordingChanged: _setRecording,
            onRefresh: _refresh,
            onClearEvents: _clearEvents,
          ),
          _InspectorTabs(controller: _tabController),
          if (_error case final error?) _ErrorBanner(message: error),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _Overview(snapshot: _snapshot, events: _events),
                _StateValues(
                  snapshot: _snapshot,
                  navigation: _navigation,
                  onOpenSource: _showSource,
                ),
                _Dependencies(
                  snapshot: _snapshot,
                  navigation: _navigation,
                  onOpenSource: _showSource,
                  onInspectObserver: _inspectObserver,
                ),
                _Events(
                  events: _events,
                  queryController: _queryController,
                  query: _query,
                  includeAccessEvents: _includeAccessEvents,
                  onQueryChanged: (value) => setState(() => _query = value),
                  onIncludeAccessEventsChanged: _setIncludeAccessEvents,
                  onOpenSource: _showSource,
                  onOpenProperty: _showProperty,
                  onInspectObserver: _inspectObserver,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _InspectorNavigation {
  const _InspectorNavigation({
    required this.tabIndex,
    this.sourceId,
    this.propertyId,
  });

  final int tabIndex;
  final int? sourceId;
  final int? propertyId;
}

class _InspectorToolbar extends StatelessWidget {
  const _InspectorToolbar({
    required this.recording,
    required this.hasEvents,
    required this.onRecordingChanged,
    required this.onRefresh,
    required this.onClearEvents,
  });

  final bool recording;
  final bool hasEvents;
  final ValueChanged<bool> onRecordingChanged;
  final VoidCallback onRefresh;
  final VoidCallback onClearEvents;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: defaultToolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: denseSpacing),
      decoration: BoxDecoration(
        border: Border(bottom: defaultBorderSide(Theme.of(context))),
      ),
      child: Row(
        children: [
          Text(
            'Flutter Observation',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const Spacer(),
          DevToolsToggleButton(
            message: recording ? 'Stop recording' : 'Start recording',
            label: 'Recording',
            icon: Icons.fiber_manual_record,
            isSelected: recording,
            outlined: false,
            onPressed: () => onRecordingChanged(!recording),
          ),
          const SizedBox(width: densePadding),
          DevToolsButton.iconOnly(
            icon: Icons.refresh,
            tooltip: 'Refresh',
            outlined: false,
            onPressed: onRefresh,
          ),
          DevToolsButton.iconOnly(
            icon: Icons.delete_sweep_outlined,
            tooltip: 'Clear events',
            outlined: false,
            onPressed: hasEvents ? onClearEvents : null,
          ),
        ],
      ),
    );
  }
}

class _InspectorTabs extends StatelessWidget {
  const _InspectorTabs({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tabLabelStyle = theme.regularTextStyle.copyWith(
      fontSize: defaultFontSize,
      fontWeight: FontWeight.w400,
    );
    return Container(
      height: defaultToolbarHeight,
      decoration: BoxDecoration(
        border: Border(bottom: defaultBorderSide(theme)),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        // Flutter merges selected and unselected labels with different
        // Material defaults. Supplying both keeps tab geometry stable.
        labelStyle: tabLabelStyle,
        unselectedLabelStyle: tabLabelStyle,
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'State'),
          Tab(text: 'Dependencies'),
          Tab(text: 'Events'),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.snapshot, required this.events});

  final ObservationSnapshot? snapshot;
  final List<ObservationEventRecord> events;

  @override
  Widget build(BuildContext context) {
    final snapshot = this.snapshot;
    if (snapshot == null) {
      return const _EmptyState(
        icon: Icons.cable_outlined,
        title: 'Waiting for the application',
        message: 'Connect DevTools to a running flutter_observation app.',
      );
    }
    final notificationCount = events
        .where((event) => event.kind == 'notify')
        .length;
    final invalidationCount = events
        .where((event) => event.kind == 'invalidate')
        .length;
    final rebuildCount = events
        .where((event) => event.kind == 'rebuildStart')
        .length;
    final hotProperties = <String, int>{};
    for (final event in events.where((event) => event.kind == 'notify')) {
      final key =
          '${event.sourceType ?? 'Observable'} · ${event.property ?? '—'}';
      hotProperties.update(key, (value) => value + 1, ifAbsent: () => 1);
    }
    final sortedHotProperties = hotProperties.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(defaultSpacing),
      children: [
        Wrap(
          spacing: denseSpacing,
          runSpacing: denseSpacing,
          children: [
            _MetricCard(
              label: 'Observable sources',
              value: '${snapshot.sources.length}',
              icon: Icons.data_object,
            ),
            _MetricCard(
              label: 'Observed properties',
              value: '${snapshot.propertyCount}',
              icon: Icons.visibility_outlined,
            ),
            _MetricCard(
              label: 'Observers',
              value: '${snapshot.observerCount}',
              icon: Icons.widgets_outlined,
            ),
            _MetricCard(
              label: 'Notifications',
              value: '$notificationCount',
              icon: Icons.notifications_none,
            ),
            _MetricCard(
              label: 'Invalidations',
              value: '$invalidationCount',
              icon: Icons.bolt_outlined,
            ),
            _MetricCard(
              label: 'Rebuilds',
              value: '$rebuildCount',
              icon: Icons.refresh_outlined,
            ),
          ],
        ),
        const SizedBox(height: defaultSpacing),
        RoundedOutlinedBorder(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SectionHeader(title: 'Hot properties'),
              if (sortedHotProperties.isEmpty)
                const _EmptyRow(
                  message: 'No property notifications have been recorded yet.',
                )
              else
                for (final entry in sortedHotProperties.take(10))
                  _KeyValueRow(label: entry.key, value: '${entry.value}'),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 164,
      height: 58,
      child: RoundedOutlinedBorder(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: denseSpacing,
            vertical: densePadding,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: actionsIconSize,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: denseSpacing),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: theme.textTheme.titleMedium),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: defaultHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: defaultSpacing),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(bottom: defaultBorderSide(theme)),
      ),
      child: Text(title, style: theme.textTheme.titleSmall),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: defaultRowHeight + denseSpacing,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: defaultSpacing),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(message, style: Theme.of(context).textTheme.bodySmall),
        ),
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: defaultRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: defaultSpacing),
      decoration: BoxDecoration(
        border: Border(top: defaultBorderSide(Theme.of(context))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: denseSpacing),
          Text(value),
        ],
      ),
    );
  }
}

class _SourcePanel extends StatelessWidget {
  const _SourcePanel({
    super.key,
    required this.highlighted,
    required this.child,
  });

  final bool highlighted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: highlighted
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
            : theme.colorScheme.surface,
        border: Border.all(
          color: highlighted ? theme.colorScheme.primary : theme.focusColor,
        ),
        borderRadius: defaultBorderRadius,
      ),
      child: child,
    );
  }
}

class _StateValues extends StatefulWidget {
  const _StateValues({
    required this.snapshot,
    required this.navigation,
    required this.onOpenSource,
  });

  final ObservationSnapshot? snapshot;
  final _InspectorNavigation? navigation;
  final ValueChanged<int> onOpenSource;

  @override
  State<_StateValues> createState() => _StateValuesState();
}

class _StateValuesState extends State<_StateValues> {
  final Map<int, GlobalKey> _sourceKeys = {};
  final Map<int, ExpansibleController> _sourceControllers = {};

  GlobalKey _sourceKey(int id) => _sourceKeys.putIfAbsent(id, GlobalKey.new);

  ExpansibleController _sourceController(int id) {
    return _sourceControllers.putIfAbsent(id, ExpansibleController.new);
  }

  @override
  void dispose() {
    for (final controller in _sourceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(_StateValues oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.navigation, oldWidget.navigation)) {
      _revealNavigation();
    }
  }

  void _revealNavigation() {
    final navigation = widget.navigation;
    final sourceId = navigation?.tabIndex == 1 ? navigation?.sourceId : null;
    if (sourceId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetContext = _sourceKey(sourceId).currentContext;
      if (targetContext == null) return;
      _sourceController(sourceId).expand();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final revealedContext = _sourceKey(sourceId).currentContext;
        if (revealedContext != null) {
          Scrollable.ensureVisible(
            revealedContext,
            alignment: 0.08,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    if (snapshot == null) {
      return const _EmptyState(
        icon: Icons.cable_outlined,
        title: 'Waiting for the application',
        message: 'Connect DevTools to a running flutter_observation app.',
      );
    }
    final sources = snapshot.sources
        .where((source) => source.properties.isNotEmpty)
        .toList(growable: false);
    if (sources.isEmpty) {
      return const _EmptyState(
        icon: Icons.data_object,
        title: 'No inspectable state',
        message: 'Generated models and built-in Observable values appear here.',
      );
    }
    final knownSourceIds = sources.map((source) => source.id).toSet();
    final navigation = widget.navigation;
    VoidCallback? openReference(ObservationPropertySnapshot property) {
      final referenceId = property.value?.referenceId;
      if (referenceId == null || !knownSourceIds.contains(referenceId)) {
        return null;
      }
      return () => widget.onOpenSource(referenceId);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(defaultSpacing),
      child: Column(
        children: [
          for (var index = 0; index < sources.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: denseSpacing),
              child: _SourcePanel(
                key: _sourceKey(sources[index].id),
                highlighted:
                    navigation?.tabIndex == 1 &&
                    navigation?.sourceId == sources[index].id,
                child: ExpansionTile(
                  controller: _sourceController(sources[index].id),
                  initiallyExpanded: index == 0,
                  dense: true,
                  minTileHeight: defaultToolbarHeight,
                  visualDensity: VisualDensity.compact,
                  shape: const Border(),
                  collapsedShape: const Border(),
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: defaultSpacing,
                  ),
                  childrenPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.data_object, size: defaultIconSize),
                  title: Text(
                    '${sources[index].type} #${sources[index].id}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  subtitle: Text(
                    '${sources[index].properties.length} state properties',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  children: [
                    for (final property in sources[index].properties)
                      _StatePropertyRow(
                        property: property,
                        onOpenSource: openReference(property),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatePropertyRow extends StatelessWidget {
  const _StatePropertyRow({required this.property, this.onOpenSource});

  final ObservationPropertySnapshot property;
  final VoidCallback? onOpenSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = property.value;
    final valueText = value?.display ?? '<unavailable>';
    return Container(
      constraints: const BoxConstraints(minHeight: defaultToolbarHeight),
      padding: const EdgeInsets.symmetric(
        horizontal: defaultSpacing,
        vertical: densePadding,
      ),
      decoration: BoxDecoration(border: Border(top: defaultBorderSide(theme))),
      child: Row(
        children: [
          SizedBox(
            width: 220,
            child: Text(
              property.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: denseSpacing),
          Expanded(
            child: Tooltip(
              message: valueText,
              child: onOpenSource == null
                  ? Text(
                      valueText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.fixedFontStyle,
                    )
                  : _InlineLink(
                      label: valueText,
                      onTap: onOpenSource!,
                      style: theme.fixedFontStyle,
                    ),
            ),
          ),
          const SizedBox(width: defaultSpacing),
          SizedBox(
            width: 150,
            child: Text(
              value?.type ?? 'Unknown',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineLink extends StatelessWidget {
  const _InlineLink({required this.label, required this.onTap, this.style});

  final String label;
  final VoidCallback onTap;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      link: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (style ?? theme.textTheme.bodySmall)?.copyWith(
              color: theme.colorScheme.primary,
              decoration: TextDecoration.underline,
              decorationColor: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Dependencies extends StatefulWidget {
  const _Dependencies({
    required this.snapshot,
    required this.navigation,
    required this.onOpenSource,
    required this.onInspectObserver,
  });

  final ObservationSnapshot? snapshot;
  final _InspectorNavigation? navigation;
  final ValueChanged<int> onOpenSource;
  final ValueChanged<ObservationObserverSnapshot> onInspectObserver;

  @override
  State<_Dependencies> createState() => _DependenciesState();
}

class _DependenciesState extends State<_Dependencies> {
  final Map<int, GlobalKey> _sourceKeys = {};
  final Map<int, GlobalKey> _propertyKeys = {};
  final Map<int, ExpansibleController> _sourceControllers = {};

  GlobalKey _sourceKey(int id) => _sourceKeys.putIfAbsent(id, GlobalKey.new);

  GlobalKey _propertyKey(int id) =>
      _propertyKeys.putIfAbsent(id, GlobalKey.new);

  ExpansibleController _sourceController(int id) {
    return _sourceControllers.putIfAbsent(id, ExpansibleController.new);
  }

  @override
  void dispose() {
    for (final controller in _sourceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(_Dependencies oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.navigation, oldWidget.navigation)) {
      _revealNavigation();
    }
  }

  ObservationSourceSnapshot? _targetSource(
    List<ObservationSourceSnapshot> sources,
    _InspectorNavigation navigation,
  ) {
    for (final source in sources) {
      if (navigation.sourceId == source.id) return source;
      for (final property in source.properties) {
        if (navigation.propertyId == property.id) {
          return source;
        }
      }
    }
    return null;
  }

  ObservationPropertySnapshot? _targetProperty(
    ObservationSourceSnapshot source,
    _InspectorNavigation navigation,
  ) {
    for (final property in source.properties) {
      if (navigation.propertyId == property.id) {
        return property;
      }
    }
    return null;
  }

  void _revealNavigation() {
    final navigation = widget.navigation;
    if (navigation == null || navigation.tabIndex != 2) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sources = widget.snapshot?.sources ?? const [];
      final source = _targetSource(sources, navigation);
      if (source == null) return;
      final sourceContext = _sourceKey(source.id).currentContext;
      if (sourceContext == null) return;
      _sourceController(source.id).expand();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final property = _targetProperty(source, navigation);
        final targetContext = property == null
            ? _sourceKey(source.id).currentContext
            : _propertyKey(property.id).currentContext;
        if (targetContext != null) {
          Scrollable.ensureVisible(
            targetContext,
            alignment: 0.12,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final sources =
        widget.snapshot?.sources ?? const <ObservationSourceSnapshot>[];
    final observedSources = sources
        .where(
          (source) => source.properties.any((property) => property.isObserved),
        )
        .toList(growable: false);
    if (observedSources.isEmpty) {
      return const _EmptyState(
        icon: Icons.account_tree_outlined,
        title: 'No active dependencies',
        message:
            'Read an Observable property from an Observation Widget or subscription.',
      );
    }
    final navigation = widget.navigation;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(defaultSpacing),
      child: Column(
        children: [
          for (var index = 0; index < observedSources.length; index++)
            Builder(
              builder: (context) {
                final source = observedSources[index];
                final properties = source.properties
                    .where((property) => property.isObserved)
                    .toList(growable: false);
                final targetSource = navigation?.tabIndex == 2
                    ? _targetSource(observedSources, navigation!)
                    : null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: denseSpacing),
                  child: _SourcePanel(
                    key: _sourceKey(source.id),
                    highlighted: targetSource?.id == source.id,
                    child: ExpansionTile(
                      controller: _sourceController(source.id),
                      initiallyExpanded: index == 0,
                      dense: true,
                      minTileHeight: defaultToolbarHeight,
                      visualDensity: VisualDensity.compact,
                      shape: const Border(),
                      collapsedShape: const Border(),
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: defaultSpacing,
                      ),
                      childrenPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.data_object,
                        size: defaultIconSize,
                      ),
                      title: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              source.type,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          const SizedBox(width: densePadding),
                          _InlineLink(
                            label: '#${source.id}',
                            onTap: () => widget.onOpenSource(source.id),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                      subtitle: Text(
                        '${properties.length} observed properties',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      children: [
                        for (final property in properties)
                          _DependencyRow(
                            key: _propertyKey(property.id),
                            property: property,
                            highlighted:
                                navigation?.tabIndex == 2 &&
                                navigation?.propertyId == property.id,
                            onInspectObserver: widget.onInspectObserver,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _DependencyRow extends StatelessWidget {
  const _DependencyRow({
    super.key,
    required this.property,
    required this.highlighted,
    required this.onInspectObserver,
  });

  final ObservationPropertySnapshot property;
  final bool highlighted;
  final ValueChanged<ObservationObserverSnapshot> onInspectObserver;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      constraints: const BoxConstraints(minHeight: defaultToolbarHeight),
      padding: const EdgeInsets.symmetric(
        horizontal: defaultSpacing,
        vertical: densePadding,
      ),
      decoration: BoxDecoration(
        color: highlighted
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
            : null,
        border: Border(top: defaultBorderSide(theme)),
      ),
      child: Row(
        children: [
          const Icon(Icons.subdirectory_arrow_right, size: defaultIconSize),
          const SizedBox(width: denseSpacing),
          SizedBox(
            width: 180,
            child: Text(
              property.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: denseSpacing),
          Expanded(
            child: property.observers.isEmpty
                ? Text('No observers', style: theme.textTheme.bodySmall)
                : Wrap(
                    spacing: densePadding,
                    runSpacing: densePadding,
                    children: [
                      for (final observer in property.observers)
                        _ObserverLabel(
                          observer: observer,
                          onTap: observer.canInspect
                              ? () => onInspectObserver(observer)
                              : null,
                        ),
                    ],
                  ),
          ),
          const SizedBox(width: denseSpacing),
          Text('${property.observers.length}'),
        ],
      ),
    );
  }
}

class _ObserverLabel extends StatelessWidget {
  const _ObserverLabel({required this.observer, this.onTap});

  final ObservationObserverSnapshot observer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: onTap == null
          ? '${observer.label} is no longer mounted'
          : 'Show ${observer.label} in Flutter Inspector',
      child: MouseRegion(
        cursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: statusLineHeight),
            padding: const EdgeInsets.symmetric(
              horizontal: denseRowSpacing,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              border: Border.all(color: Colors.transparent),
              borderRadius: BorderRadius.circular(statusLineHeight / 2),
            ),
            child: Text(
              '${observer.label} #${observer.id}'
              '${observer.stateLabel == null ? '' : ' · ${observer.stateLabel}'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: onTap == null ? null : theme.colorScheme.primary,
                decoration: onTap == null ? null : TextDecoration.underline,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Events extends StatelessWidget {
  const _Events({
    required this.events,
    required this.queryController,
    required this.query,
    required this.includeAccessEvents,
    required this.onQueryChanged,
    required this.onIncludeAccessEventsChanged,
    required this.onOpenSource,
    required this.onOpenProperty,
    required this.onInspectObserver,
  });

  final List<ObservationEventRecord> events;
  final TextEditingController queryController;
  final String query;
  final bool includeAccessEvents;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<bool> onIncludeAccessEventsChanged;
  final ValueChanged<int> onOpenSource;
  final void Function(int sourceId, int propertyId) onOpenProperty;
  final ValueChanged<ObservationObserverSnapshot> onInspectObserver;

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final filtered = events
        .where(
          (event) =>
              normalizedQuery.isEmpty ||
              event.searchableText.contains(normalizedQuery),
        )
        .toList(growable: false)
        .reversed
        .toList(growable: false);
    return Column(
      children: [
        Container(
          height: defaultToolbarHeight + 2 * densePadding,
          padding: const EdgeInsets.symmetric(
            horizontal: denseSpacing,
            vertical: densePadding,
          ),
          decoration: BoxDecoration(
            border: Border(bottom: defaultBorderSide(Theme.of(context))),
          ),
          child: Row(
            children: [
              Expanded(
                child: DevToolsTextField(
                  controller: queryController,
                  onChanged: onQueryChanged,
                  prefixIcon: const Icon(Icons.search, size: defaultIconSize),
                  hintText: 'Filter events',
                  roundedBorder: true,
                ),
              ),
              const SizedBox(width: denseSpacing),
              DevToolsToggleButton(
                message: 'Include property reads',
                label: 'Property reads',
                icon: Icons.read_more,
                isSelected: includeAccessEvents,
                onPressed: () =>
                    onIncludeAccessEventsChanged(!includeAccessEvents),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const _EmptyState(
                  icon: Icons.timeline_outlined,
                  title: 'No matching events',
                  message: 'Interact with the app or change the filter.',
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return _EventTile(
                      event: filtered[index],
                      onOpenSource: onOpenSource,
                      onOpenProperty: onOpenProperty,
                      onInspectObserver: onInspectObserver,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.onOpenSource,
    required this.onOpenProperty,
    required this.onInspectObserver,
  });

  final ObservationEventRecord event;
  final ValueChanged<int> onOpenSource;
  final void Function(int sourceId, int propertyId) onOpenProperty;
  final ValueChanged<ObservationObserverSnapshot> onInspectObserver;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = <Widget>[];
    void addSeparator() {
      if (details.isNotEmpty) {
        details.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: densePadding),
            child: Text('→'),
          ),
        );
      }
    }

    if (event.sourceType != null && event.sourceId != null) {
      details.add(
        _InlineLink(
          label: '${event.sourceType} #${event.sourceId}',
          onTap: () => onOpenSource(event.sourceId!),
        ),
      );
    }
    if (event.property != null) {
      addSeparator();
      if (event.sourceId != null && event.propertyId != null) {
        details.add(
          _InlineLink(
            label: event.property!,
            onTap: () => onOpenProperty(event.sourceId!, event.propertyId!),
          ),
        );
      } else {
        details.add(Text(event.property!, style: theme.textTheme.bodySmall));
      }
    }
    if (event.observer != null && event.observerId != null) {
      addSeparator();
      details.add(
        _InlineLink(
          label: '${event.observer} #${event.observerId}',
          onTap: () => onInspectObserver(
            ObservationObserverSnapshot(
              id: event.observerId!,
              label: event.observer!,
              canInspect: true,
            ),
          ),
        ),
      );
    }
    return Container(
      height: defaultRowHeight + denseSpacing,
      padding: const EdgeInsets.symmetric(horizontal: defaultSpacing),
      decoration: BoxDecoration(
        border: Border(bottom: defaultBorderSide(theme)),
      ),
      child: Row(
        children: [
          Icon(
            _eventIcon(event.kind),
            size: defaultIconSize,
            color: _eventColor(context, event.kind),
          ),
          const SizedBox(width: denseSpacing),
          SizedBox(width: 116, child: Text(event.kind)),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: details.isEmpty
                  ? Text('—', style: theme.textTheme.bodySmall)
                  : Row(mainAxisSize: MainAxisSize.min, children: details),
            ),
          ),
          const SizedBox(width: denseSpacing),
          Text(_formatTime(event.timestamp), style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: denseSpacing,
        vertical: densePadding,
      ),
      color: colors.errorContainer,
      child: Row(
        children: [
          Icon(Icons.error_outline, size: defaultIconSize, color: colors.error),
          const SizedBox(width: denseSpacing),
          Expanded(
            child: Text(
              'Could not connect to the Observation runtime. Ensure the app '
              'uses flutter_observation 0.2.0-dev.2 or newer. $message',
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(defaultSpacing),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: mediumProgressSize),
            const SizedBox(height: denseSpacing),
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: densePadding),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

IconData _eventIcon(String kind) => switch (kind) {
  'notify' => Icons.notifications_none,
  'invalidate' => Icons.bolt_outlined,
  'dependencyAdded' => Icons.add_link,
  'dependencyRemoved' => Icons.link_off,
  'rebuildStart' || 'rebuildEnd' => Icons.refresh_outlined,
  'transactionStart' || 'transactionEnd' => Icons.swap_horiz,
  'observationStart' || 'observationEnd' => Icons.visibility_outlined,
  'access' => Icons.read_more,
  _ => Icons.circle_outlined,
};

Color _eventColor(BuildContext context, String kind) {
  final colors = Theme.of(context).colorScheme;
  return switch (kind) {
    'notify' => colors.tertiary,
    'invalidate' => colors.error,
    'dependencyAdded' => colors.primary,
    'dependencyRemoved' => colors.outline,
    _ => colors.secondary,
  };
}

String _formatTime(DateTime value) {
  String two(int value) => value.toString().padLeft(2, '0');
  String three(int value) => value.toString().padLeft(3, '0');
  return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}.'
      '${three(value.millisecond)}';
}
