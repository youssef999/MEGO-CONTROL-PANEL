import 'package:flutter/material.dart';
import '../core/money.dart';
import '../models/food_checkout_model.dart';
import '../models/food_complain_model.dart';
import '../models/restaurant_model.dart';
import '../models/user_model.dart';
import '../services/admin_notification_sender.dart';
import '../services/noti_fcm.dart';
import '../services/supabase_service.dart';
import '../widgets/firebase_storage_image.dart';
import 'food_checkout_detail_screen.dart';

class FoodComplainDetailScreen extends StatefulWidget {
  final FoodComplainModel complain;

  const FoodComplainDetailScreen({super.key, required this.complain});

  @override
  State<FoodComplainDetailScreen> createState() =>
      _FoodComplainDetailScreenState();
}

class _FoodComplainDetailScreenState extends State<FoodComplainDetailScreen> {
  final _supabase = SupabaseService();
  final _noti = NotificationSenderService();

  late FoodComplainModel _complain;
  UserModel? _user;
  FoodCheckoutModel? _order;
  RestaurantModel? _restaurant;
  double? _walletTotal;
  bool _loading = true;
  bool _updating = false;
  bool _sendingNoti = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _complain = widget.complain;
    _load();
  }

  String? get _pushToken {
    final fcm = _user?.fcmToken?.trim();
    if (fcm != null && fcm.isNotEmpty) return fcm;
    final device = _user?.deviceToken?.trim();
    if (device != null && device.isNotEmpty) return device;
    return null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = _complain.userId?.trim();
      final userTask = (userId != null && userId.isNotEmpty)
          ? _supabase.getUserById(userId)
          : Future<UserModel?>.value(null);

      final orderTask = (_complain.isOrderType && _complain.orderId != null)
          ? _supabase.getFoodCheckoutById(_complain.orderId!)
          : Future<FoodCheckoutModel?>.value(null);

      final walletTask = (userId != null && userId.isNotEmpty)
          ? _supabase.getUserWalletTotal(userId)
          : Future<double?>.value(null);

      final results = await Future.wait([userTask, orderTask, walletTask]);
      final order = results[1] as FoodCheckoutModel?;
      RestaurantModel? restaurant;
      if (order?.restaurantId != null) {
        restaurant = await _supabase.getRestaurantById(order!.restaurantId!);
      }

      if (!mounted) return;
      setState(() {
        _user = results[0] as UserModel?;
        _order = order;
        _restaurant = restaurant;
        _walletTotal = results[2] as double?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markSolved(bool solved) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2D),
        title: Text(
          solved ? 'Mark as solved?' : 'Reopen complaint?',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          solved
              ? 'This complaint will be marked solved in Supabase.'
              : 'This complaint will be marked as unsolved again.',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  solved ? Colors.green : Colors.orangeAccent,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              solved ? 'Mark solved' : 'Reopen',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _updating = true);
    try {
      await _supabase.updateFoodComplainSolved(
        _complain.id,
        isSolve: solved,
      );
      if (!mounted) return;
      setState(() {
        _complain = _complain.copyWith(isSolve: solved);
        _updating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(solved ? 'Marked as solved' : 'Marked as unsolved'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _updating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendNotification() async {
    final token = _pushToken;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User has no FCM / device token'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final titleCtrl = TextEditingController(
      text: 'Complaint #${_complain.id}',
    );
    final bodyCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2D),
        title: Text(
          'Notify ${_user?.name ?? 'user'}',
          style: const TextStyle(color: Colors.white),
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: bodyCtrl,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx, {
                'title': titleCtrl.text.trim(),
                'body': bodyCtrl.text.trim(),
              });
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      titleCtrl.dispose();
      bodyCtrl.dispose();
    });

    if (result == null || !mounted) return;

    setState(() => _sendingNoti = true);
    final userId = (_complain.userId ?? _user?.id)?.trim() ?? '';
    final AdminSendResult sent;
    if (userId.isEmpty) {
      final ok = await _noti.sendNotification(
        deviceToken: token,
        title: result['title']!,
        body: result['body']!,
        data: {'type': 'admin_message', 'recipient_type': 'user'},
      );
      sent = AdminSendResult(savedToInbox: false, pushed: ok, hadToken: true);
    } else {
      sent = await AdminNotificationSender.send(
        recipientType: 'user',
        recipientId: userId,
        deviceToken: token,
        title: result['title']!,
        body: result['body']!,
      );
    }
    if (!mounted) return;
    setState(() => _sendingNoti = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(sent.message),
        backgroundColor: sent.ok ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _addWalletAmount() async {
    final userId = _complain.userId?.trim();
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No user linked to this complaint'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final amountCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2D),
        title: const Text(
          'Add to wallet',
          style: TextStyle(color: Colors.white),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current balance: ${_walletTotal == null ? '—' : _walletTotal!.toStringAsFixed(2)}',
                style: TextStyle(color: Colors.grey[400]),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  labelStyle: TextStyle(color: Colors.grey),
                  prefixText: '\$ ',
                  prefixStyle: TextStyle(color: Colors.white),
                ),
                validator: (v) {
                  final n = double.tryParse(v?.trim() ?? '');
                  if (n == null || n <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
            ),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx, double.parse(amountCtrl.text.trim()));
            },
            child: const Text(
              'Add',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      amountCtrl.dispose();
    });

    if (amount == null || !mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2D),
        title: const Text(
          'Confirm credit',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Add ${amount.toStringAsFixed(2)} to this user\'s wallet?',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final newTotal = await _supabase.addAmountToUserWallet(userId, amount);
      if (!mounted) return;
      setState(() => _walletTotal = newTotal);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Wallet updated. New balance: ${newTotal.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Complaint #${_complain.id}'),
        actions: [
          if (!_complain.isSolve)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: _updating ? null : () => _markSolved(true),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Mark solved'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.greenAccent,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: _updating ? null : () => _markSolved(false),
                icon: const Icon(Icons.replay_outlined, size: 18),
                label: const Text('Reopen'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orangeAccent,
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _statusBanner(),
                      const SizedBox(height: 16),
                      _complaintCard(),
                      const SizedBox(height: 16),
                      _userCard(),
                      if (_complain.isOrderType) ...[
                        const SizedBox(height: 16),
                        _orderCard(),
                      ],
                      const SizedBox(height: 20),
                      _actionsRow(),
                    ],
                  ),
                ),
    );
  }

  Widget _statusBanner() {
    final solved = _complain.isSolve;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: (solved ? Colors.green : Colors.orange).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (solved ? Colors.green : Colors.orange).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            solved ? Icons.check_circle : Icons.pending_actions,
            color: solved ? Colors.greenAccent : Colors.orangeAccent,
          ),
          const SizedBox(width: 10),
          Text(
            solved ? 'Solved' : 'Unsolved',
            style: TextStyle(
              color: solved ? Colors.greenAccent : Colors.orangeAccent,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const Spacer(),
          Text(
            _complain.formattedCreatedAt,
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _complaintCard() {
    return _section(
      title: 'Complaint',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv('Type', (_complain.type ?? '—').toUpperCase()),
          if (_complain.orderId != null)
            _kv('Order ID', '#${_complain.orderId}'),
          const SizedBox(height: 8),
          Text(
            'Message',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            _complain.message?.trim().isNotEmpty == true
                ? _complain.message!.trim()
                : 'No message',
            style: const TextStyle(color: Colors.white, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _userCard() {
    return _section(
      title: 'User',
      child: _user == null
          ? Text(
              _complain.userId?.isNotEmpty == true
                  ? 'User not found (${_complain.userId})'
                  : 'No user linked',
              style: TextStyle(color: Colors.grey[500]),
            )
          : Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: FirebaseStorageImage.avatar(
                    imageUrl: _user!.profile,
                    label: _user!.name ?? _user!.email,
                    radius: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _user!.name ?? 'Unnamed',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _user!.email ?? '—',
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                      if (_user!.phone != null &&
                          _user!.phone!.trim().isNotEmpty)
                        Text(
                          _user!.phone!,
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        'Wallet: ${_walletTotal == null ? '—' : _walletTotal!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.tealAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _orderCard() {
    return _section(
      title: 'Related order',
      child: _order == null
          ? Text(
              _complain.orderId != null
                  ? 'Order #${_complain.orderId} not found'
                  : 'No order linked',
              style: TextStyle(color: Colors.grey[500]),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('Order', '#${_order!.id}'),
                _kv('Status', _order!.status ?? '—'),
                _kv(
                  'Restaurant',
                  _restaurant?.name ??
                      (_order!.restaurantId?.toString() ?? '—'),
                ),
                _kv('Email', _order!.userEmail ?? '—'),
                _kv('Customer paid', formatMoney(_order!.grandTotal)),
                _kv('Created', _order!.formattedCreatedAt),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              FoodCheckoutDetailScreen(checkout: _order!),
                        ),
                      );
                    },
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open order details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.tealAccent,
                      side: BorderSide(
                        color: Colors.tealAccent.withOpacity(0.4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _actionsRow() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (!_complain.isSolve)
          ElevatedButton.icon(
            onPressed: _updating ? null : () => _markSolved(true),
            icon: _updating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: const Text('Mark solved'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
          ),
        ElevatedButton.icon(
          onPressed: _sendingNoti || _user == null ? null : _sendNotification,
          icon: _sendingNoti
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.notifications_active_outlined),
          label: Text(
            _pushToken == null ? 'No push token' : 'Send notification',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _user == null ? null : _addWalletAmount,
          icon: const Icon(Icons.account_balance_wallet_outlined),
          label: const Text('Add to wallet'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
