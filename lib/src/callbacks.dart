/// Runs every callback in order, even when one or more callbacks throw.
///
/// After all callbacks have run, the first error is rethrown with its original
/// stack trace. Observation uses this for notification fan-out and lifecycle
/// cleanup so one faulty consumer cannot prevent the remaining work.
void runObservationCallbacks(Iterable<void Function()> callbacks) {
  Object? firstError;
  StackTrace? firstStackTrace;

  for (final callback in callbacks) {
    try {
      callback();
    } catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }
  }

  if (firstError case final error?) {
    Error.throwWithStackTrace(error, firstStackTrace!);
  }
}
