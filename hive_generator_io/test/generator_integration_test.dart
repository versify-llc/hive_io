import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:hive_generator_io/hive_generator_io.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

const _pkg = 'test_pkg';

Future<void> _runGeneratorTest({
  required String inputPath,
  required String inputSource,
  required Matcher outputMatcher,
}) async {
  final readerWriter = TestReaderWriter(rootPackage: _pkg);
  await readerWriter.testing.loadIsolateSources();

  await testBuilder(
    getBuilder(BuilderOptions.empty),
    {'$_pkg|lib/$inputPath': inputSource},
    readerWriter: readerWriter,
    outputs: {
      '$_pkg|lib/${inputPath.replaceAll('.dart', '.hive_generator_io.g.part')}':
          decodedMatches(outputMatcher),
    },
  );
}

Future<List<String>> _runGeneratorErrorTest({
  required String inputPath,
  required String inputSource,
}) async {
  final readerWriter = TestReaderWriter(rootPackage: _pkg);
  await readerWriter.testing.loadIsolateSources();
  final logs = <String>[];

  await testBuilder(
    getBuilder(BuilderOptions.empty),
    {'$_pkg|lib/$inputPath': inputSource},
    readerWriter: readerWriter,
    onLog: (record) {
      if (record.level >= Level.SEVERE) {
        logs.add(record.message);
      }
    },
  );

  return logs;
}

void main() {
  test('generates class adapter with read and write', () async {
    await _runGeneratorTest(
      inputPath: 'user.dart',
      inputSource: '''
import 'package:hive_io/hive_io.dart';

part 'user.hive_generator_io.g.part';

@HiveType(typeId: 1)
class User {
  User({required this.name, this.age = 0});

  @HiveField(0)
  final String name;

  @HiveField(1)
  int age;
}
''',
      outputMatcher: allOf([
        contains('class UserAdapter extends TypeAdapter<User>'),
        contains('final int typeId = 1'),
        contains('reader.readByte()'),
        contains('return User('),
        contains('name: fields[0] as String'),
        contains('age: (fields[1] as num).toInt()'),
        contains('..writeByte(2)'),
        contains('..writeByte(0)'),
        contains('..write(obj.name)'),
        contains('..writeByte(1)'),
        contains('..write(obj.age)'),
      ]),
    );
  });

  test('generates enum adapter with default case', () async {
    await _runGeneratorTest(
      inputPath: 'theme.dart',
      inputSource: '''
import 'package:hive_io/hive_io.dart';

part 'theme.hive_generator_io.g.part';

@HiveType(typeId: 2)
enum ThemeMode {
  @HiveField(0)
  light,

  @HiveField(1, defaultValue: true)
  dark,
}
''',
      outputMatcher: allOf([
        contains('class ThemeModeAdapter extends TypeAdapter<ThemeMode>'),
        contains('case 0:'),
        contains('return ThemeMode.light'),
        contains('case 1:'),
        contains('return ThemeMode.dark'),
        contains('default:'),
        contains('return ThemeMode.dark'),
        contains('case ThemeMode.light:'),
        contains('writer.writeByte(0)'),
        contains('case ThemeMode.dark:'),
        contains('writer.writeByte(1)'),
      ]),
    );
  });

  test('uses custom adapterName from annotation', () async {
    await _runGeneratorTest(
      inputPath: 'item.dart',
      inputSource: '''
import 'package:hive_io/hive_io.dart';

part 'item.hive_generator_io.g.part';

@HiveType(typeId: 3, adapterName: 'MyItemAdapter')
class Item {
  @HiveField(0)
  int id = 0;
}
''',
      outputMatcher: contains('class MyItemAdapter extends TypeAdapter<Item>'),
    );
  });

  test('generates adapter with default field values', () async {
    await _runGeneratorTest(
      inputPath: 'settings.dart',
      inputSource: '''
import 'package:hive_io/hive_io.dart';

part 'settings.hive_generator_io.g.part';

@HiveType(typeId: 4)
class Settings {
  Settings({required this.enabled, required this.count});

  @HiveField(0, defaultValue: true)
  bool enabled;

  @HiveField(1, defaultValue: 42)
  int count;
}
''',
      outputMatcher: allOf([
        contains('fields[0] == null ? true : fields[0] as bool'),
        contains('fields[1] == null ? 42 : (fields[1] as num).toInt()'),
      ]),
    );
  });

  test('generates adapter for List and Map fields', () async {
    await _runGeneratorTest(
      inputPath: 'container.dart',
      inputSource: '''
import 'package:hive_io/hive_io.dart';

part 'container.hive_generator_io.g.part';

@HiveType(typeId: 6)
class Container {
  Container({required this.tags, required this.meta});

  @HiveField(0)
  List<String> tags;

  @HiveField(1)
  Map<String, int> meta;
}
''',
      outputMatcher: allOf([
        contains('tags: (fields[0] as List).cast<String>()'),
        contains('meta: (fields[1] as Map).cast<String, int>()'),
      ]),
    );
  });

  test('reports duplicate field indices', () async {
    final logs = await _runGeneratorErrorTest(
      inputPath: 'duplicate.dart',
      inputSource: '''
import 'package:hive_io/hive_io.dart';

part 'duplicate.hive_generator_io.g.part';

@HiveType(typeId: 7)
class Duplicate {
  @HiveField(0)
  int first = 0;

  @HiveField(0)
  int second = 0;
}
''',
    );

    expect(logs.join('\n'), contains('Duplicate field number: 0'));
  });
}
