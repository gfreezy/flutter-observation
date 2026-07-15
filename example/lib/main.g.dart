// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main.dart';

// **************************************************************************
// ObservationWidgetGenerator
// **************************************************************************

abstract class _$ObservationExample extends StatefulWidget {
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
    with ReactiveStateMixin<ObservationExample> {
  late User _user;
  bool _hasUser = false;
  bool _statesReady = false;

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
    } catch (_) {
      _disposeCreatedStates();
      rethrow;
    }
  }

  @override
  void didUpdateWidget(covariant ObservationExample oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldRecreateStates(oldWidget)) {
      stopReactiveObservation();
      _disposeStates(oldWidget);
      _createStates();
    } else {
      widget.didUpdateStates(oldWidget, user: _user);
    }
  }

  @override
  Widget build(BuildContext context) {
    return buildReactive((context) {
      return widget.build(context, user: _user);
    });
  }

  void _disposeStates(ObservationExample owner) {
    if (!_statesReady) return;
    _statesReady = false;
    try {
      owner.disposeStates(user: _user);
    } finally {
      _disposeCreatedStates();
    }
  }

  void _disposeCreatedStates() {
    if (_hasUser) {
      _hasUser = false;
    }
  }

  @override
  void dispose() {
    stopReactiveObservation();
    try {
      _disposeStates(widget);
    } finally {
      super.dispose();
    }
  }
}

abstract class _$UserCard extends ReactiveStatelessWidget {
  const _$UserCard({super.key});
}

abstract class _$AddressCard extends ReactiveStatelessWidget {
  const _$AddressCard({super.key});
}
