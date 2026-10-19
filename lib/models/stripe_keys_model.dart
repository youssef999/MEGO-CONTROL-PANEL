class StripeKeysModel {
  final int? id;
  final String publishableKey;
  final String secretKey;

  const StripeKeysModel({
    this.id,
    required this.publishableKey,
    required this.secretKey,
  });

  static const publishableColumn = 'Publishable key';
  static const secretColumn = 'Secret key';

  static String? _readKey(Map<String, dynamic> json, List<String> names) {
    for (final name in names) {
      final value = json[name];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  factory StripeKeysModel.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'];
    return StripeKeysModel(
      id: idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw'),
      publishableKey:
          _readKey(json, [
            publishableColumn,
            'publishable_key',
            'publishable key',
            'Publishable Key',
          ]) ??
          '',
      secretKey:
          _readKey(json, [
            secretColumn,
            'secret_key',
            'secret key',
            'Secret Key',
          ]) ??
          '',
    );
  }

  Map<String, dynamic> toTableJson() => {
    publishableColumn: publishableKey.trim(),
    secretColumn: secretKey.trim(),
  };

  bool get hasPublishable => publishableKey.trim().isNotEmpty;
  bool get hasSecret => secretKey.trim().isNotEmpty;

  bool get isLiveMode =>
      publishableKey.startsWith('pk_live_') || secretKey.startsWith('sk_live_');

  bool get isTestMode =>
      publishableKey.startsWith('pk_test_') || secretKey.startsWith('sk_test_');

  String get maskedPublishable => _mask(publishableKey);
  String get maskedSecret => _mask(secretKey);

  static String _mask(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Not set';
    if (trimmed.length <= 8) return '••••••••';
    return '${trimmed.substring(0, 7)}••••${trimmed.substring(trimmed.length - 4)}';
  }
}
