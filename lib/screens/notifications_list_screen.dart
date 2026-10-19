import 'dart:math';

import 'package:flutter/material.dart';
import '../core/auth_storage.dart';
import '../models/user_model.dart';
import '../models/driver_model.dart';
import '../models/restaurant_model.dart';
import '../services/supabase_service.dart';
import '../services/noti_fcm.dart';
import '../widgets/custom_drawer.dart';

class NotificationsListScreen extends StatefulWidget {
  const NotificationsListScreen({super.key});

  @override
  State<NotificationsListScreen> createState() =>
      _NotificationsListScreenState();
}

class _NotificationsListScreenState extends State<NotificationsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseService _supabaseService = SupabaseService();
  final NotificationSenderService _notiService = NotificationSenderService();

  List<UserModel> _users = [];
  List<DriverModel> _drivers = [];
  List<RestaurantModel> _restaurants = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  /// FCM send target: prefer `device_token`, then `fcm_token` (legacy).
  static String? _pushTokenFor(Object entity) {
    if (entity is UserModel) {
      return _firstNonBlank(entity.deviceToken, entity.fcmToken);
    }
    if (entity is DriverModel) {
      return _firstNonBlank(entity.deviceToken, entity.fcmToken);
    }
    if (entity is RestaurantModel) {
      return _firstNonBlank(entity.deviceToken, entity.fcmToken);
    }
    return null;
  }

  /// `app_notifications.recipient_type` for [entity].
  static String _recipientTypeFor(Object entity) {
    if (entity is DriverModel) return 'driver';
    if (entity is RestaurantModel) return 'restaurant';
    return 'user';
  }

  static String _recipientIdFor(dynamic entity) => entity.id.toString();

  static String _newBatchId() {
    final rnd = Random.secure();
    final b = List<int>.generate(16, (_) => rnd.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }

  /// Lets the apps open the right inbox when the push is tapped.
  static Map<String, dynamic> _pushDataFor(Object entity) => {
    'type': 'admin_message',
    'recipient_type': _recipientTypeFor(entity),
  };

  static String? _firstNonBlank(String? a, String? b) {
    final x = a?.trim();
    if (x != null && x.isNotEmpty) return x;
    final y = b?.trim();
    if (y != null && y.isNotEmpty) return y;
    return null;
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _supabaseService.getUsers(),
        _supabaseService.getDrivers(),
        _supabaseService.getRestaurants(),
      ]);
      setState(() {
        _users = results[0] as List<UserModel>;
        _drivers = results[1] as List<DriverModel>;
        _restaurants = results[2] as List<RestaurantModel>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        title: const Text('Notifications Management'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.deepPurpleAccent,
          tabs: const [
            Tab(text: 'Users'),
            Tab(text: 'Drivers'),
            Tab(text: 'Restaurants'),
          ],
        ),
      ),
      drawer: const CustomDrawer(activeItem: 'Notifications'),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Text(
                  'Error: $_error',
                  style: const TextStyle(color: Colors.red),
                ),
              )
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildEntityList(_users, 'user'),
                  _buildEntityList(_drivers, 'driver'),
                  _buildEntityList(_restaurants, 'restaurant'),
                ],
              ),
    );
  }

  Widget _buildEntityList(List<dynamic> entities, String type) {
    if (entities.isEmpty) {
      return const Center(
        child: Text('No entries found.', style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () => _showNotificationDialog(entities: entities),
            icon: const Icon(Icons.send_outlined),
            label: Text('Send to All ${type}s'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurpleAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: entities.length,
            itemBuilder: (context, index) {
              final entity = entities[index];
              final String name = entity.name ?? 'Unknown';
              final String? token = _pushTokenFor(entity);

              return Card(
                color: const Color(0xFF1A1D2D),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  title: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    token != null
                        ? 'device_token: ${token.length > 14 ? "${token.substring(0, 10)}…" : token}'
                        : 'No device_token — in-app inbox only',
                    style: TextStyle(
                      color: token != null ? Colors.grey : Colors.orangeAccent,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.message_outlined,
                      color: Colors.blueAccent,
                    ),
                    onPressed: () => _showNotificationDialog(entity: entity),
                    tooltip:
                        token != null
                            ? 'Send push + in-app notification'
                            : 'Send in-app notification (no device_token)',
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showNotificationDialog({
    dynamic entity,
    List<dynamic>? entities,
  }) async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final bool isMass = entities != null;

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1D2D),
            title: Text(
              isMass ? 'Send Group Notification' : 'Send to ${entity.name}',
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      labelStyle: TextStyle(color: Colors.grey),
                    ),
                    validator:
                        (v) =>
                            v == null || v.isEmpty ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: bodyController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Message Body',
                      labelStyle: TextStyle(color: Colors.grey),
                    ),
                    validator:
                        (v) =>
                            v == null || v.isEmpty ? 'Body is required' : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final title = titleController.text;
                    final body = bodyController.text;
                    Navigator.pop(context);

                    if (isMass) {
                      _sendMassNotification(entities, title, body);
                    } else {
                      _sendIndividualNotification(entity, title, body);
                    }
                  }
                },
                child: const Text('Send'),
              ),
            ],
          ),
    );
  }

  Future<void> _sendIndividualNotification(
    dynamic entity,
    String title,
    String body,
  ) async {
    var savedInbox = false;
    try {
      await _supabaseService.saveInboxNotifications(
        recipientType: _recipientTypeFor(entity),
        recipientIds: [_recipientIdFor(entity)],
        title: title,
        body: body,
        sentBy: AuthStorage.email,
      );
      savedInbox = true;
    } catch (e) {
      debugPrint('❌ [Inbox] save failed: $e');
    }

    final token = _pushTokenFor(entity);
    final pushed = token != null &&
        await _notiService.sendNotification(
          deviceToken: token,
          title: title,
          body: body,
          data: _pushDataFor(entity),
        );

    if (mounted) {
      final String message;
      if (savedInbox && pushed) {
        message = 'Sent: in-app inbox + push notification';
      } else if (savedInbox) {
        message = token == null
            ? 'Saved to in-app inbox (no device_token for push)'
            : 'Saved to in-app inbox, push failed';
      } else {
        message = pushed
            ? 'Push sent, but saving to in-app inbox failed'
            : 'Failed to send notification';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: savedInbox && (pushed || token == null)
              ? Colors.green
              : (savedInbox || pushed ? Colors.orange : Colors.red),
        ),
      );
    }
  }

  Future<void> _sendMassNotification(
    List<dynamic> entities,
    String title,
    String body,
  ) async {
    int successCount = 0;
    int failCount = 0;
    String? inboxError;

    if (entities.isNotEmpty) {
      try {
        await _supabaseService.saveInboxNotifications(
          recipientType: _recipientTypeFor(entities.first),
          recipientIds: entities.map(_recipientIdFor).toList(),
          title: title,
          body: body,
          batchId: _newBatchId(),
          sentBy: AuthStorage.email,
        );
      } catch (e) {
        inboxError = '$e';
        debugPrint('❌ [Inbox] bulk save failed: $e');
      }
    }

    // We can run these in parallel, but with caution on rate limits if many
    for (var entity in entities) {
      final token = _pushTokenFor(entity);
      if (token != null) {
        final success = await _notiService.sendNotification(
          deviceToken: token,
          title: title,
          body: body,
          data: _pushDataFor(entity),
        );
        if (success)
          successCount++;
        else
          failCount++;
      }
    }

    if (mounted) {
      final inboxText = inboxError == null
          ? 'In-app inbox: ${entities.length}'
          : 'In-app inbox FAILED';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bulk send complete! $inboxText · Push success: $successCount, failed: $failCount',
          ),
          backgroundColor: failCount == 0 && inboxError == null
              ? Colors.green
              : Colors.orange,
        ),
      );
    }
  }
}
