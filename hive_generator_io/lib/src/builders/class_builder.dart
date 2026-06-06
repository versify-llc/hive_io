import 'dart:typed_data';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:hive_generator_io/src/builders/builder.dart';
import 'package:hive_generator_io/src/helpers/helpers.dart';
import 'package:source_gen/source_gen.dart';

class ClassBuilder extends Builder {
  ClassBuilder(super.cls, super.getters, super.setters);

  TypeChecker listChecker = const TypeChecker.typeNamed(List);
  TypeChecker mapChecker = const TypeChecker.typeNamed(Map);
  TypeChecker setChecker = const TypeChecker.typeNamed(Set);
  TypeChecker iterableChecker = const TypeChecker.typeNamed(Iterable);
  TypeChecker uint8ListChecker = const TypeChecker.typeNamed(Uint8List);

  @override
  String buildRead() {
    final constr = getConstructor(cls);

    // The remaining fields to initialize.
    final fields = setters.toList();

    // Empty classes
    if (constr.formalParameters.isEmpty && fields.isEmpty) {
      return 'return ${cls.displayName}();';
    }

    final code = StringBuffer();
    code.writeln('''
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++)
        reader.readByte(): reader.read(),
    };
    return ${cls.displayName}(
    ''');

    for (final param in constr.formalParameters) {
      var field = fields.firstWhereOrNull((it) => it.name == param.displayName);
      // Final fields
      field ??= getters.firstWhereOrNull((it) => it.name == param.displayName);

      if (field != null) {
        if (param.isNamed) {
          code.write('${param.displayName}: ');
        }
        code.write(
          _parameterValue(
            param.type,
            'fields[${field.index}]',
            field.defaultValue,
          ),
        );
        code.writeln(',');
        fields.remove(field);
      }
    }

    code.writeln(')');

    // There may still be fields to initialize that were not in the constructor
    // as initializing formals. We do so using cascades.
    for (final field in fields) {
      code.write('..${field.name} = ');
      code.writeln(
        _parameterValue(
          field.type,
          'fields[${field.index}]',
          field.defaultValue,
        ),
      );
    }

    code.writeln(';');

    return code.toString();
  }

  String _parameterValue(
    DartType type,
    String variable,
    DartObject? defaultValue,
  ) {
    final value = _cast(type, variable);
    if (defaultValue?.isNull != false) {
      return value;
    }

    return '$variable == null ? ${constantToString(defaultValue)} : $value';
  }

  String _cast(DartType type, String variable) {
    final suffix = _suffixFromType(type);

    if (iterableChecker.isAssignableFromType(type) && !isUint8List(type)) {
      return '($variable as List$suffix)${_castIterable(type)}';
    } else if (mapChecker.isAssignableFromType(type)) {
      return '($variable as Map$suffix)${_castMap(type)}';
    } else if (type.isDartCoreInt) {
      return '($variable as num$suffix)$suffix.toInt()';
    } else if (type.isDartCoreDouble) {
      return '($variable as num$suffix)$suffix.toDouble()';
    } else {
      return '$variable as ${type.getDisplayString()}';
    }
  }

  bool isMapOrIterable(DartType type) {
    return iterableChecker.isAssignableFromType(type) ||
        mapChecker.isAssignableFromType(type);
  }

  bool isUint8List(DartType type) {
    return uint8ListChecker.isExactlyType(type);
  }

  String _castIterable(DartType type) {
    final paramType = type as ParameterizedType;
    final arg = paramType.typeArguments.first;
    final suffix = _accessorSuffixFromType(type);

    if (isMapOrIterable(arg) && !isUint8List(arg)) {
      var cast = '';
      // Using assignable because List? is not exactly List
      if (listChecker.isAssignableFromType(type)) {
        cast = '.toList()';
        // Using assignable because Set? is not exactly Set
      } else if (setChecker.isAssignableFromType(type)) {
        cast = '.toSet()';
      }

      return '$suffix.map((dynamic e)=> ${_cast(arg, 'e')})$cast';
    } else {
      return '$suffix.cast<${arg.getDisplayString()}>()';
    }
  }

  String _castMap(DartType type) {
    final paramType = type as ParameterizedType;
    final arg1 = paramType.typeArguments[0];
    final arg2 = paramType.typeArguments[1];
    final suffix = _accessorSuffixFromType(type);

    if (isMapOrIterable(arg1) || isMapOrIterable(arg2)) {
      return '$suffix.map((dynamic k, dynamic v)=> '
          'MapEntry(${_cast(arg1, 'k')},${_cast(arg2, 'v')}))';
    } else {
      return '$suffix.cast<${arg1.getDisplayString()}, '
          '${arg2.getDisplayString()}>()';
    }
  }

  @override
  String buildWrite() {
    final code = StringBuffer();
    code.writeln('writer');
    code.writeln('..writeByte(${getters.length})');

    for (final field in getters) {
      final value = _convertIterable(field.type, 'obj.${field.name}');
      code.writeln('''
      ..writeByte(${field.index})
      ..write($value)''');
    }
    code.writeln(';');

    return code.toString();
  }

  String _convertIterable(DartType type, String accessor) {
    if (listChecker.isAssignableFromType(type)) {
      return accessor;
    } else
    // Using assignable because Set? and Iterable? are not exactly Set and
    // Iterable
    if (setChecker.isAssignableFromType(type) ||
        iterableChecker.isAssignableFromType(type)) {
      final suffix = _accessorSuffixFromType(type);
      return '$accessor$suffix.toList()';
    } else {
      return accessor;
    }
  }
}

/// Suffix to use when accessing a field in [type].
/// $variable$suffix.field
String _accessorSuffixFromType(DartType type) {
  if (type.nullabilitySuffix == NullabilitySuffix.star) {
    return '?';
  }
  if (type.nullabilitySuffix == NullabilitySuffix.question) {
    return '?';
  }
  return '';
}

/// Suffix to use when casting a value to [type].
String _suffixFromType(DartType type) {
  return type.nullabilitySuffix == NullabilitySuffix.question ? '?' : '';
}
