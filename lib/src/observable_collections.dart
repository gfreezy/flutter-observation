import 'dart:collection';
import 'dart:math';

import 'debug.dart';
import 'model.dart';
import 'observation_key.dart';
import 'registrar.dart';
import 'tracking.dart';
import 'transaction.dart';

/// A growable list whose reads and in-place mutations participate in
/// observation tracking.
final class ObservableList<E> extends ListBase<E> implements ObservableObject {
  ObservableList([Iterable<E> values = const []])
    : _values = List<E>.of(values, growable: true) {
    _registrar.attachDebugSource(this);
    if (!ObservationDebug.isReleaseMode) {
      _registrar.registerDebugProperty(_contentsKey, () => _values);
      _registrar.registerDebugProperty(_lengthKey, () => _values.length);
    }
  }

  final List<E> _values;
  final ObservationRegistrar _registrar = ObservationRegistrar();
  final Map<int, ObservationKey<Object?>> _indexKeys = {};
  int _keysUntilPrune = 64;

  static final ObservationKey<Object?> _contentsKey = ObservationKey<Object?>(
    'ObservableList.contents',
  );
  static final ObservationKey<int> _lengthKey = ObservationKey<int>(
    'ObservableList.length',
  );

  @override
  ObservationRegistrar get observationRegistrar => _registrar;

  ObservationKey<Object?> _indexKey(int index) {
    if (!_indexKeys.containsKey(index)) _maybePruneIndexKeys();
    return _indexKeys.putIfAbsent(index, () {
      final property = ObservationKey<Object?>('ObservableList[$index]');
      if (!ObservationDebug.isReleaseMode) {
        _registrar.registerDebugProperty(
          property,
          () => index >= 0 && index < _values.length ? _values[index] : null,
        );
      }
      return property;
    });
  }

  void _maybePruneIndexKeys() {
    _keysUntilPrune--;
    if (_keysUntilPrune > 0) return;
    _keysUntilPrune = 64;
    _indexKeys.removeWhere((_, key) => !_registrar.hasObserversFor(key));
  }

  void _notifyChange({
    bool lengthChanged = false,
    int? fromIndex,
    int? toIndex,
  }) {
    final affectedIndexKeys = _indexKeys.entries
        .where((entry) {
          return (fromIndex == null || entry.key >= fromIndex) &&
              (toIndex == null || entry.key < toIndex);
        })
        .map((entry) => entry.value)
        .toList();

    ObservationTransaction.run(() {
      _registrar.notify(_contentsKey);
      if (lengthChanged) _registrar.notify(_lengthKey);
      for (final key in affectedIndexKeys) {
        _registrar.notify(key);
      }
    });
  }

  @override
  int get length {
    _registrar.access(_lengthKey);
    return _values.length;
  }

  @override
  set length(int value) {
    final previousLength = _values.length;
    if (previousLength == value) return;
    _values.length = value;
    _notifyChange(lengthChanged: true, fromIndex: min(previousLength, value));
  }

  @override
  Iterator<E> get iterator {
    _registrar.access(_contentsKey);
    return _values.iterator;
  }

  @override
  E operator [](int index) {
    if (ObservationTracking.currentObserver != null) {
      _registrar.access(_indexKey(index));
    }
    return _values[index];
  }

  @override
  void operator []=(int index, E element) {
    if (_values[index] == element) return;
    _values[index] = element;
    _notifyChange(fromIndex: index, toIndex: index + 1);
  }

  @override
  void add(E element) {
    final index = _values.length;
    _values.add(element);
    _notifyChange(lengthChanged: true, fromIndex: index);
  }

  @override
  void addAll(Iterable<E> iterable) {
    final values = iterable.toList();
    if (values.isEmpty) return;
    final index = _values.length;
    _values.addAll(values);
    _notifyChange(lengthChanged: true, fromIndex: index);
  }

  @override
  void insert(int index, E element) {
    _values.insert(index, element);
    _notifyChange(lengthChanged: true, fromIndex: index);
  }

  @override
  void insertAll(int index, Iterable<E> iterable) {
    final values = iterable.toList();
    if (values.isEmpty) return;
    _values.insertAll(index, values);
    _notifyChange(lengthChanged: true, fromIndex: index);
  }

