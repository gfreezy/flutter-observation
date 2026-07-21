// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'advanced_models.dart';

// **************************************************************************
// ObservableGenerator
// **************************************************************************

abstract class _$Box<T extends Object?> with ObservableModelMixin {
  _$Box({
    required T value,
    required String id,
    required int cacheHits,
    required int revision,
  }) : _value = value,
       _id = id,
       _cacheHits = cacheHits,
       _revision = revision {
    if (!ObservationDebug.isReleaseMode) {
      observationRegisterDebugProperty(_valueKey, () => _value);
      observationRegisterDebugProperty(_idKey, () => _id);
      observationRegisterDebugProperty(_revisionKey, () => _revision);
    }
  }
  final ObservationKey<T> _valueKey = ObservationKey<T>('Box.value');
  T _value;

  T get value {
    observationAccess(_valueKey);
    return _value;
  }

  set value(T value) {
    if (_value == value) return;
    observationMutation(_valueKey, () {
      _value = value;
    });
  }

  final ObservationKey<String> _idKey = ObservationKey<String>('Box.id');
  final String _id;

  String get id {
    observationAccess(_idKey);
    return _id;
  }

  int _cacheHits;

  int get cacheHits {
    return _cacheHits;
  }

  set cacheHits(int value) {
    if (_cacheHits == value) return;
    _cacheHits = value;
  }

  final ObservationKey<int> _revisionKey = ObservationKey<int>('Box.revision');
  int _revision;

  int get revision {
    observationAccess(_revisionKey);
    return _revision;
  }

  set revision(int value) {
    observationMutation(_revisionKey, () {
      _revision = value;
    });
  }
}
