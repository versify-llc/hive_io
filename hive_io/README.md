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
  hive_io: ^3.3.0
  hive_flutter_io: ^3.3.0

dev_dependencies:
  build_runner: ^2.4.0
  hive_generator_io: ^3.3.0
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

### Pure Dart setup

`hive_io` has no Flutter dependency, so you can use it in a plain Dart app too. Skip `hive_flutter_io` and initialize Hive with a directory of your choice:

```dart
Future<void> main() async {
  // Point Hive at any directory where your boxes should live.
  Hive.init('path/to/hive');

  Hive.registerAdapter(PersonAdapter());

  final box = await Hive.openBox<Person>('person');

  ...
}
```

`Hive.initFlutter(...)` is just a convenience from `hive_flutter_io` that calls `Hive.init` with your app's documents directory.

## Important APIs

### Type adapters

Type adapters teach Hive how to read and write your objects. A few rules are worth knowing up front:

- Every `@HiveType` needs a `typeId` that is **unique** across your app and in the range **0–223**.
- `typeId`s and `@HiveField` indices are written to disk. Once data exists, never reuse or change them. To drop a field, retire its index and don't reuse it.
- Add `defaultValue` to a `@HiveField` so old records stay readable after you introduce a new field.
- Adapters must be registered with `Hive.registerAdapter(...)` **before** you open a box that uses them.

### HiveObjects

If your model extends `HiveObject` (or mixes in `HiveObjectMixin`), each instance remembers the box and key it was stored under. That gives you handy `save()` and `delete()` methods.

```dart
@HiveType(typeId: 0)
class Person extends HiveObject {
  @HiveField(0)
  String? name;

  Person({this.name});
}

final person = Person(name: 'David');
await box.add(person); // stored with an auto-increment key

person.name = 'David B.';
await person.save();   // updates the entry in place

await person.delete(); // removes it from the box
```

### Common box operations

A box behaves a lot like a map. Writes are asynchronous, but the new values are available immediately, so you rarely need to await them.

```dart
box.put('key', value);           // add or update
box.putAll({'a': v1, 'b': v2});  // batch write
final id = await box.add(value); // auto-increment integer key

box.get('key', defaultValue: fallback);
box.getAt(0);                    // by index

box.containsKey('key');
box.keys;                        // all keys (sorted ascending)
box.values;                      // all values
box.length;

box.delete('key');
box.deleteAll(['a', 'b']);
await box.clear();               // remove everything
```

### Encryption 🔒

Hive can transparently encrypt a box with AES-256. Generate a key once, store it somewhere safe (for example `flutter_secure_storage`), and pass a `HiveAesCipher` when you open the box.

```dart
// Generate a secure 256-bit key. Do this once and persist it securely.
final key = Hive.generateSecureKey();

final box = await Hive.openBox<Person>(
  'person',
  encryptionCipher: HiveAesCipher(key),
);
```

Read and write to the box exactly as you normally would — encryption and decryption happen behind the scenes.

### Closing and cleaning up

Boxes stay open until you close them. You usually don't need to close them manually, but it's good practice on shutdown:

```dart
await box.close();             // close a single box
await Hive.close();            // close every open box
```
