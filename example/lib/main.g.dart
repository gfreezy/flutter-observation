// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main.dart';

// **************************************************************************
// ObservationWidgetGenerator
// **************************************************************************

abstract class _$ObservationExample extends StatefulWidget
    with ObservationWidgetDiagnostics {
  const _$ObservationExample({super.key});

  Widget build(BuildContext context, {required User user});

  bool shouldRecreateStates(covariant _$ObservationExample oldWidget) => false;

  void didUpdateStates(
    covariant _$ObservationExample oldWidget, {
    required User user,
  }) {}

  void disposeStates({required User user}) {}

  @override
  State<ObservationExample> createState() => _$ObservationExampleState();
}

final class _$ObservationExampleState extends State<ObservationExample>
    with ObservationStateMixin<ObservationExample> {
  late User _user;
  bool _hasUser = false;
  bool _statesReady = false;

  @override
  Iterable<({String name, Object? value})> get observationOwnedStates => [
    if (_hasUser) (name: 'user', value: _user),
  ];

  @override
  void initState() {
    super.initState();
    _createStates();
  }

  void _createStates() {
    try {
      _user = widget.createUser();
      _hasUser = true;
      _statesReady = true;
    } catch (error, stackTrace) {
      runObservationCallbacks([
        () => Error.throwWithStackTrace(error, stackTrace),
        _disposeCreatedStates,
      ]);
    }
  }

  @override
  void didUpdateWidget(covariant ObservationExample oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldRecreateStates(oldWidget)) {
      stopObservation();
      _disposeStates(oldWidget);
      _createStates();
    } else {
      widget.didUpdateStates(oldWidget, user: _user);
    }
  }

  @override
  Widget build(BuildContext context) {
    return buildObserved((context) {
      return widget.build(context, user: _user);
    });
  }

  void _disposeStates(ObservationExample owner) {
    if (!_statesReady) return;
    _statesReady = false;
    runObservationCallbacks([
      () => owner.disposeStates(user: _user),
      _disposeCreatedStates,
    ]);
  }

  void _disposeCreatedStates() {
    runObservationCallbacks([
      if (_hasUser)
        () {
          _hasUser = false;
        },
    ]);
  }

  @override
  void dispose() {
    stopObservation();
    try {
      _disposeStates(widget);
    } finally {
      super.dispose();
    }
  }
}

abstract class _$UserCard extends ObservationStatelessWidget {
  const _$UserCard({super.key});
}

abstract class _$AddressCard extends ObservationStatelessWidget {
  const _$AddressCard({super.key});
}
