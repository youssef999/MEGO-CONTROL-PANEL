import 'package:get_storage/get_storage.dart';

class AuthStorage {
  AuthStorage._();

  static const _boxName = 'mego_auth';
  static const _typeKey = 'auth_session_type';
  static const _restaurantIdKey = 'auth_restaurant_id';
  static const _adminIdKey = 'auth_admin_id';
  static const _emailKey = 'auth_email';
  static const _firebaseImageUrlMigrationDoneKey =
      'firebase_image_url_migration_done_v2';

  static const int superAdminId = 1;
  static const String superAdminEmail = 'realadmin26@gmail.com';

  static const String typeRestaurant = 'restaurant';
  static const String typeAdmin = 'admin';

  static GetStorage? _box;

  static GetStorage get _storage {
    final box = _box;
    if (box == null) {
      throw StateError('AuthStorage.init() must be called before use');
    }
    return box;
  }

  static Future<void> init() async {
    await GetStorage.init(_boxName);
    _box = GetStorage(_boxName);
  }

  static bool get hasSession {
    final type = sessionType;
    if (type == typeRestaurant) return restaurantId != null;
    if (type == typeAdmin) return adminId != null;
    return false;
  }

  static String? get sessionType => _storage.read<String>(_typeKey);

  static String? get email => _storage.read<String>(_emailKey);

  static int? get restaurantId {
    final v = _storage.read(_restaurantIdKey);
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static int? get adminId {
    final v = _storage.read(_adminIdKey);
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static bool get isSuperAdmin {
    if (sessionType != typeAdmin) return false;
    if (adminId == superAdminId) return true;
    final storedEmail = email?.trim().toLowerCase();
    return storedEmail == superAdminEmail;
  }
  static bool get isFirebaseImageUrlMigrationDone =>
      _storage.read<bool>(_firebaseImageUrlMigrationDoneKey) ?? false;

  static Future<void> saveRestaurantSession(int id, {String? email}) async {
    await _storage.write(_typeKey, typeRestaurant);
    await _storage.write(_restaurantIdKey, id);
    await _storage.remove(_adminIdKey);
    if (email != null && email.trim().isNotEmpty) {
      await _storage.write(_emailKey, email.trim());
    }
  }

  static Future<void> saveAdminSession(int adminId, {String? email}) async {
    await _storage.write(_typeKey, typeAdmin);
    await _storage.remove(_restaurantIdKey);
    await _storage.write(_adminIdKey, adminId);
    if (email != null && email.trim().isNotEmpty) {
      await _storage.write(_emailKey, email.trim());
    }
  }

  static Future<void> clear() async {
    await _storage.remove(_typeKey);
    await _storage.remove(_restaurantIdKey);
    await _storage.remove(_adminIdKey);
    await _storage.remove(_emailKey);
  }

  static void markFirebaseImageUrlMigrationDone() {
    _storage.write(_firebaseImageUrlMigrationDoneKey, true);
  }
}