  @override
  bool remove(Object? element) {
    final index = _values.indexWhere((value) => value == element);
    if (index < 0) return false;
    _values.removeAt(index);
    _notifyChange(lengthChanged: true, fromIndex: index);
    return true;
  }

  @override
  E removeAt(int index) {
    final value = _values.removeAt(index);
    _notifyChange(lengthChanged: true, fromIndex: index);
    return value;
  }

  @override
  E removeLast() {
    final index = _values.length - 1;
    final value = _values.removeLast();
    _notifyChange(lengthChanged: true, fromIndex: index);
    return value;
  }

  @override
  void clear() {
    if (_values.isEmpty) return;
    _values.clear();
    _notifyChange(lengthChanged: true, fromIndex: 0);
  }

  @override
  void removeRange(int start, int end) {
    if (start == end) return;
    _values.removeRange(start, end);
    _notifyChange(lengthChanged: true, fromIndex: start);
  }

  @override
  void replaceRange(int start, int end, Iterable<E> newContents) {
    final values = newContents.toList();
    if (start == end && values.isEmpty) return;
    final previousLength = _values.length;
    _values.replaceRange(start, end, values);
    _notifyChange(
      lengthChanged: previousLength != _values.length,
      fromIndex: start,
    );
  }

  @override
  void setAll(int index, Iterable<E> iterable) {
    final values = iterable.toList();
    if (values.isEmpty) return;
    _values.setAll(index, values);
    _notifyChange(fromIndex: index, toIndex: index + values.length);
  }

  @override
  void setRange(int start, int end, Iterable<E> iterable, [int skipCount = 0]) {
    if (start == end) return;
    _values.setRange(start, end, iterable, skipCount);
    _notifyChange(fromIndex: start, toIndex: end);
  }

  @override
  void fillRange(int start, int end, [E? fill]) {
    if (start == end) return;
    _values.fillRange(start, end, fill);
    _notifyChange(fromIndex: start, toIndex: end);
  }

  @override
  void removeWhere(bool Function(E element) test) {
    final previousLength = _values.length;
    _values.removeWhere(test);
    if (_values.length != previousLength) {
      _notifyChange(lengthChanged: true, fromIndex: 0);
    }
  }

  @override
  void retainWhere(bool Function(E element) test) {
    final previousLength = _values.length;
    _values.retainWhere(test);
    if (_values.length != previousLength) {
      _notifyChange(lengthChanged: true, fromIndex: 0);
    }
  }

  @override
  void sort([int Function(E a, E b)? compare]) {
    if (_values.length < 2) return;
    _values.sort(compare);
    _notifyChange(fromIndex: 0);
  }

  @override
  void shuffle([Random? random]) {
    if (_values.length < 2) return;
    _values.shuffle(random);
    _notifyChange(fromIndex: 0);
  }

  /// Performs several mutations while invalidating each observer once.
  T transaction<T>(T Function(ObservableList<E> list) body) {
    return ObservationTransaction.run(() => body(this));
  }
}

