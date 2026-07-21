import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:flutter_observation/annotations.dart';
import 'package:source_gen/source_gen.dart';

const _ignoredChecker = TypeChecker.typeNamed(
  ObservationIgnored,
  inPackage: 'flutter_observation',
);
const _readOnlyChecker = TypeChecker.typeNamed(
  ObservationReadOnly,
  inPackage: 'flutter_observation',
);
const _alwaysNotifyChecker = TypeChecker.typeNamed(
  ObservationAlwaysNotify,
  inPackage: 'flutter_observation',
);

final class ObservableGenerator
    extends GeneratorForAnnotation<ObservableModel> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@ObservableModel() can only be used on a class.',
        element: element,
      );
    }
    if (element.isAbstract) {
      throw InvalidGenerationSourceError(
        '@ObservableModel() classes must be concrete and extend the generated '
        'base class.',
        element: element,
      );
    }
    final className = element.name;
    if (className == null) {
      throw InvalidGenerationSourceError(
        'The observable class must have a name.',
        element: element,
      );
    }

    final constructor = element.constructors.where((constructor) {
      return constructor.isGenerative && constructor.name == 'new';
    }).firstOrNull;
    if (constructor == null) {
      throw InvalidGenerationSourceError(
        '$className must declare an unnamed generative constructor.',
        element: element,
      );
    }

    final parameters = constructor.formalParameters;
    if (parameters.isEmpty) {
      throw InvalidGenerationSourceError(
        'The observable constructor must declare at least one property parameter.',
        element: constructor,
      );
    }
    if (parameters.any((parameter) => !parameter.isNamed)) {
      throw InvalidGenerationSourceError(
        'The observable constructor must use named parameters only.',
        element: constructor,
      );
    }
    final implicitSuperParameter = parameters
        .whereType<SuperFormalParameterElement>()
        .where((parameter) => parameter.hasImplicitType)
        .firstOrNull;
    if (implicitSuperParameter != null) {
      final name = implicitSuperParameter.name ?? 'property';
      throw InvalidGenerationSourceError(
        'Observable model super parameters must declare an explicit type so '
        'properties can be generated on a clean first build. Write '
        '`Type super.$name`.',
        element: implicitSuperParameter,
      );
    }
    final parameterNames = parameters
        .map((parameter) => parameter.name)
        .toSet();
    final duplicateProperties = element.fields.where((field) {
      return !field.isStatic && parameterNames.contains(field.name);
    }).toList();
    if (duplicateProperties.isNotEmpty) {
      throw InvalidGenerationSourceError(
        'Do not redeclare observable properties in the class body. '
        '`${duplicateProperties.first.name}` is already defined by the '
        'constructor parameter and generated base class.',
        element: duplicateProperties.first,
      );
    }

    for (final parameter in parameters) {
      final ignored = _ignoredChecker.hasAnnotationOf(parameter);
      final readOnly = _readOnlyChecker.hasAnnotationOf(parameter);
      final alwaysNotify = _alwaysNotifyChecker.hasAnnotationOf(parameter);
      if (alwaysNotify && (ignored || readOnly)) {
        throw InvalidGenerationSourceError(
          '@ObservationAlwaysNotify() cannot be combined with '
          '@ObservationIgnored() or @ObservationReadOnly().',
          element: parameter,
        );
      }
    }

    final usesSuperParameters = parameters.any(
      (parameter) => parameter is SuperFormalParameterElement,
    );
    final output = StringBuffer()
      ..writeln(
        'abstract class _\$$className${_typeParameterDeclaration(element)} '
        'with ObservableModelMixin {',
      );
    if (usesSuperParameters) {
      output.writeln('  _\$$className({');
      for (final parameter in parameters) {
        output.writeln('    required ${_parameterSource(parameter)},');
      }
      output.writeln('  })');
    } else {
      output.write('  _\$$className(');
      for (final parameter in parameters) {
        output
          ..write(_parameterSource(parameter))
          ..write(',');
      }
      output.writeln(')');
    }
    output.write('      : ');
    for (var index = 0; index < parameters.length; index++) {
      final parameter = parameters[index];
      if (index > 0) output.write(', ');
      output.write('_${parameter.name} = ${parameter.name}');
    }
    final observedParameters = parameters
        .where((parameter) => !_ignoredChecker.hasAnnotationOf(parameter))
        .toList(growable: false);
    if (observedParameters.isEmpty) {
      output.writeln(';');
    } else {
      output
        ..writeln(' {')
        ..writeln('    if (!ObservationDebug.isReleaseMode) {');
      for (final parameter in observedParameters) {
        final name = parameter.name!;
        output.writeln(
          '      observationRegisterDebugProperty(_${name}Key, () => _$name);',
        );
      }
      output
        ..writeln('    }')
        ..writeln('  }');
    }

    for (final parameter in parameters) {
      final name = parameter.name!;
      final type = parameter.type.getDisplayString();
      final ignored = _ignoredChecker.hasAnnotationOf(parameter);
      final readOnly = _readOnlyChecker.hasAnnotationOf(parameter);
      final alwaysNotify = _alwaysNotifyChecker.hasAnnotationOf(parameter);

      if (!ignored) {
        output.writeln(
          "  final ObservationKey<$type> _${name}Key = "
          "ObservationKey<$type>('$className.$name');",
        );
      }
      output
        ..writeln('  ${readOnly ? 'final ' : ''}$type _$name;')
        ..writeln()
        ..writeln('  $type get $name {');
      if (!ignored) {
        output.writeln('    observationAccess(_${name}Key);');
      }
      output
        ..writeln('    return _$name;')
        ..writeln('  }');

      if (!readOnly) {
        output
          ..writeln()
          ..writeln('  set $name($type value) {');
        if (!alwaysNotify) {
          output.writeln('    if (_$name == value) return;');
        }
        if (ignored) {
          output.writeln('    _$name = value;');
        } else {
          output
            ..writeln('    observationMutation(_${name}Key, () {')
            ..writeln('      _$name = value;')
            ..writeln('    });');
        }
        output.writeln('  }');
      }
      output.writeln();
    }
    output.writeln('}');
    return output.toString();
  }
}

String _parameterSource(FormalParameterElement parameter) {
  return '${parameter.type.getDisplayString()} ${parameter.name}';
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
