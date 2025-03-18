import 'package:analyzer/dart/element/element2.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';

import 'imports.dart';

extension DartTypeX on DartType {
  bool get isDynamic2 {
    return this is DynamicType || this is InvalidType;
  }

  bool get isNullable {
    if (isDynamic2 ||
        isDartCoreNull ||
        nullabilitySuffix == NullabilitySuffix.question) {
      return true;
    }

    final that = this;
    if (that is TypeParameterType) return that.bound.isNullable;

    return false;
  }
}

/// Renders a type based on its string + potential import alias
///
/// PLEXAGON PATCH — reworked so that ANY type alias keeps the name the author
/// wrote, not just a `typedef` over a function type. Upstream special
/// cases `FunctionType` only, so a plain alias — `typedef LayerTimeFrame
/// = BaseLayer_TimeFrame`, as generated for protobuf nested messages —
/// is expanded by `getDisplayString()` to the underlying name, which is
/// then emitted into generated code where it may not even be imported.
/// Verified 2026-08-16: reverting this makes plx_editor-dart generate
/// code with 12 analyzer errors.
String resolveFullTypeStringFrom(LibraryElement2 originLibrary, DartType type) {
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
  final alias = type.alias;
  if (alias != null) {
    final element = alias.element2;
    displayType = buildType(element.name3!, alias.typeArguments);
    libraryId = element.library2.id;
  } else if (type is InterfaceType) {
    final element = type.element3;
    final typeArguments = type.typeArguments;
    // The parameter is a Interface with a Type Argument that is not yet
    // generated. In this case analyzer would set its type to InvalidType
    //
    // For example for:
    // List<ToBeGenerated> values,
    //
    // it would generate:  List<InvalidType>
    // instead of          List<dynamic>
    //
    // This a regression in analyzer 5.13.0
    if (typeArguments.any((e) => e is InvalidType)) {
      final dynamicType = element.library2.typeProvider.dynamicType;
      typeArguments.replaceWhere((t) => t is InvalidType, dynamicType);
    }
    displayType = buildType(element.name3!, typeArguments);
    libraryId = element.library2.id;
  } else {
    displayType = type.getDisplayString();
    libraryId = null;
  }

  final owner = originLibrary.firstFragment.prefixes.firstWhereOrNull((e) {
    return e.imports.any((l) {
      return l.importedLibrary2!.anyTransitiveExport((library) {
        return library.id == libraryId;
      });
    });
  });

  if (owner != null) {
    return '${owner.name3}.$displayType';
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
