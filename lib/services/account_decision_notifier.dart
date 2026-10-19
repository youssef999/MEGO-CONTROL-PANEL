import '../models/driver_model.dart';
import '../models/restaurant_model.dart';
import 'admin_notification_sender.dart';

/// Rejection / block messages for restaurants and drivers (inbox + push).
class AccountDecisionNotifier {
  AccountDecisionNotifier._();

  static const restaurantReasons = [
    'Incomplete restaurant information',
    'Unclear or missing restaurant photos',
    'Menu is empty or incomplete',
    'Invalid contact details',
    'Repeated customer complaints',
  ];

  static const driverReasons = [
    'Missing or unclear documents',
    'Driving licence is expired or unreadable',
    'ID photos do not match the profile',
    'Vehicle does not meet MEGO requirements',
    'Background check not approved',
  ];

  static String? _token(String? device, String? fcm) =>
      (device != null && device.trim().isNotEmpty) ? device : fcm;

  static String _body(String reason) =>
      'Reason: $reason\n\n'
      'Please review the reason above, update your details if needed, '
      'and contact MEGO support if you have any questions.';

  static Future<AdminSendResult> restaurantApproved(RestaurantModel restaurant) {
    final name = restaurant.name?.trim();
    return AdminNotificationSender.send(
      recipientType: 'restaurant',
      recipientId: restaurant.id.toString(),
      title: 'Your restaurant is now live on MEGO 🎉',
      body: '${name == null || name.isEmpty ? 'Your restaurant' : name} '
          'has been approved and activated.\n\n'
          'You can now open your dashboard, keep your menu up to date and '
          'start receiving orders. Welcome to MEGO!',
      deviceToken: _token(restaurant.deviceToken, restaurant.fcmToken),
      kind: AdminNotificationKind.accountApproved,
    );
  }

  static Future<AdminSendResult> driverApproved(DriverModel driver) {
    final name = driver.name?.trim();
    return AdminNotificationSender.send(
      recipientType: 'driver',
      recipientId: driver.id,
      title: 'Your driver account is activated 🎉',
      body: '${name == null || name.isEmpty ? 'Hi' : 'Hi $name'}, '
          'your documents have been reviewed and your account is now active.\n\n'
          'Go online to start receiving requests. Drive safe, and welcome to MEGO!',
      deviceToken: _token(driver.deviceToken, driver.fcmToken),
      kind: AdminNotificationKind.accountApproved,
    );
  }

  /// [blocked]: account was active and is now blocked; otherwise the
  /// pending application was rejected.
  static Future<AdminSendResult> restaurant(
    RestaurantModel restaurant, {
    required String reason,
    required bool blocked,
  }) {
    return AdminNotificationSender.send(
      recipientType: 'restaurant',
      recipientId: restaurant.id.toString(),
      title: blocked
          ? 'Your restaurant has been suspended'
          : 'Restaurant application not approved',
      body: _body(reason),
      deviceToken: _token(restaurant.deviceToken, restaurant.fcmToken),
      kind: blocked
          ? AdminNotificationKind.accountBlocked
          : AdminNotificationKind.accountRejected,
      data: {'reason': reason},
    );
  }

  static Future<AdminSendResult> driver(
    DriverModel driver, {
    required String reason,
    required bool blocked,
  }) {
    return AdminNotificationSender.send(
      recipientType: 'driver',
      recipientId: driver.id,
      title: blocked
          ? 'Your driver account has been deactivated'
          : 'Driver application not approved',
      body: _body(reason),
      deviceToken: _token(driver.deviceToken, driver.fcmToken),
      kind: blocked
          ? AdminNotificationKind.accountBlocked
          : AdminNotificationKind.accountRejected,
      data: {'reason': reason},
    );
  }
}
