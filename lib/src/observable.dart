import 'model.dart';
import 'observation_key.dart';

/// A standalone observable value.
final class Observable<T> with ObservableModelMixin {
  Observable(T value) : _value = value;

  final ObservationKey<T> _property = ObservationKey<T>('Observable.value');
  T _value;

  T get value {
    observationAccess(_property);
    return _value;
  }

  set value(T value) {
    if (_value == value) return;
    observationMutation(_property, () => _value = value);
  }
}