/// A map whose direct key reads are tracked independently while iteration
/// observes the complete contents.
final class ObservableMap<K, V> extends MapBase<K, V>
    implements ObservableObject {
  ObservableMap([Map<K, V>? values]) : _values = Map<K, V>.of(values ?? {}) {
    _registrar.attachDebugSource(this);
    if (!ObservationDebug.isReleaseMode) {
      _registrar.registerDebugProperty(_contentsKey, () => _values);
    }
  }

  final Map<K, V> _values;
  final ObservationRegistrar _registrar = ObservationRegistrar();
  final Map<Object?, ObservationKey<Object?>> _entryKeys = {};
  int _keysUntilPrune = 64;

  static final ObservationKey<Object?> _contentsKey = ObservationKey<Object?>(
    'ObservableMap.contents',
  );

  @override
  ObservationRegistrar get observationRegistrar => _registrar;

  ObservationKey<Object?> _entryKey(Object? key) {
    if (!_entryKeys.containsKey(key)) _maybePruneEntryKeys();
    return _entryKeys.putIfAbsent(key, () {
      final property = ObservationKey<Object?>('ObservableMap[$key]');
      if (!ObservationDebug.isReleaseMode) {
        _registrar.registerDebugProperty(property, () => _values[key]);
      }
      return property;
    });
  }

  void _maybePruneEntryKeys() {
    _keysUntilPrune--;
    if (_keysUntilPrune > 0) return;
    _keysUntilPrune = 64;
    _entryKeys.removeWhere((_, key) => !_registrar.hasObserversFor(key));
  }

  void _notifyKeys(Iterable<Object?> keys) {
    final entryKeys = keys
        .map((key) => _entryKeys[key])
        .whereType<ObservationKey<Object?>>()
        .toList();
    ObservationTransaction.run(() {
      _registrar.notify(_contentsKey);
      for (final key in entryKeys) {
        _registrar.notify(key);
      }
    });
  }

  @override
  V? operator [](Object? key) {
    if (ObservationTracking.currentObserver != null) {
      _registrar.access(_entryKey(key));
    }
    return _values[key];
  }

  @override
  bool containsKey(Object? key) {
    if (ObservationTracking.currentObserver != null) {
      _registrar.access(_entryKey(key));
    }
    return _values.containsKey(key);
  }

  @override
  void operator []=(K key, V value) {
    if (_values.containsKey(key) && _values[key] == value) return;
    _values[key] = value;
    _notifyKeys([key]);
  }

  @override
  Iterable<K> get keys {
    _registrar.access(_contentsKey);
    return _values.keys;
  }

  @override
  void clear() {
    if (_values.isEmpty) return;
    final keys = _values.keys.toList();
    _values.clear();
    _notifyKeys(keys);
  }

  @override
  V? remove(Object? key) {
    if (!_values.containsKey(key)) return null;
    final value = _values.remove(key);
    _notifyKeys([key]);
    return value;
  }

  @override
  void addAll(Map<K, V> other) {
    final changedKeys = <K>[];
    for (final entry in other.entries) {
      if (!_values.containsKey(entry.key) ||
          _values[entry.key] != entry.value) {
        changedKeys.add(entry.key);
      }
    }
    if (changedKeys.isEmpty) return;
    _values.addAll(other);
    _notifyKeys(changedKeys);
  }

  @override
  void addEntries(Iterable<MapEntry<K, V>> newEntries) {
    ObservationTransaction.run(() {
      for (final entry in newEntries) {
        this[entry.key] = entry.value;
      }
    });
  }

  @override
  V putIfAbsent(K key, V Function() ifAbsent) {
    if (_values.containsKey(key)) return _values[key] as V;
    final value = _values.putIfAbsent(key, ifAbsent);
    _notifyKeys([key]);
    return value;
  }

  @override
  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) {
    final hadKey = _values.containsKey(key);
    final previous = _values[key];
    final value = _values.update(key, update, ifAbsent: ifAbsent);
    if (!hadKey || previous != value) _notifyKeys([key]);
    return value;
  }

  @override
  void updateAll(V Function(K key, V value) update) {
    if (_values.isEmpty) return;
    final previous = Map<K, V>.of(_values);
    _values.updateAll(update);
    final changedKeys = _values.keys.where(
      (key) => previous[key] != _values[key],
    );
    if (changedKeys.isNotEmpty) _notifyKeys(changedKeys);
  }

  @override
  void removeWhere(bool Function(K key, V value) test) {
    final previousKeys = _values.keys.toSet();
    _values.removeWhere(test);
    final removedKeys = previousKeys.difference(_values.keys.toSet());
    if (removedKeys.isNotEmpty) _notifyKeys(removedKeys);
  }

  /// Performs several mutations while invalidating each observer once.
  T transaction<T>(T Function(ObservableMap<K, V> map) body) {
    return ObservationTransaction.run(() => body(this));
  }
}

/// A set whose direct membership reads are tracked independently while
/// iteration observes the complete contents.
final class ObservableSet<E> extends SetBase<E> implements ObservableObject {
  ObservableSet([Iterable<E> values = const []]) : _values = Set<E>.of(values) {
    _registrar.attachDebugSource(this);
    if (!ObservationDebug.isReleaseMode) {
      _registrar.registerDebugProperty(_contentsKey, () => _values);
    }
  }

