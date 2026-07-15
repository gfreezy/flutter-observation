import 'dart:collection';
import 'dart:math';

import 'model.dart';
import 'observation_key.dart';
import 'registrar.dart';
import 'transaction.dart';

/// A growable list whose reads and in-place mutations participate in
/// observation tracking.
final class ObservableList<E> extends ListBase<E> implements ObservableObject {
  ObservableList([Iterable<E> values = const []])
    : _values = List<E>.of(values, growable: true);

  final List<E> _values;
  final ObservationRegistrar _registrar = ObservationRegistrar();

  @override
  ObservationRegistrar get observationRegistrar => _registrar;

  static final ObservationKey<Object?> _contentsKey = ObservationKey<Object?>(
    'ObservableList.contents',
  );

  void _access() => _registrar.access(_contentsKey);
  void _notify() => _registrar.notify(_contentsKey);

  @override
  int get length {
    _access();
    return _values.length;
  }

  @override
  set length(int value) {
    if (_values.length == value) return;
    _values.length = value;
    _notify();
  }

  @override
  E operator [](int index) {
    _access();
    return _values[index];
  }

  @override
  void operator []=(int index, E element) {
    if (_values[index] == element) return;
    _values[index] = element;
    _notify();
  }

  @override
  void add(E element) {
    _values.add(element);
    _notify();
  }

  @override
  void addAll(Iterable<E> iterable) {
    final previousLength = _values.length;
    _values.addAll(iterable);
    if (_values.length != previousLength) _notify();
  }

  @override
  void insert(int index, E element) {
    _values.insert(index, element);
    _notify();
  }

  @override
  void insertAll(int index, Iterable<E> iterable) {
    final previousLength = _values.length;
    _values.insertAll(index, iterable);
    if (_values.length != previousLength) _notify();
  }

  @override
  bool remove(Object? element) {
    final removed = _values.remove(element);
    if (removed) _notify();
    return removed;
  }

  @override
  E removeAt(int index) {
    final value = _values.removeAt(index);
    _notify();
    return value;
  }

  @override
  E removeLast() {
    final value = _values.removeLast();
    _notify();
    return value;
  }

  @override
  void clear() {
    if (_values.isEmpty) return;
    _values.clear();
    _notify();
  }

  @override
  void removeRange(int start, int end) {
    if (start == end) return;
    _values.removeRange(start, end);
    _notify();
  }

  @override
  void replaceRange(int start, int end, Iterable<E> newContents) {
    _values.replaceRange(start, end, newContents);
    _notify();
  }

  @override
  void setAll(int index, Iterable<E> iterable) {
    _values.setAll(index, iterable);
    _notify();
  }

  @override
  void setRange(int start, int end, Iterable<E> iterable, [int skipCount = 0]) {
    if (start == end) return;
    _values.setRange(start, end, iterable, skipCount);
    _notify();
  }

  @override
  void fillRange(int start, int end, [E? fill]) {
    if (start == end) return;
    _values.fillRange(start, end, fill);
    _notify();
  }

  @override
  void removeWhere(bool Function(E element) test) {
    final previousLength = _values.length;
    _values.removeWhere(test);
    if (_values.length != previousLength) _notify();
  }

  @override
  void retainWhere(bool Function(E element) test) {
    final previousLength = _values.length;
    _values.retainWhere(test);
    if (_values.length != previousLength) _notify();
  }

  @override
  void sort([int Function(E a, E b)? compare]) {
    if (_values.length < 2) return;
    _values.sort(compare);
    _notify();
  }

  @override
  void shuffle([Random? random]) {
    if (_values.length < 2) return;
    _values.shuffle(random);
    _notify();
  }

  /// Performs several mutations while invalidating each observer once.
  T transaction<T>(T Function(ObservableList<E> list) body) =>
      ObservationTransaction.run(() => body(this));
}

