/// Source generation for lifecycle-aware observation widgets.
library;

import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:flutter_observation/annotations.dart';
import 'package:flutter_observation/model.dart';
import 'package:source_gen/source_gen.dart';

const _stateChecker = TypeChecker.typeNamed(
  StateAnnotation,
  inPackage: 'flutter_observation',
);
const _observableStateChecker = TypeChecker.typeNamed(
  ObservableState,
  inPackage: 'flutter_observation',
);
const _observableChecker = TypeChecker.typeNamed(
  ObservableModel,
  inPackage: 'flutter_observation',
);
const _observableObjectChecker = TypeChecker.typeNamed(
  ObservableObject,
  inPackage: 'flutter_observation',
);

final class ObservationWidgetGenerator
    extends GeneratorForAnnotation<ObservationWidget> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@ObservationWidget() can only be used on a class.',
        element: element,
      );
    }
    if (element.isAbstract) {
      throw InvalidGenerationSourceError(
        '@ObservationWidget() classes must be concrete.',
        element: element,
      );
    }

    final className = element.name;
    if (className == null) {
      throw InvalidGenerationSourceError(
        'The reactive Widget class must have a name.',
        element: element,
      );
    }

    final constructors = element.constructors.where(
      (constructor) => constructor.isGenerative && constructor.name == 'new',
    );
    if (constructors.isEmpty) {
      throw InvalidGenerationSourceError(
        '$className must declare an unnamed generative constructor.',
        element: element,
      );
    }

    final states = <_StateDescriptor>[];
    for (final method in element.methods) {
      final stateAnnotations = _stateChecker.annotationsOf(method).toList();
      if (stateAnnotations.isEmpty) continue;
      if (stateAnnotations.length > 1) {
        throw InvalidGenerationSourceError(
          'Use only one of @PlainState() and @ObservableState() on a state '
          'factory.',
          element: method,
        );
      }
      final stateAnnotation = stateAnnotations.single;
      if (method.isStatic) {
        throw InvalidGenerationSourceError(
          'State factories must be instance methods.',
          element: method,
        );
      }
      if (method.formalParameters.isNotEmpty) {
        throw InvalidGenerationSourceError(
          'State factories cannot declare parameters.',
          element: method,
        );
      }
      final type = method.returnType.getDisplayString();
      if (type == 'void' || type == 'dynamic') {
        throw InvalidGenerationSourceError(
          'State factories must declare a concrete return type.',
          element: method,
        );
      }
      final requiresObservable = _observableStateChecker.isAssignableFromType(
        stateAnnotation.type!,
      );
      final returnsObservable = _isObservableType(method.returnType);
      if (requiresObservable && !returnsObservable) {
        throw InvalidGenerationSourceError(
          '@ObservableState() factories must return an ObservableObject. Use '
          'an @ObservableModel() model, Observable<T>, an observable collection, '
          'or a '
          'type that mixes in ObservableModelMixin.',
          element: method,
        );
      }
      if (!requiresObservable &&
          _isObservableType(method.returnType, allowNullable: true)) {
        throw InvalidGenerationSourceError(
          '@PlainState() factories must return a non-ObservableObject. Use '
          '@ObservableState() for observable state.',
          element: method,
        );
      }

      final reader = ConstantReader(stateAnnotation);
      final explicitName = reader.peek('name')?.stringValue;
      final name = explicitName ?? _stateName(method.name!);
      if (!_isGeneratedStateName(name)) {
        throw InvalidGenerationSourceError(
          '`$name` cannot be used as a generated state parameter. Choose a '
          'non-keyword name other than `context` or `oldWidget`.',
          element: method,
        );
      }
      if (states.any((state) => state.name == name)) {
        throw InvalidGenerationSourceError(
          'More than one state factory generates `$name`.',
          element: method,
        );
      }
      final autoDispose = reader.peek('autoDispose')?.boolValue ?? true;
      final disposeMethod = _zeroArgumentDispose(method.returnType);
      if (autoDispose &&
          disposeMethod != null &&
          disposeMethod.returnType.getDisplayString() != 'void') {
        throw InvalidGenerationSourceError(
          'Automatically managed dispose() methods must return void. Set '
          'autoDispose to false and use disposeStates() for asynchronous '
          'cleanup.',
          element: method,
        );
      }
      states.add(
        _StateDescriptor(
          factoryName: method.name!,
          name: name,
          type: type,
          autoDispose: autoDispose,
          hasDispose: disposeMethod != null,
        ),
      );
    }

    _validateBuildMethod(element, states);

    if (states.isEmpty) {
      return _generateStatelessBase(element, className);
    }
    return _generateStatefulBase(element, className, states);
  }
}

String _generateStatelessBase(ClassElement element, String className) {
  final declaration = _typeParameterDeclaration(element);
  return '''
abstract class _\$$className$declaration extends ObservationStatelessWidget {
  const _\$$className({super.key});
}
''';
}

