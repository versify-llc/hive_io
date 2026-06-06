part of 'hive_object.dart';

/// Not part of public API
extension HiveObjectInternal on HiveObjectMixin {
  /// Not part of public API
  @pragma('vm:prefer-inline')
  void init(dynamic key, BoxBase box) {
    if (_box != null) {
      if (_box != box) {
        throw HiveError(
          'The same instance of an HiveObject cannot '
          'be stored in two different boxes.',
        );
      } else if (_key != key) {
        throw HiveError(
          'The same instance of an HiveObject cannot '
          'be stored with two different keys ("$_key" and "$key").',
        );
      }
    }
    _box = box;
    _key = key;
  }

  /// Not part of public API
  void dispose() {
    _box = null;
    _key = null;
  }
}