/// A map whose reads and in-place mutations participate in observation
/// tracking.
final class ObservableMap<K, V> extends MapBase<K, V>
    implements ObservableObject {
  ObservableMap([Map<K, V>? values]) : _values = Map<K, V>.of(values ?? {});

  final Map<K, V> _values;
  final ObservationRegistrar _registrar = ObservationRegistrar();

  @override
  ObservationRegistrar get observationRegistrar => _registrar;

  static final ObservationKey<Object?> _contentsKey = ObservationKey<Object?>(
    'ObservableMap.contents',
  );

  void _access() => _registrar.access(_contentsKey);
  void _notify() => _registrar.notify(_contentsKey);

  @override
  V? operator [](Object? key) {
    _access();
    return _values[key];
  }

  @override
  void operator []=(K key, V value) {
    if (_values.containsKey(key) && _values[key] == value) return;
    _values[key] = value;
    _notify();
  }

  @override
  Iterable<K> get keys {
    _access();
    return _values.keys;
  }

  @override
  void clear() {
    if (_values.isEmpty) return;
    _values.clear();
    _notify();
  }

  @override
  V? remove(Object? key) {
    if (!_values.containsKey(key)) return null;
    final value = _values.remove(key);
    _notify();
    return value;
  }

  @override
  void addAll(Map<K, V> other) {
    if (other.isEmpty) return;
    _values.addAll(other);
    _notify();
  }

  @override
  void addEntries(Iterable<MapEntry<K, V>> newEntries) {
    final entries = newEntries.toList();
    if (entries.isEmpty) return;
    _values.addEntries(entries);
    _notify();
  }

  @override
  V putIfAbsent(K key, V Function() ifAbsent) {
    if (_values.containsKey(key)) return _values[key] as V;
    final value = _values.putIfAbsent(key, ifAbsent);
    _notify();
    return value;
  }

  @override
  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) {
    final hadKey = _values.containsKey(key);
    final previous = _values[key];
    final value = _values.update(key, update, ifAbsent: ifAbsent);
    if (!hadKey || previous != value) _notify();
    return value;
  }

  @override
  void updateAll(V Function(K key, V value) update) {
    if (_values.isEmpty) return;
    _values.updateAll(update);
    _notify();
  }

  @override
  void removeWhere(bool Function(K key, V value) test) {
    final previousLength = _values.length;
    _values.removeWhere(test);
    if (_values.length != previousLength) _notify();
  }

  /// Performs several mutations while invalidating each observer once.
  T transaction<T>(T Function(ObservableMap<K, V> map) body) =>
      ObservationTransaction.run(() => body(this));
}

/// A set whose reads and in-place mutations participate in observation
/// tracking.
final class ObservableSet<E> extends SetBase<E> implements ObservableObject {
  ObservableSet([Iterable<E> values = const []]) : _values = Set<E>.of(values);

  final Set<E> _values;
  final ObservationRegistrar _registrar = ObservationRegistrar();

  @override
  ObservationRegistrar get observationRegistrar => _registrar;

  static final ObservationKey<Object?> _contentsKey = ObservationKey<Object?>(
    'ObservableSet.contents',
  );

  void _access() => _registrar.access(_contentsKey);
  void _notify() => _registrar.notify(_contentsKey);

  @override
  bool add(E value) {
    final added = _values.add(value);
    if (added) _notify();
    return added;
  }

  @override
  bool contains(Object? element) {
    _access();
    return _values.contains(element);
  }

  @override
  E? lookup(Object? element) {
    _access();
    return _values.lookup(element);
  }

  @override
  bool remove(Object? value) {
    final removed = _values.remove(value);
    if (removed) _notify();
    return removed;
  }

  @override
  Iterator<E> get iterator {
    _access();
    return _values.iterator;
  }

  @override
  int get length {
    _access();
    return _values.length;
  }

  @override
  Set<E> toSet() {
    _access();
    return _values.toSet();
  }

  @override
  void addAll(Iterable<E> elements) {
    final previousLength = _values.length;
    _values.addAll(elements);
    if (_values.length != previousLength) _notify();
  }

  @override
  void removeAll(Iterable<Object?> elements) {
    final previousLength = _values.length;
    _values.removeAll(elements);
    if (_values.length != previousLength) _notify();
  }

  @override
  void retainAll(Iterable<Object?> elements) {
    final previousLength = _values.length;
    _values.retainAll(elements);
    if (_values.length != previousLength) _notify();
  }

  @override
  void removeWhere(bool Function(E element) test) {
    final previousLength = _values.length;
    _values.removeWhere(test);
    if (_values.length != previousLength) _notify();
  }

  @override
  void retainWhere(bool Function(E element) test) {
    final previousLength = _values.length;
    _values.retainWhere(test);
    if (_values.length != previousLength) _notify();
  }

  @override
  void clear() {
    if (_values.isEmpty) return;
    _values.clear();
    _notify();
  }

  /// Performs several mutations while invalidating each observer once.
  T transaction<T>(T Function(ObservableSet<E> set) body) =>
      ObservationTransaction.run(() => body(this));
}
