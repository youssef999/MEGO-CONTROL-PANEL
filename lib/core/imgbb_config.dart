/// [ImgBB](https://imgbb.com/) image hosting API key.
///
/// Get a key: https://api.imgbb.com/
///
/// Recommended (no key in source):
/// `flutter run --dart-define=IMGBB_API_KEY=your_key_here`
///
/// For local dev only you may set [_devKey]. Prefer `--dart-define=IMGBB_API_KEY=...`
/// when you do not want the key in source control.
class ImgbbConfig {
  ImgbbConfig._();

  static const String _devKey = 'd2ddffc93cc2910f78901f7d0aedfed0';

  static String get apiKey {
    const fromEnv = String.fromEnvironment('IMGBB_API_KEY');
    if (fromEnv.isNotEmpty) return fromEnv;
    return _devKey;
  }
}
