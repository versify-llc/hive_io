import 'package:hive_generator_io/src/helpers/type_helper.dart';
import 'package:source_gen/source_gen.dart';
import 'package:source_helper/source_helper.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('constantToString', () {
    test('returns null for null object', () {
      expect(constantToString(null), 'null');
    });

    test('converts string literals', () async {
      final value = await defaultValueFromSource('''
        library example;

        import 'package:hive_io/hive_io.dart';

        class Sample {
          @HiveField(0, defaultValue: 'hello')
          final String value = '';
        }
      ''', 'Sample');

      expect(constantToString(value), "'hello'");
    });

    test('escapes special characters in strings', () async {
      final value = await defaultValueFromSource('''
        library example;

        import 'package:hive_io/hive_io.dart';

        class Sample {
          @HiveField(0, defaultValue: 'line\\nquote"')
          final String value = '';
        }
      ''', 'Sample');

      expect(constantToString(value), escapeDartString('line\nquote"'));
    });

    test('converts bool and num literals', () async {
      final trueValue = await defaultValueFromSource('''
        library example;

        import 'package:hive_io/hive_io.dart';

        class Sample {
          @HiveField(0, defaultValue: true)
          final bool value = false;
        }
      ''', 'Sample');
      final intValue = await defaultValueFromSource('''
        library example;

        import 'package:hive_io/hive_io.dart';

        class Sample {
          @HiveField(0, defaultValue: 42)
          final int value = 0;
        }
      ''', 'Sample');
      final doubleValue = await defaultValueFromSource('''
        library example;

        import 'package:hive_io/hive_io.dart';

        class Sample {
          @HiveField(0, defaultValue: 3.14)
          final double value = 0;
        }
      ''', 'Sample');

      expect(constantToString(trueValue), 'true');
      expect(constantToString(intValue), '42');
      expect(constantToString(doubleValue), '3.14');
    });

    test('converts double special values', () async {
      final nan = await defaultValueFromSource('''
        library example;

        import 'package:hive_io/hive_io.dart';

        class Sample {
          @HiveField(0, defaultValue: double.nan)
          final double value = 0;
        }
      ''', 'Sample');
      final infinity = await defaultValueFromSource('''
        library example;

        import 'package:hive_io/hive_io.dart';

        class Sample {
          @HiveField(0, defaultValue: double.infinity)
          final double value = 0;
        }
      ''', 'Sample');
      final negativeInfinity = await defaultValueFromSource('''
        library example;

        import 'package:hive_io/hive_io.dart';

        class Sample {
          @HiveField(0, defaultValue: double.negativeInfinity)
          final double value = 0;
        }
      ''', 'Sample');

      expect(constantToString(nan), 'double.nan');
      expect(constantToString(infinity), 'double.infinity');
      expect(constantToString(negativeInfinity), 'double.negativeInfinity');
    });

    test('converts list literals', () async {
      final value = await defaultValueFromSource('''
        library example;

        import 'package:hive_io/hive_io.dart';

        class Sample {
          @HiveField(0, defaultValue: <String>['a', 'b'])
          final List<String> value = const [];
        }
      ''', 'Sample');

      expect(constantToString(value), "['a', 'b']");
    });

    test('converts set literals', () async {
      final value = await defaultValueFromSource('''
        library example;

        import 'package:hive_io/hive_io.dart';

        class Sample {
          @HiveField(0, defaultValue: <int>{1, 2})
          final Set<int> value = const {};
        }
      ''', 'Sample');

      expect(constantToString(value), '{1, 2}');
    });

    test('converts map literals', () async {
      final value = await defaultValueFromSource('''
        library example;

        import 'package:hive_io/hive_io.dart';

        class Sample {
          @HiveField(0, defaultValue: <String, int>{'a': 1, 'b': 2})
          final Map<String, int> value = const {};
        }
      ''', 'Sample');

      expect(
        constantToString(value),
        allOf([contains("'a': 1"), contains("'b': 2")]),
      );
    });

    test('converts enum constants', () async {
      final value = await defaultValueFromSource('''
        library example;

        import 'package:hive_io/hive_io.dart';

        enum Color { red, green }

        class Sample {
          @HiveField(0, defaultValue: Color.red)
          final Color value = Color.red;
        }
      ''', 'Sample');

      expect(constantToString(value), 'Color.red');
    });

    test('converts const constructor calls', () async {
      final value = await defaultValueFromSource('''
        library example;

        import 'package:hive_io/hive_io.dart';

        class Point {
          const Point(this.x, this.y);
          final int x;
          final int y;
        }

        class Sample {
          @HiveField(0, defaultValue: Point(1, 2))
          final Point value = const Point(0, 0);
        }
      ''', 'Sample');

      expect(constantToString(value), 'const Point(1, 2)');
    });

    test('rejects unsupported default values', () async {
      final value = await defaultValueFromSource('''
        library example;

        import 'package:hive_io/hive_io.dart';

        class Sample {
          @HiveField(0, defaultValue: #symbol)
          final Symbol value = #other;
        }
      ''', 'Sample');

      expect(
        () => constantToString(value),
        throwsA(isA<InvalidGenerationSourceError>()),
      );
    });
  });
}
