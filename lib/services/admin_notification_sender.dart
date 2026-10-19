import 'package:flutter/foundation.dart';
import '../core/auth_storage.dart';
import 'noti_fcm.dart';
import 'supabase_service.dart';

/// Result of [AdminNotificationSender.send].
class AdminSendResult {
  final bool savedToInbox;
  final bool pushed;
  final bool hadToken;

  const AdminSendResult({
    required this.savedToInbox,
    required this.pushed,
    required this.hadToken,
  });

  bool get ok => savedToInbox && (pushed || !hadToken);

  String get message {
    if (savedToInbox && pushed) return 'Sent: in-app inbox + push notification';
    if (savedToInbox) {
      return hadToken
          ? 'Saved to in-app inbox, push failed'
          : 'Saved to in-app inbox (no device_token for push)';
    }
    return pushed
        ? 'Push sent, but saving to in-app inbox failed'
        : 'Failed to send notification';
  }
}

/// `data.kind` values the apps style differently in the inbox.
class AdminNotificationKind {
  AdminNotificationKind._();

  static const accountApproved = 'account_approved';
  static const accountRejected = 'account_rejected';
  static const accountBlocked = 'account_blocked';
}

/// Every admin notification: save to the recipient's in-app inbox
/// (`app_notifications`), then send the FCM push if there is a token.
class AdminNotificationSender {
  AdminNotificationSender._();

  static final _supabase = SupabaseService();
  static final _fcm = NotificationSenderService();

  /// [recipientType]: user | driver | restaurant.
  /// [kind]: optional [AdminNotificationKind] stored in `data.kind`.
  /// [data]: extra keys merged into the inbox row `data` and the push payload.
  static Future<AdminSendResult> send({
    required String recipientType,
    required String recipientId,
    required String title,
    required String body,
    String? deviceToken,
    String? kind,
    Map<String, dynamic>? data,
  }) async {
    final extra = <String, dynamic>{...?data, if (kind != null) 'kind': kind};
    var saved = false;
    try {
      await _supabase.saveInboxNotifications(
        recipientType: recipientType,
        recipientIds: [recipientId],
        title: title,
        body: body,
        sentBy: AuthStorage.email,
        data: extra,
      );
      saved = true;
    } catch (e) {
      debugPrint('❌ [Inbox] save failed: $e');
    }

    final token = deviceToken?.trim();
    final hasToken = token != null && token.isNotEmpty;
    final pushed = hasToken &&
        await _fcm.sendNotification(
          deviceToken: token,
          title: title,
          body: body,
          data: {
            ...extra,
            'type': 'admin_message',
            'recipient_type': recipientType,
          },
        );

    return AdminSendResult(
      savedToInbox: saved,
      pushed: pushed,
      hadToken: hasToken,
    );
  }
}
