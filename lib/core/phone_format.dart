/// Restaurant phone helpers — same rules as restaurant sign-up in the partner
/// app (`mego_driver_app/lib/features/auth/country_code.dart`).
/// Supports **US (+1)** and **Egypt (+20)**; stored as E.164.

final RegExp _e164 = RegExp(r'^\+[1-9]\d{7,14}$');
final RegExp _usNanp = RegExp(r'^1[2-9]\d{2}[2-9]\d{6}$');
final RegExp _egMobile = RegExp(r'^201[0125]\d{8}$');
final RegExp _egLocal10 = RegExp(r'^1[0125]\d{8}$');
final RegExp _usWithCode = RegExp(r'^1[2-9]\d{9}$');

String _digitsOnly(String input) => input.replaceAll(RegExp(r'\D'), '');

String formatPhoneE164(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return trimmed;
  if (trimmed.startsWith('+')) {
    final d = _digitsOnly(trimmed);
    return d.isEmpty ? trimmed : '+$d';
  }
  final d = _digitsOnly(trimmed);
  if (d.isEmpty) return trimmed;
  if (d.length == 12 && d.startsWith('20')) return '+$d';
  if (d.length == 11 && _usWithCode.hasMatch(d)) return '+$d';
  if (d.startsWith('0') && d.length == 11) {
    final local = d.substring(1);
    if (_egLocal10.hasMatch(local)) return '+20$local';
    if (local.length == 10) return '+1$local';
  }
  if (d.length == 10) {
    return _egLocal10.hasMatch(d) ? '+20$d' : '+1$d';
  }
  if (d.length >= 11 && d.length <= 15) return '+$d';
  return '+1$d';
}

bool isValidPhone(String input) {
  final formatted = formatPhoneE164(input);
  if (!_e164.hasMatch(formatted)) return false;
  final national = formatted.substring(1);
  if (national.startsWith('20')) return _egMobile.hasMatch(national);
  if (national.startsWith('1')) return _usNanp.hasMatch(national);
  return true;
}
