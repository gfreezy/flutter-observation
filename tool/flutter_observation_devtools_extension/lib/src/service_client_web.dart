import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:web/web.dart' as web;

import 'service_client_base.dart';

ObservationServiceClient createVmObservationServiceClient() {
  return VmObservationServiceClient();
}

final class VmObservationServiceClient implements ObservationServiceClient {
  static const _getSnapshot = 'ext.flutter_observation.getSnapshot';
  static const _getEvents = 'ext.flutter_observation.getEvents';
  static const _setRecording = 'ext.flutter_observation.setRecording';
  static const _setValueInspection =
      'ext.flutter_observation.setValueInspection';
  static const _selectInspectorTarget =
      'ext.flutter_observation.selectInspectorTarget';
  static const _clearEvents = 'ext.flutter_observation.clearEvents';

  Future<Map<String, Object?>> _call(
    String method, {
    Map<String, dynamic>? args,
  }) async {
    await serviceManager.onServiceAvailable;
    final response = await serviceManager.callServiceExtensionOnMainIsolate(
      method,
      args: args,
    );
    final json = response.json;
    if (json == null) return const {};
    return json.map((key, value) => MapEntry(key, value));
  }

  @override
  Future<Map<String, Object?>> getSnapshot() => _call(_getSnapshot);

  @override
  Future<Map<String, Object?>> getEvents({
    required int afterSequence,
    int limit = 1000,
  }) {
    return _call(_getEvents, args: {'after': afterSequence, 'limit': limit});
  }

  @override
  Future<Map<String, Object?>> setRecording({
    required bool enabled,
    int capacity = 2000,
    bool includeAccessEvents = false,
  }) {
    return _call(
      _setRecording,
      args: {
        'enabled': enabled,
        'capacity': capacity,
        'includeAccessEvents': includeAccessEvents,
      },
    );
  }

  @override
  Future<Map<String, Object?>> setValueInspection({required bool enabled}) {
    return _call(_setValueInspection, args: {'enabled': enabled});
  }

  @override
  Future<bool> showInFlutterInspector({required int observerId}) async {
    final response = await _call(
      _selectInspectorTarget,
      args: {'observerId': observerId},
    );
    if (response['selected'] != true) return false;
    _openFlutterInspector();
    return true;
  }

  void _openFlutterInspector() {
    final current = Uri.tryParse(web.window.location.href);
    if (current == null) return;
    const marker = '/devtools/';
    final markerIndex = current.path.indexOf(marker);
    if (markerIndex < 0) return;
    final inspectorPath =
        '${current.path.substring(0, markerIndex + marker.length)}inspector';
    web.window.parent?.location.href = current
        .replace(path: inspectorPath)
        .toString();
  }

  @override
  Future<void> clearEvents() async {
    await _call(_clearEvents);
  }
}
