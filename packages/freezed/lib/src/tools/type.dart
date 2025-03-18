import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';

import 'imports.dart';

extension DartTypeX on DartType {
  bool get isDynamic2 {
    return this is DynamicType || this is InvalidType;
  }

  bool get isNullable {
    if (isDynamic2 || nullabilitySuffix == NullabilitySuffix.question) {
      return true;
    }

    final that = this;
    if (that is TypeParameterType) return that.bound.isNullable;

    return false;
  }
}

/// Renders a type based on its string + potential import alias
String resolveFullTypeStringFrom(LibraryElement originLibrary, DartType type) {
  String buildType(String name, List<DartType> typeArguments) {
    if (typeArguments.isNotEmpty) {
      name += '<${typeArguments.map(
            (t) => resolveFullTypeStringFrom(
              originLibrary,
              t,
            ),
          ).join(', ')}>';
    }
    if (type.nullabilitySuffix == NullabilitySuffix.question) {
      name += '?';
    }

    return name;
  }

  final String displayType;
  final int? libraryId;
  if (type.alias?.element != null) {
    final alias = type.alias!;
    final element = alias.element;
    displayType = buildType(element.name, alias.typeArguments);
    libraryId = element.library.id;
  } else if (type is InterfaceType) {
    final element = type.element;
    final typeArguments = type.typeArguments;
    // The parameter is a Interface with a Type Argument that is not yet generated
    // In this case analyzer would set its type to InvalidType
    //
    // For example for:
    // List<ToBeGenerated> values,
    //
    // it would generate:  List<InvalidType>
    // instead of          List<dynamic>
    //
    // This a regression in analyzer 5.13.0
    if (typeArguments.any((e) => e is InvalidType)) {
      final dynamicType = type.element.library.typeProvider.dynamicType;
      typeArguments.replaceWhere((t) => t is InvalidType, dynamicType);
    }
    displayType = buildType(element.name, typeArguments);
    libraryId = element.library.id;
  } else {
    displayType = type.getDisplayString();
    libraryId = null;
  }

  final owner = originLibrary.units
      .expand((e) => e.libraryImportPrefixes)
      .firstWhereOrNull((e) {
    return e.imports.any((l) {
        return l.importedLibrary!.anyTransitiveExport((library) {
          return library.id == libraryId;
        });
      });
  });

  if (owner != null) {
    return '${owner.name}.$displayType';
  }

  return displayType;
}

extension ReplaceWhereExtension<T> on List<T> {
  void replaceWhere(bool Function(T element) test, T replacement) {
    for (var index = 0; index < length; index++) {
      if (test(this[index])) {
        this[index] = replacement;
      }
    }
  }
}
