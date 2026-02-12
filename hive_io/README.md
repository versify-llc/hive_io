# hive_io

Hive is a lightweight and blazing fast key-value database written in pure Dart.

- 🚀 Built for mobile and desktop
- 🔒 Encryption built in
- 🎈 No native dependencies

👉 The original Hive project is abandoned. Hive_IO is a fork (minus web support) to keep everything working with newer versions of Flutter and Dart. I'm not planning to add any new features. Checkout [hive_ce](https://pub.dev/packages/hive_ce) if you're looking for:

- Multi-isolate support
- Web support
- New feature development

## See also

[hive_flutter_io](https://pub.dev/packages/hive_flutter_io) - hive extensions and helpers for flutter

[hive_generator_io](https://pub.dev/packages/hive_generator_io) - generates hive type adapters

## Getting started

Follow this guide to get started with Hive in your Flutter app!

### Install dependencies

Add the `hive_io` packages to your `pubspec.yaml`

```yaml
dependencies:
  hive_io: ^3.2.2
  hive_flutter: ^3.2.2

dev_dependencies:
  hive_generator_io: ^3.2.2
```

### Generate type adapters

Hive supports primitives, lists, maps, and any Dart object you want. However, you will need to generate a type adapter before you can store objects. 

Here is an example:

```dart
@HiveType(typeId: 0)
class Person {

  @HiveField(0)
  int id;

  @HiveField(1)
  String? name;

  @HiveField(2, defaultValue: false)
  bool isVIP;

  Person({
    required this.id, 
    this.name, 
    this.isVIP = false,
  });
}
```

Run `build_runner` to generate Hive types:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Initialize Hive

Initialize hive in the `main` function of your app:

```dart
Future<void> main() async {
  ...

  // Initialize Hive. This MUST be called first.
  await Hive.initFlutter(null);

  // Register all of your type adapters next.
  Hive.registerAdapter(PersonAdapter());

  // Box needs to be opened before you can interact with it.
  await Hive.openBox<Person>('person');

  ...

  runApp(App());
}
```

### Using boxes

You can use a Hive box just like a map. It is not necessary to await Futures.

```dart
final box = Hive.box<Person>('person');

box.put('123', Person(id: '123', name: 'David'));

final person = box.get('123');
```

### Listen to box changes

You can use `ValueListenableBuilder` to listen for changes to a box and then update your widgets.

```dart
import 'package:hive_io/hive_io.dart';
import 'package:hive_flutter_io/hive_flutter_io.dart';

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(),
      builder: (context, box, widget) {
        return Switch(
          value: box.get('darkMode'),
          onChanged: (val) {
            box.put('darkMode', val);
          }
        );
      },
    );
  }
}
```
