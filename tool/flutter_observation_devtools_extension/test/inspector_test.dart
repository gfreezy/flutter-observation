import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_observation_devtools_extension/src/inspector.dart';
import 'package:flutter_observation_devtools_extension/src/models.dart';
import 'package:flutter_observation_devtools_extension/src/service_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cleans generated ObservationKey labels', () {
    expect(
      cleanObservationLabel('ObservationKey<String>(User.name)'),
      'User.name',
    );
    expect(cleanObservationLabel('custom'), 'custom');
  });

  testWidgets('shows overview, dependencies, and runtime events', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = _FakeObservationServiceClient();

    await tester.pumpWidget(
      MaterialApp(home: ObservationInspector(client: client)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('Observable sources'), findsOneWidget);
    expect(find.text('Observed properties'), findsOneWidget);
    expect(find.text('Hot properties'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('Values'), findsNothing);
    expect(
      tester.getSize(find.byType(TabBar)).height,
      closeTo(defaultToolbarHeight, 1),
    );
    expect(
      tester.getSize(find.byType(DevToolsToggleButton).first).height,
      defaultButtonHeight,
    );
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.labelStyle?.fontSize, defaultFontSize);
    expect(tabBar.labelStyle?.fontWeight, FontWeight.w400);
    expect(tabBar.unselectedLabelStyle, tabBar.labelStyle);
    final tabSizes = {
      for (final label in ['Overview', 'State', 'Dependencies', 'Events'])
        label: tester.getSize(find.widgetWithText(Tab, label)),
    };

    await tester.tap(find.text('State'));
    await tester.pumpAndSettle();
    for (final entry in tabSizes.entries) {
      expect(tester.getSize(find.widgetWithText(Tab, entry.key)), entry.value);
    }
    expect(find.text('User.name'), findsOneWidget);
    expect(find.text('"Alice"'), findsOneWidget);
    expect(find.text('Values'), findsNothing);
    await tester.tap(find.text('Address #5').first);
    await tester.pumpAndSettle();
    expect(find.text('Address.city'), findsOneWidget);
    for (final tile in tester.widgetList<ExpansionTile>(
      find.byType(ExpansionTile),
    )) {
      expect(tile.shape, const Border());
      expect(tile.collapsedShape, const Border());
    }

    await tester.tap(find.text('Dependencies'));
    await tester.pumpAndSettle();
    expect(find.text('User'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('User.name'), findsOneWidget);
    expect(find.textContaining('UserPage #4 · _UserPageState'), findsOneWidget);
    await tester.tap(find.textContaining('UserPage #4 · _UserPageState'));
    await tester.pump();
    expect(client.inspectedObserverId, 4);

    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();
    expect(find.text('notify'), findsOneWidget);
    expect(find.textContaining('User.name'), findsOneWidget);
    await tester.tap(find.text('User.name'));
    await tester.pumpAndSettle();
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller?.index, 2);
  });
}

final class _FakeObservationServiceClient implements ObservationServiceClient {
  bool recording = false;
  bool includeAccessEvents = false;
  bool valueInspectionEnabled = false;
  bool _sentEvents = false;
  int? inspectedObserverId;

  Map<String, Object?> get _snapshot => {
    'protocolVersion': 2,
    'recording': recording,
    'includeAccessEvents': includeAccessEvents,
    'valueInspectionEnabled': valueInspectionEnabled,
    'capacity': 2000,
    'latestSequence': 1,
    'sources': [
      {
        'id': 1,
        'registrarId': 2,
        'type': 'User',
        'propertyCount': 1,
        'observerCount': 1,
        'properties': [
          {
            'id': 3,
            'label': 'ObservationKey<String>(User.name)',
            'observerCount': 1,
            'observers': [
              {
                'id': 4,
                'label': 'UserPage',
                'stateLabel': '_UserPageState',
                'canInspect': true,
              },
            ],
            if (valueInspectionEnabled)
              'value': {
                'kind': 'string',
                'type': 'String',
                'display': '"Alice"',
              },
          },
          {
            'id': 6,
            'label': 'ObservationKey<Address>(User.address)',
            'observerCount': 0,
            'observers': [],
            if (valueInspectionEnabled)
              'value': {
                'kind': 'observable',
                'type': 'Address',
                'display': 'Address #5',
                'referenceId': 5,
              },
          },
        ],
      },
      {
        'id': 5,
        'registrarId': 7,
        'type': 'Address',
        'propertyCount': 0,
        'observerCount': 0,
        'properties': [
          {
            'id': 8,
            'label': 'ObservationKey<String>(Address.city)',
            'observerCount': 0,
            'observers': [],
            if (valueInspectionEnabled)
              'value': {
                'kind': 'string',
                'type': 'String',
                'display': '"Shanghai"',
              },
          },
        ],
      },
    ],
  };

  @override
  Future<void> clearEvents() async {
    _sentEvents = true;
  }

  @override
  Future<Map<String, Object?>> getEvents({
    required int afterSequence,
    int limit = 1000,
  }) async {
    if (_sentEvents || afterSequence >= 1) {
      return {'protocolVersion': 2, 'latestSequence': 1, 'events': []};
    }
    _sentEvents = true;
    return {
      'protocolVersion': 2,
      'latestSequence': 1,
      'events': [
        {
          'kind': 'notify',
          'sequence': 1,
          'timestampMicros': 1,
          'sourceId': 1,
          'sourceType': 'User',
          'propertyId': 3,
          'property': 'ObservationKey<String>(User.name)',
          'observerId': 4,
          'observer': 'UserPage',
          'observerCount': 1,
        },
      ],
    };
  }

  @override
  Future<Map<String, Object?>> getSnapshot() async => _snapshot;

  @override
  Future<Map<String, Object?>> setRecording({
    required bool enabled,
    int capacity = 2000,
    bool includeAccessEvents = false,
  }) async {
    recording = enabled;
    this.includeAccessEvents = includeAccessEvents;
    return _snapshot;
  }

  @override
  Future<Map<String, Object?>> setValueInspection({
    required bool enabled,
  }) async {
    valueInspectionEnabled = enabled;
    return _snapshot;
  }

  @override
  Future<bool> showInFlutterInspector({required int observerId}) async {
    inspectedObserverId = observerId;
    return true;
  }
}
