import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;
import '../core/res/fcm_keys.dart';

class NotificationSenderService {
  // Firebase Project ID
  static const String _projectId = 'mego-c43a7';

  // FCM endpoint using HTTP v1 API
  static String get _fcmEndpoint =>
      'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';

  /// Get OAuth2 access token using service account credentials
  static Future<String> _getAccessToken() async {
    // Service Account JSON credentials provided by the user
    final serviceAccountJson = fcmServiceAccountKey;

    // Required OAuth2 scopes for FCM
    List<String> scopes = [
      "https://www.googleapis.com/auth/userinfo.email",
      "https://www.googleapis.com/auth/firebase.database",
      "https://www.googleapis.com/auth/firebase.messaging",
    ];

    try {
      // Create HTTP client with service account credentials
      final client = await auth.clientViaServiceAccount(
        auth.ServiceAccountCredentials.fromJson(serviceAccountJson),
        scopes,
      );

      // Obtain access credentials
      final credentials = await auth.obtainAccessCredentialsViaServiceAccount(
        auth.ServiceAccountCredentials.fromJson(serviceAccountJson),
        scopes,
        client,
      );

      client.close();

      debugPrint('✅ [FCM] OAuth2 access token obtained successfully');
      return credentials.accessToken.data;
    } catch (e) {
      debugPrint('💥 [FCM] Error getting access token: $e');
      rethrow;
    }
  }

  /// Send FCM notification to a specific device using HTTP v1 API
  Future<bool> sendNotification({
    required String deviceToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      if (deviceToken.isEmpty) {
        debugPrint('❌ [FCM] Device token is empty');
        return false;
      }

      // Get OAuth2 access token
      final String accessToken = await _getAccessToken();

      // Build FCM v1 message payload
      final Map<String, dynamic> message = {
        "message": {
          "token": deviceToken,
          "notification": {"title": title, "body": body},
          "data": data ?? {},
          "android": {
            "priority": "high",
            "notification": {
              "channel_id": "mego_channel_id",
              "sound": "noti",
              "notification_priority": "PRIORITY_MAX",
              "visibility": "public",
              "default_sound": true,
              "default_vibrate_timings": true,
            },
          },
          "apns": {
            "headers": {"apns-priority": "10"},
            "payload": {
              "aps": {
                "alert": {"title": title, "body": body},
                "sound": "default",
                "badge": 1,
              },
            },
          },
        },
      };

      debugPrint(
        '📤 [FCM] Sending notification to: ${deviceToken.substring(0, 10)}...',
      );

      // Send HTTP request
      final response = await http.post(
        Uri.parse(_fcmEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ [FCM] Notification sent successfully');
        return true;
      } else {
        debugPrint('❌ [FCM] Failed with status: ${response.statusCode}');
        debugPrint('📊 [FCM] Response: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('💥 [FCM] Error sending notification: $e');
      return false;
    }
  }

  /// Sends "new order available" notification to all food drivers (type == 'food').
  Future<void> sendFoodOrderAvailableToDrivers({
    required List<String> deviceTokens,
    required String orderId,
  }) async {
    const title = 'New food order';
    const body =
        'A restaurant has accepted an order and is looking for a driver.';
    final data = {'type': 'food_order_available', 'order_id': orderId};
    for (final token in deviceTokens) {
      if (token.isNotEmpty) {
        await sendNotification(
          deviceToken: token,
          title: title,
          body: body,
          data: data,
        );
      }
    }
  }

  /// Sends "order accepted" notification to user and restaurant when a food driver accepts an order.
  Future<void> sendFoodOrderAcceptedNotifications({
    required String? userDeviceToken,
    required String? restaurantDeviceToken,
    required String orderId,
  }) async {
    const title = 'Order accepted';
    const body = 'A driver has accepted your order and is on the way.';
    const bodyRestaurant =
        'A driver has accepted the order and is heading to your restaurant.';
    if (userDeviceToken != null && userDeviceToken.isNotEmpty) {
      await sendNotification(
        deviceToken: userDeviceToken,
        title: title,
        body: body,
        data: {'type': 'food_order_accepted', 'order_id': orderId},
      );
    }
    if (restaurantDeviceToken != null && restaurantDeviceToken.isNotEmpty) {
      await sendNotification(
        deviceToken: restaurantDeviceToken,
        title: title,
        body: bodyRestaurant,
        data: {'type': 'food_order_accepted', 'order_id': orderId},
      );
    }
  }

  /// Sends status-update notification to both user and restaurant.
  /// [status] must be: at_pickup | at_delivery | delivered
  Future<void> sendFoodOrderStatusNotifications({
    required String? userDeviceToken,
    required String? restaurantDeviceToken,
    required String orderId,
    required String status,
  }) async {
    String title;
    String bodyUser;
    String bodyRestaurant;
    switch (status) {
      case 'at_pickup':
        title = 'Driver at pickup';
        bodyUser =
            'The driver has arrived at the restaurant to pick up your order.';
        bodyRestaurant =
            'The driver has arrived at your restaurant to pick up the order.';
        break;
      case 'at_delivery':
        title = 'Driver on the way';
        bodyUser = 'The driver is on the way to your location with your order.';
        bodyRestaurant = 'The driver is on the way to deliver the order.';
        break;
      case 'delivered':
        title = 'Order delivered';
        bodyUser = 'Your order has been delivered. Thank you!';
        bodyRestaurant = 'The order has been delivered to the customer.';
        break;
      default:
        return;
    }
    final data = {
      'type': 'food_order_status',
      'order_id': orderId,
      'status': status,
    };
    if (userDeviceToken != null && userDeviceToken.isNotEmpty) {
      await sendNotification(
        deviceToken: userDeviceToken,
        title: title,
        body: bodyUser,
        data: data,
      );
    }
    if (restaurantDeviceToken != null && restaurantDeviceToken.isNotEmpty) {
      await sendNotification(
        deviceToken: restaurantDeviceToken,
        title: title,
        body: bodyRestaurant,
        data: data,
      );
    }
  }
}
