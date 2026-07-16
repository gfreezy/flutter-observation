import 'package:flutter_observation/flutter_observation.dart';

part 'advanced_models.g.dart';

/// Exercises the advanced generator surface without adding noise to the UI.
@ObservableModel()
class Box<T extends Object?> extends _$Box<T> {
  Box({
    required T value,
    @ObservationReadOnly() required String id,
    @ObservationIgnored() int cacheHits = 0,
    @ObservationAlwaysNotify() int revision = 0,
  }) : super(value, id, cacheHits, revision);

  static final ObservationKey<String> _externalStatusKey =
      ObservationKey<String>('Box.externalStatus');
  String _externalStatus = 'idle';

  String get description => '$id: $value';

  String get externalStatus {
    observationAccess(_externalStatusKey);
    return _externalStatus;
  }

  set externalStatus(String value) {
    if (_externalStatus == value) return;
    observationMutation(_externalStatusKey, () => _externalStatus = value);
  }
}
