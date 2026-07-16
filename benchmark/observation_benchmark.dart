import 'package:flutter_observation/flutter_observation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('observation performance baseline', () {
    _benchmarkReads();
    _benchmarkFanOut();
    _benchmarkKeyedMap();
  });
}

void _benchmarkReads() {
  const iterations = 1000000;
  final value = Observable(1);
  var total = 0;
  final stopwatch = Stopwatch()..start();
  for (var index = 0; index < iterations; index++) {
    total += value.value;
  }
  stopwatch.stop();
  _report('1M untracked reads', stopwatch, '$total');
}

void _benchmarkFanOut() {
  const observerCount = 10000;
  final value = Observable(0);
  var invalidations = 0;
  for (var index = 0; index < observerCount; index++) {
    withObservationTracking(() => value.value, onChange: () => invalidations++);
  }

  final stopwatch = Stopwatch()..start();
  value.value++;
  stopwatch.stop();
  _report('10K observer fan-out', stopwatch, '$invalidations invalidations');
}

void _benchmarkKeyedMap() {
  const entryCount = 10000;
  final values = ObservableMap<int, int>({
    for (var index = 0; index < entryCount; index++) index: index,
  });
  var invalidations = 0;
  for (var index = 0; index < entryCount; index++) {
    withObservationTracking(
      () => values[index],
      onChange: () => invalidations++,
    );
  }

  final stopwatch = Stopwatch()..start();
  values[entryCount ~/ 2] = -1;
  stopwatch.stop();
  _report('10K keyed map observers', stopwatch, '$invalidations invalidation');
}

void _report(String name, Stopwatch stopwatch, String result) {
  // ignore: avoid_print
  print('$name: ${stopwatch.elapsedMicroseconds} µs ($result)');
}
