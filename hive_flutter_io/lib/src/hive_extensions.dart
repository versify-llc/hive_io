part of '../hive_flutter_io.dart';

/// Flutter extensions for Hive.
extension HiveX on HiveInterface {
  /// Initializes Hive with the path from [getApplicationDocumentsDirectory].
  ///
  /// You can provide a [subDir] where the boxes should be stored.
  Future<void> initFlutter([String? subDir]) async {
    WidgetsFlutterBinding.ensureInitialized();

    String? path;
    final appDir = await getApplicationDocumentsDirectory();
    path = path_helper.join(appDir.path, subDir);

    init(path);
  }
}
