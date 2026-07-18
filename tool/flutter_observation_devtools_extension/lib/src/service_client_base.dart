abstract interface class ObservationServiceClient {
  Future<Map<String, Object?>> getSnapshot();

  Future<Map<String, Object?>> getEvents({
    required int afterSequence,
    int limit = 1000,
  });

  Future<Map<String, Object?>> setRecording({
    required bool enabled,
    int capacity = 2000,
    bool includeAccessEvents = false,
  });

  Future<Map<String, Object?>> setValueInspection({required bool enabled});

  Future<bool> showInFlutterInspector({required int observerId});

  Future<void> clearEvents();
}