  final Set<E> _values;
  final ObservationRegistrar _registrar = ObservationRegistrar();
  final Map<Object?, ObservationKey<Object?>> _elementKeys = {};
  int _keysUntilPrune = 64;

  static final ObservationKey<Object?> _contentsKey = ObservationKey<Object?>(
    'ObservableSet.contents',
  );

  @override
  ObservationRegistrar get observationRegistrar => _registrar;

  ObservationKey<Object?> _elementKey(Object? value) {
    if (!_elementKeys.containsKey(value)) _maybePruneElementKeys();
    return _elementKeys.putIfAbsent(value, () {
      final property = ObservationKey<Object?>('ObservableSet[$value]');
      if (!ObservationDebug.isReleaseMode) {
        _registrar.registerDebugProperty(
          property,
          () => _values.contains(value),
        );
      }
      return property;
    });
  }

  void _maybePruneElementKeys() {
    _keysUntilPrune--;
    if (_keysUntilPrune > 0) return;
    _keysUntilPrune = 64;
    _elementKeys.removeWhere((_, key) => !_registrar.hasObserversFor(key));
  }

  void _notifyElements(Iterable<Object?> elements) {
    final elementKeys = elements
        .map((element) => _elementKeys[element])
        .whereType<ObservationKey<Object?>>()
        .toList();
    ObservationTransaction.run(() {
      _registrar.notify(_contentsKey);
      for (final key in elementKeys) {
        _registrar.notify(key);
      }
    });
  }

  @override
  bool add(E value) {
    final added = _values.add(value);
    if (added) _notifyElements([value]);
    return added;
  }

  @override
  bool contains(Object? element) {
    if (ObservationTracking.currentObserver != null) {
      _registrar.access(_elementKey(element));
    }
    return _values.contains(element);
  }

  @override
  E? lookup(Object? element) {
    if (ObservationTracking.currentObserver != null) {
      _registrar.access(_elementKey(element));
    }
    return _values.lookup(element);
  }

  @override
  bool remove(Object? value) {
    final removed = _values.remove(value);
    if (removed) _notifyElements([value]);
    return removed;
  }

  @override
  Iterator<E> get iterator {
    _registrar.access(_contentsKey);
    return _values.iterator;
  }

  @override
  int get length {
    _registrar.access(_contentsKey);
    return _values.length;
  }

  @override
  Set<E> toSet() {
    _registrar.access(_contentsKey);
    return _values.toSet();
  }

  @override
  void addAll(Iterable<E> elements) {
    final added = <E>[];
    for (final element in elements) {
      if (_values.add(element)) added.add(element);
    }
    if (added.isNotEmpty) _notifyElements(added);
  }

  @override
  void removeAll(Iterable<Object?> elements) {
    final removed = <Object?>[];
    for (final element in elements.toList()) {
      if (_values.remove(element)) removed.add(element);
    }
    if (removed.isNotEmpty) _notifyElements(removed);
  }

  @override
  void retainAll(Iterable<Object?> elements) {
    final retained = elements.toSet();
    final removed = _values
        .where((value) => !retained.contains(value))
        .toList();
    if (removed.isEmpty) return;
    _values.retainAll(retained);
    _notifyElements(removed);
  }

  @override
  void removeWhere(bool Function(E element) test) {
    final removed = _values.where(test).toList();
    if (removed.isEmpty) return;
    _values.removeAll(removed);
    _notifyElements(removed);
  }

  @override
  void retainWhere(bool Function(E element) test) {
    final removed = _values.where((element) => !test(element)).toList();
    if (removed.isEmpty) return;
    _values.removeAll(removed);
    _notifyElements(removed);
  }

  @override
  void clear() {
    if (_values.isEmpty) return;
    final removed = _values.toList();
    _values.clear();
    _notifyElements(removed);
  }

  /// Performs several mutations while invalidating each observer once.
  T transaction<T>(T Function(ObservableSet<E> set) body) {
    return ObservationTransaction.run(() => body(this));
  }
}