String _generateStatefulBase(
  ClassElement element,
  String className,
  List<_StateDescriptor> states,
) {
  final declaration = _typeParameterDeclaration(element);
  final arguments = _typeParameterArguments(element);
  final baseType = '_\$$className$arguments';
  final widgetType = '$className$arguments';
  final stateClass = '_\$${className}State';
  final output = StringBuffer()
    ..writeln(
      'abstract class _\$$className$declaration extends StatefulWidget {',
    )
    ..writeln('  const _\$$className({super.key});')
    ..writeln()
    ..writeln('  Widget build(')
    ..writeln('    BuildContext context, {');
  _writeRequiredStates(output, states, indent: '    ');
  output
    ..writeln('  });')
    ..writeln()
    ..writeln(
      '  bool shouldRecreateStates(covariant $baseType oldWidget) => false;',
    )
    ..writeln()
    ..writeln('  void didUpdateStates(')
    ..writeln('    covariant $baseType oldWidget, {');
  _writeRequiredStates(output, states, indent: '    ');
  output
    ..writeln('  }) {}')
    ..writeln()
    ..writeln('  void disposeStates({');
  _writeRequiredStates(output, states, indent: '    ');
  output
    ..writeln('  }) {}')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  State<$widgetType> createState() => $stateClass$arguments();')
    ..writeln('}')
    ..writeln()
    ..writeln(
      'final class $stateClass$declaration extends State<$widgetType> '
      'with ObservationStateMixin<$widgetType> {',
    );

  for (final state in states) {
    output
      ..writeln('  late ${state.type} _${state.name};')
      ..writeln('  bool _has${_upperFirst(state.name)} = false;');
  }
  output
    ..writeln('  bool _statesReady = false;')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  void initState() {')
    ..writeln('    super.initState();')
    ..writeln('    _createStates();')
    ..writeln('  }')
    ..writeln()
    ..writeln('  void _createStates() {')
    ..writeln('    try {');
  for (final state in states) {
    output
      ..writeln('      _${state.name} = widget.${state.factoryName}();')
      ..writeln('      _has${_upperFirst(state.name)} = true;');
  }
  output
    ..writeln('      _statesReady = true;')
    ..writeln('    } catch (error, stackTrace) {')
    ..writeln('      runObservationCallbacks([')
    ..writeln('        () => Error.throwWithStackTrace(error, stackTrace),')
    ..writeln('        _disposeCreatedStates,')
    ..writeln('      ]);')
    ..writeln('    }')
    ..writeln('  }')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  void didUpdateWidget(covariant $widgetType oldWidget) {')
    ..writeln('    super.didUpdateWidget(oldWidget);')
    ..writeln('    if (widget.shouldRecreateStates(oldWidget)) {')
    ..writeln('      stopObservation();')
    ..writeln('      _disposeStates(oldWidget);')
    ..writeln('      _createStates();')
    ..writeln('    } else {')
    ..writeln('      widget.didUpdateStates(')
    ..writeln('        oldWidget,');
  _writeStateArguments(output, states, indent: '        ');
  output
    ..writeln('      );')
    ..writeln('    }')
    ..writeln('  }')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  Widget build(BuildContext context) {')
    ..writeln('    return buildObserved((context) {')
    ..writeln('      return widget.build(')
    ..writeln('        context,');
  _writeStateArguments(output, states, indent: '        ');
  output
    ..writeln('      );')
    ..writeln('    });')
    ..writeln('  }')
    ..writeln()
    ..writeln('  void _disposeStates($widgetType owner) {')
    ..writeln('    if (!_statesReady) return;')
    ..writeln('    _statesReady = false;')
    ..writeln('    runObservationCallbacks([')
    ..writeln('      () => owner.disposeStates(');
  _writeStateArguments(output, states, indent: '        ');
  output
    ..writeln('      ),')
    ..writeln('      _disposeCreatedStates,')
    ..writeln('    ]);')
    ..writeln('  }')
    ..writeln()
    ..writeln('  void _disposeCreatedStates() {')
    ..writeln('    runObservationCallbacks([');
  for (final state in states.reversed) {
    final flag = '_has${_upperFirst(state.name)}';
    output
      ..writeln('      if ($flag) () {')
      ..writeln('        $flag = false;');
    if (state.autoDispose && state.hasDispose) {
      output.writeln('        _${state.name}.dispose();');
    }
    output.writeln('      },');
  }
  output
    ..writeln('    ]);')
    ..writeln('  }')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  void dispose() {')
    ..writeln('    stopObservation();')
    ..writeln('    try {')
    ..writeln('      _disposeStates(widget);')
    ..writeln('    } finally {')
    ..writeln('      super.dispose();')
    ..writeln('    }')
    ..writeln('  }')
    ..writeln('}');
  return output.toString();
}

void _writeRequiredStates(
  StringBuffer output,
  List<_StateDescriptor> states, {
  required String indent,
}) {
  for (final state in states) {
    output.writeln('${indent}required ${state.type} ${state.name},');
  }
}

void _writeStateArguments(
  StringBuffer output,
  List<_StateDescriptor> states, {
  required String indent,
}) {
  for (final state in states) {
    output.writeln('$indent${state.name}: _${state.name},');
  }
}

String _stateName(String methodName) {
  if (methodName.startsWith('create') && methodName.length > 6) {
    return _lowerFirst(methodName.substring(6));
  }
  return methodName;
}

String _lowerFirst(String value) =>
    '${value[0].toLowerCase()}${value.substring(1)}';

String _upperFirst(String value) =>
    '${value[0].toUpperCase()}${value.substring(1)}';

bool _isIdentifier(String value) =>
    RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$').hasMatch(value);

bool _isGeneratedStateName(String value) {
  return _isIdentifier(value) &&
      !Keyword.keywords.containsKey(value) &&
      value != 'context' &&
      value != 'oldWidget';
}

void _validateBuildMethod(ClassElement element, List<_StateDescriptor> states) {
  final build = element.methods.where((method) {
    return method.name == 'build' && !method.isStatic;
  }).firstOrNull;
  if (build == null) {
    throw InvalidGenerationSourceError(
      '${element.name} must declare an instance build() method.',
      element: element,
    );
  }

  final positional = build.formalParameters
      .where((parameter) => !parameter.isNamed)
      .toList();
  if (positional.length != 1 ||
      !positional.single.isRequiredPositional ||
      positional.single.type.getDisplayString() != 'BuildContext') {
    throw InvalidGenerationSourceError(
      'build() must start with exactly one required BuildContext parameter.',
      element: build,
    );
  }

  final named = {
    for (final parameter in build.formalParameters.where(
      (parameter) => parameter.isNamed,
    ))
      parameter.name!: parameter,
  };
  final stateNames = states.map((state) => state.name).toSet();

  for (final state in states) {
    final parameter = named[state.name];
    if (parameter == null) {
      throw InvalidGenerationSourceError(
        'build() must declare `required ${state.type} ${state.name}` for the '
        'matching state factory.',
        element: build,
      );
    }
    if (!parameter.isRequiredNamed) {
      throw InvalidGenerationSourceError(
        'The `${state.name}` build parameter must be required.',
        element: parameter,
      );
    }
    if (parameter.type.getDisplayString() != state.type) {
      throw InvalidGenerationSourceError(
        'The `${state.name}` build parameter must have type ${state.type}, '
        'not ${parameter.type.getDisplayString()}.',
        element: parameter,
      );
    }
  }

  final unexpected = named.keys.where((name) => !stateNames.contains(name));
  if (unexpected.isNotEmpty) {
    throw InvalidGenerationSourceError(
      'The `${unexpected.first}` named build parameter has no matching state '
      'factory.',
      element: named[unexpected.first],
    );
  }
}

bool _isObservableType(DartType type, {bool allowNullable = false}) {
  if (!allowNullable && type.nullabilitySuffix == NullabilitySuffix.question) {
    return false;
  }
  if (_observableObjectChecker.isAssignableFromType(type)) return true;

  // On a clean first build, an @ObservableModel() class can still have an unresolved
  // generated superclass. Accepting the annotation directly avoids requiring
  // users to run the generator twice before the type hierarchy is complete.
  final element = type.element;
  if (element != null &&
      _observableChecker.hasAnnotationOf(element, throwOnUnresolved: false)) {
    return true;
  }

  return type is TypeParameterType &&
      _isObservableType(type.bound, allowNullable: allowNullable);
}

MethodElement? _zeroArgumentDispose(DartType type) {
  if (type is! InterfaceType) return null;

  for (final interface in [type, ...type.allSupertypes]) {
    final method = interface.getMethod('dispose');
    if (method != null && !method.isStatic && method.formalParameters.isEmpty) {
      return method;
    }
  }
  return null;
}

String _typeParameterDeclaration(ClassElement element) {
  if (element.typeParameters.isEmpty) return '';
  final parameters = element.typeParameters.map((parameter) {
    final name = parameter.name!;
    final bound = parameter.bound;
    return bound == null ? name : '$name extends ${bound.getDisplayString()}';
  });
  return '<${parameters.join(', ')}>';
}

String _typeParameterArguments(ClassElement element) {
  if (element.typeParameters.isEmpty) return '';
  return '<${element.typeParameters.map((parameter) => parameter.name).join(', ')}>';
}

final class _StateDescriptor {
  const _StateDescriptor({
    required this.factoryName,
    required this.name,
    required this.type,
    required this.autoDispose,
    required this.hasDispose,
  });

  final String factoryName;
  final String name;
  final String type;
  final bool autoDispose;
  final bool hasDispose;
}
