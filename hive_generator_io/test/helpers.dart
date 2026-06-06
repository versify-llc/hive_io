import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:hive_io/hive_io.dart';
import 'package:source_gen/source_gen.dart';

/// Finds `@HiveField` annotations on elements in test source.
const hiveFieldChecker = TypeChecker.typeNamed(HiveField);

/// Finds `@HiveType` annotations on elements in test source.
const hiveTypeChecker = TypeChecker.typeNamed(HiveType);

/// Resolves in-memory Dart [source] with the analyzer and runs [action].
///
/// Test sources must declare `library example;` so they can be looked up by
/// [findExampleLibrary]. All package dependencies (including `hive_io`) are
/// read from the filesystem so imports resolve the same way they do in a real
/// build.
Future<T> resolveHiveSource<T>(
  String source,
  Future<T> Function(Resolver resolver) action,
) {
  return resolveSource(source, action, readAllSourcesFromFilesystem: true);
}

/// Returns the `example` library from a resolver produced by [resolveHiveSource].
///
/// Throws if the library is missing, which usually means the test source forgot
/// to include `library example;`.
Future<LibraryElement> findExampleLibrary(Resolver resolver) async {
  final library = await resolver.findLibraryByName('example');
  if (library == null) {
    throw StateError('Could not find library "example".');
  }
  return library;
}

/// Extracts the `defaultValue` from a `@HiveField` on the `value` field of
/// [typeName] in [source].
///
/// Test classes should define a field named `value` with the annotation whose
/// default value needs to be inspected, for example:
///
/// ```dart
/// class Sample {
///   @HiveField(0, defaultValue: 42)
///   final int value = 0;
/// }
/// ```
Future<DartObject?> defaultValueFromSource(String source, String typeName) {
  return resolveHiveSource(source, (resolver) async {
    final cls = (await findExampleLibrary(resolver)).getClass(typeName)!;
    final field = cls.getField('value')!;
    final annotation = hiveFieldChecker.firstAnnotationOfExact(field)!;
    return annotation.getField('defaultValue');
  });
}

/// Returns a [ConstantReader] for the `@HiveType` annotation on [typeName]
/// in [source].
///
/// Used to test generator logic that reads annotation parameters such as
/// `typeId` and `adapterName`.
Future<ConstantReader> hiveTypeAnnotation(String source, String typeName) {
  return resolveHiveSource(source, (resolver) async {
    final element = (await findExampleLibrary(resolver)).getClass(typeName)!;
    return ConstantReader(hiveTypeChecker.firstAnnotationOfExact(element));
  });
}
