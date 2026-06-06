import 'package:analyzer/dart/element/element.dart';
import 'package:hive_generator_io/src/type_adapter_generator.dart';
import 'package:hive_io/hive_io.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  final generator = TypeAdapterGenerator();

  group('generateName', () {
    test('strips generated prefixes and suffixes', () {
      expect(TypeAdapterGenerator.generateName(r'_$User'), 'UserAdapter');
      expect(
        TypeAdapterGenerator.generateName(r'_$_SomeClass'),
        'SomeClassAdapter',
      );
    });

    test('removes non-alphanumeric characters', () {
      expect(
        TypeAdapterGenerator.generateName(r'_$User$Impl'),
        'UserImplAdapter',
      );
      expect(TypeAdapterGenerator.generateName('Foo.Bar'), 'FooBarAdapter');
    });
  });

  group('getAdapterName', () {
    test('uses generated name when adapterName is omitted', () async {
      final annotation = await hiveTypeAnnotation('''
        library example;

        import 'package:hive_io/hive_io.dart';

        @HiveType(typeId: 1)
        class Person {}
      ''', 'Person');

      expect(
        generator.getAdapterName(r'_$Person', annotation),
        'PersonAdapter',
      );
    });

    test('uses custom adapterName from annotation', () async {
      final annotation = await hiveTypeAnnotation('''
        library example;

        import 'package:hive_io/hive_io.dart';

        @HiveType(typeId: 1, adapterName: 'CustomPersonAdapter')
        class Person {}
      ''', 'Person');

      expect(
        generator.getAdapterName(r'_$Person', annotation),
        'CustomPersonAdapter',
      );
    });
  });

  group('getTypeId', () {
    test('returns typeId from annotation', () async {
      final annotation = await hiveTypeAnnotation('''
        library example;

        import 'package:hive_io/hive_io.dart';

        @HiveType(typeId: 99)
        class Person {}
      ''', 'Person');

      expect(generator.getTypeId(annotation), 99);
    });
  });

  group('getClass', () {
    test('accepts classes and enums', () async {
      await resolveHiveSource(
        '''
        library example;

        import 'package:hive_io/hive_io.dart';

        @HiveType(typeId: 1)
        class Person {}

        @HiveType(typeId: 2)
        enum Status { active }
      ''',
        (resolver) async {
          final library = await findExampleLibrary(resolver);
          final person = library.getClass('Person')!;
          final status = library.getEnum('Status')!;

          expect(generator.getClass(person), isA<InterfaceElement>());
          expect(generator.getClass(status), isA<InterfaceElement>());
        },
      );
    });

    test('rejects non-class elements', () async {
      await resolveHiveSource(
        '''
        library example;

        import 'package:hive_io/hive_io.dart';

        @HiveType(typeId: 1)
        int invalidField = 0;
      ''',
        (resolver) async {
          final field = (await findExampleLibrary(resolver)).topLevelVariables
              .singleWhere((element) => element.name == 'invalidField');

          expect(
            () => generator.getClass(field),
            throwsA(
              'Only classes or enums are allowed to be annotated with @HiveType.',
            ),
          );
        },
      );
    });
  });

  group('verifyFieldIndices', () {
    test('accepts valid unique indices', () async {
      await resolveHiveSource(
        '''
        library example;

        import 'package:hive_io/hive_io.dart';

        @HiveType(typeId: 1)
        class Person {
          @HiveField(0)
          int first = 0;

          @HiveField(255)
          int last = 0;
        }
      ''',
        (resolver) async {
          final library = await findExampleLibrary(resolver);
          final cls = library.getClass('Person')!;
          final accessors = generator.getAccessors(cls, library);

          expect(
            () => generator.verifyFieldIndices(accessors[0]),
            returnsNormally,
          );
          expect(
            () => generator.verifyFieldIndices(accessors[1]),
            returnsNormally,
          );
        },
      );
    });

    test('throws when index is out of range', () async {
      await resolveHiveSource(
        '''
        library example;

        import 'package:hive_io/hive_io.dart';

        @HiveType(typeId: 1)
        class Person {
          @HiveField(256)
          int invalid = 0;
        }
      ''',
        (resolver) async {
          final library = await findExampleLibrary(resolver);
          final cls = library.getClass('Person')!;
          final getters = generator.getAccessors(cls, library)[0];

          expect(
            () => generator.verifyFieldIndices(getters),
            throwsA('Field numbers can only be in the range 0-255.'),
          );
        },
      );
    });

    test('throws when indices are duplicated', () async {
      await resolveHiveSource(
        '''
        library example;

        import 'package:hive_io/hive_io.dart';

        @HiveType(typeId: 1)
        class Person {
          @HiveField(1)
          int first = 0;

          @HiveField(1)
          int second = 0;
        }
      ''',
        (resolver) async {
          final library = await findExampleLibrary(resolver);
          final cls = library.getClass('Person')!;
          final getters = generator.getAccessors(cls, library)[0];

          expect(
            () => generator.verifyFieldIndices(getters),
            throwsA(isA<HiveError>()),
          );
        },
      );
    });
  });
}
