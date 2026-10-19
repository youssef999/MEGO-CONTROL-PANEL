import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/money.dart';
import '../models/user_model.dart';
import '../models/ride_model.dart';
import '../models/food_checkout_model.dart';
import '../models/restaurant_model.dart';
import '../models/user_food_location_model.dart';
import '../models/driver_model.dart';
import '../models/cart_item_model.dart';
import '../models/ride_request_model.dart';
import '../services/admin_notification_sender.dart';
import '../services/supabase_service.dart';
import '../widgets/firebase_storage_image.dart';

class UserDetailScreen extends StatefulWidget {
  final UserModel user;

  const UserDetailScreen({super.key, required this.user});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService();
  late TabController _tabController;

  List<RideModel> _rides = [];
  List<FoodCheckoutModel> _foodOrders = [];
  Map<int, RestaurantModel> _restaurantsMap = {};
  Map<int, UserFoodLocationModel> _foodLocationsMap = {};
  Map<String, DriverModel> _driversMap = {};
  Map<int, List<CartItemModel>> _cartItemsByCartId = {};
  Map<String, RideRequestModel> _rideRequestsById = {};
  bool _isLoading = true;
  String? _error;
  bool _sendingNoti = false;

  String? get _userPushToken {
    final device = widget.user.deviceToken?.trim();
    if (device != null && device.isNotEmpty) return device;
    final fcm = widget.user.fcmToken?.trim();
    if (fcm != null && fcm.isNotEmpty) return fcm;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final rides = await _supabaseService.getRidesByRiderId(widget.user.id);
      final rideRequestIds = rides
          .map((r) => r.rideRequestId?.trim())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final rideRequests =
          await _supabaseService.getRideRequestsByIds(rideRequestIds);
      final orders = widget.user.email != null && widget.user.email!.isNotEmpty
          ? await _supabaseService.getFoodCheckoutsByUserEmail(widget.user.email!)
          : <FoodCheckoutModel>[];
      final restaurants = await _supabaseService.getRestaurants();
      final locationIds = orders
          .map((o) => o.locationId)
          .whereType<int>()
          .toSet()
          .toList();
      final locations = await _supabaseService.getUserFoodLocationsByIds(locationIds);
      final driverIds = <String>{};
      for (final o in orders) {
        final id = o.driverId?.trim();
        if (id != null && id.isNotEmpty) driverIds.add(id);
      }
      for (final r in rides) {
        final id = r.driverId?.trim();
        if (id != null && id.isNotEmpty) driverIds.add(id);
      }
      final drivers = await _supabaseService.getDriversByIds(driverIds.toList());
      final cartIds = orders
          .map((o) => o.cartId)
          .whereType<int>()
          .toSet()
          .toList();
      final cartItems = await _supabaseService.getCartItemsByCartIds(cartIds);
      final resMap = {for (var r in restaurants) r.id: r};
      final locationMap = {for (var l in locations) l.id: l};
      final driversMap = {for (var d in drivers) d.id: d};
      final rideReqMap = {for (final rr in rideRequests) rr.id: rr};
      final cartItemsMap = <int, List<CartItemModel>>{};
      for (final item in cartItems) {
        final key = item.cartId;
        if (key == null) continue;
        cartItemsMap.putIfAbsent(key, () => []).add(item);
      }
      setState(() {
        _rides = rides;
        _foodOrders = orders;
        _restaurantsMap = resMap;
        _foodLocationsMap = locationMap;
        _driversMap = driversMap;
        _rideRequestsById = rideReqMap;
        _cartItemsByCartId = cartItemsMap;
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          widget.user.name ?? 'User Details',
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        actions: [
          if (_userPushToken != null)
            IconButton(
              onPressed: _sendingNoti ? null : _showSendNotificationDialog,
              icon: _sendingNoti
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.notifications_active_outlined,
                      color: Colors.blueAccent),
              tooltip: 'Send notification',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.deepPurpleAccent,
          labelColor: Colors.deepPurpleAccent,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Analysis'),
            Tab(text: 'Rides'),
            Tab(text: 'Food Orders'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAnalysisTab(),
                    _buildRidesTab(),
                    _buildFoodOrdersTab(),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text('$_error', textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _fetchData, child: const Text('Retry')),
        ],
      ),
    );
  }

  Future<void> _showSendNotificationDialog() async {
    final token = _userPushToken;
    if (token == null) return;

    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2D),
        title: Text('Send notification to ${widget.user.name ?? 'user'}'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
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
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: bodyController,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    labelStyle: TextStyle(color: Colors.grey),
                    hintText: 'Enter notification message',
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Message is required' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context, {
                'title': titleController.text.trim(),
                'body': bodyController.text.trim(),
              });
            },
            child: const Text('Send', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      titleController.dispose();
      bodyController.dispose();
    });

    if (result == null || !mounted) return;

    setState(() => _sendingNoti = true);
    final sent = await AdminNotificationSender.send(
      recipientType: 'user',
      recipientId: widget.user.id,
      deviceToken: token,
      title: result['title']!,
      body: result['body']!,
    );
    if (!mounted) return;
    setState(() => _sendingNoti = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(sent.message),
        backgroundColor: sent.ok ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _buildAnalysisTab() {
    final completedRides = _rides.where((r) => r.isCompleted).toList();
    final totalRideSpend =
        completedRides.fold<double>(0, (sum, r) => sum + r.riderPaid);
    final doneOrders = _foodOrders.where((o) => o.isCompleted).toList();
    final totalFoodSpend =
        doneOrders.fold<double>(0, (sum, o) => sum + o.grandTotal);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary for ${widget.user.name ?? widget.user.email ?? "User"}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (_userPushToken != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sendingNoti ? null : _showSendNotificationDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _sendingNoti
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.notifications_active_outlined),
                label: Text(_sendingNoti ? 'Sending...' : 'Send notification'),
              ),
            ),
          ],
          const SizedBox(height: 20),
          _analysisCard(
            'Rides',
            [
              _statRow('Total rides', '${_rides.length}'),
              _statRow('Completed', '${completedRides.length}'),
              _statRow('Total spent', _formatCurrency(totalRideSpend)),
            ],
            Icons.directions_car,
            Colors.blue,
          ),
          const SizedBox(height: 16),
          _analysisCard(
            'Food Orders',
            [
              _statRow('Total orders', '${_foodOrders.length}'),
              _statRow('Delivered', '${doneOrders.length}'),
              _statRow('Total spent', _formatCurrency(totalFoodSpend)),
            ],
            Icons.restaurant,
            Colors.orange,
          ),
          const SizedBox(height: 16),
          _analysisCard(
            'Overall',
            [
              _statRow('Total rides + orders',
                  '${_rides.length + _foodOrders.length}'),
              _statRow('Combined spend', _formatCurrency(totalRideSpend + totalFoodSpend)),
            ],
            Icons.analytics,
            Colors.deepPurpleAccent,
          ),
        ],
      ),
    );
  }

  Widget _analysisCard(
    String title,
    List<Widget> rows,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...rows,
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[400])),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRidesTab() {
    if (_rides.isEmpty) {
      return const Center(
        child: Text('No rides yet.', style: TextStyle(color: Colors.grey)),
      );
    }
    final sortedRides = [..._rides]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sortedRides.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final ride = sortedRides[i];
        final driver =
            ride.driverId != null ? _driversMap[ride.driverId!.trim()] : null;
        final rideRequest = ride.rideRequestId != null
            ? _rideRequestsById[ride.rideRequestId!.trim()]
            : null;
        final statusColor = _getRideStatusColor(ride.status);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D2D),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.directions_car, color: statusColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatCurrency(ride.riderPaid),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ride.formattedCreatedAt,
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusPill(ride.status, statusColor),
                ],
              ),
              const SizedBox(height: 12),
              _buildKeyValueGrid([
                _kv('id', ride.id),
                _kv('pickup_place', rideRequest?.pickupPlace ?? ''),
                _kv('dropoff_place', rideRequest?.dropoffPlace ?? ''),
                _kv('start_time', _formatDateTime(ride.startTime)),
                _kv('end_time', _formatDateTime(ride.endTime)),
                _kv('total_price (driver fare)', _formatCurrency(ride.driverFare)),
                _kv('created_at', _formatDateTime(ride.createdAt)),
                _kv('status', ride.status ?? ''),
              ]),
              if (driver != null) ...[
                const SizedBox(height: 10),
                _buildDriverInfoCard(driver, includeRate: true),
              ],
              const SizedBox(height: 10),
              _buildRidePaymentCard(ride),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRidePaymentCard(RideModel ride) {
    return _buildInfoSectionCard(
      title: 'Payment',
      icon: Icons.payments_outlined,
      color: Colors.greenAccent,
      child: _buildKeyValueGrid([
        _kv('payment_type', ride.paymentType ?? ''),
        _kv('rider paid', _formatCurrency(ride.riderPaid)),
        _kv(
          'coupon (paid by app)',
          ride.hasCouponDiscount ? _formatCurrency(ride.couponCovered) : '',
        ),
        _kv('payment_sent', ride.paymentSent ? 'true' : 'false'),
      ]),
    );
  }

  Widget _buildFoodOrdersTab() {
    if (_foodOrders.isEmpty) {
      return const Center(
        child: Text('No food orders yet.', style: TextStyle(color: Colors.grey)),
      );
    }
    final sortedOrders = [..._foodOrders]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sortedOrders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final order = sortedOrders[i];
        final restaurant = order.restaurantId != null
            ? _restaurantsMap[order.restaurantId!]
            : null;
        final location = order.locationId != null
            ? _foodLocationsMap[order.locationId!]
            : null;
        final driver = order.driverId != null ? _driversMap[order.driverId!] : null;
        final cartItems =
            order.cartId != null ? (_cartItemsByCartId[order.cartId!] ?? []) : const <CartItemModel>[];
        final statusColor = _getOrderStatusColor(order.status);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D2D),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.restaurant, color: statusColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurant?.name ?? 'Restaurant #${order.restaurantId ?? '-'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.formattedCreatedAt,
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusPill(order.status, statusColor),
                ],
              ),
              const SizedBox(height: 12),
              _buildKeyValueGrid([
                _kv('Order ID', '${order.id}'),
                _kv('Cart ID', _displayInt(order.cartId)),
                _kv('Location Name', location?.locationName ?? 'N/A'),
                _kv('Restaurant ID', _displayInt(order.restaurantId)),
                _kv('User Email', order.userEmail ?? 'N/A'),
                _kv('Payment', order.paymentType ?? 'N/A'),
                _kv('Food', _formatCurrency(order.foodAmount)),
                _kv(
                  'Coupon',
                  order.couponDiscount > 0
                      ? '−${_formatCurrency(order.couponDiscount)}'
                      : '',
                ),
                _kv('Delivery', _formatCurrency(order.deliveryPrice)),
                _kv('Customer Paid', _formatCurrency(order.grandTotal)),
                _kv('Restaurant Category', restaurant?.category ?? 'N/A'),
                _kv(
                  'Restaurant Rating',
                  restaurant?.rateLabel ?? 'N/A',
                ),
              ]),
              if (location != null) ...[
                const SizedBox(height: 12),
                _buildInfoSectionCard(
                  title: 'User Location Data',
                  icon: Icons.location_on,
                  color: Colors.tealAccent,
                  child: _buildKeyValueGrid([
                    _kv('Location Name', location.locationName ?? ''),
                    _kv('User Name', location.userName ?? ''),
                    _kv('User Phone', location.userPhone ?? ''),
                    _kv('Floor', location.floor ?? ''),
                    _kv('Apartment', location.apartment ?? ''),
                    _kv('Landmark', location.landmark ?? ''),
                    _kv('Notes', location.notes ?? ''),
                    _kv('Coordinates', _formatLocation(location.lat, location.lng)),
                  ]),
                ),
              ],
              if (driver != null) ...[
                const SizedBox(height: 10),
                _buildDriverInfoCard(driver),
              ],
              if (order.cartId != null) ...[
                const SizedBox(height: 10),
                _buildCartItemsCard(order.cartId!, cartItems),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCartItemsCard(int cartId, List<CartItemModel> items) {
    final sorted = [...items]..sort((a, b) {
          final ta = a.createdAt;
          final tb = b.createdAt;
          if (ta != null && tb != null) return ta.compareTo(tb);
          return a.id.compareTo(b.id);
        });
    return _buildInfoSectionCard(
      title: 'cart_items',
      icon: Icons.shopping_bag,
      color: Colors.amberAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'cart_id: $cartId • ${sorted.length} row(s)',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (sorted.isEmpty)
            Text(
              'No rows in cart_items for this cart_id.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12.5),
            )
          else
            for (int i = 0; i < sorted.length; i++) ...[
              _buildSingleCartItem(sorted[i]),
              if (i < sorted.length - 1)
                Divider(color: Colors.white.withOpacity(0.08), height: 22),
            ],
        ],
      ),
    );
  }

  Widget _buildSingleCartItem(CartItemModel item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.14)),
                color: Colors.white.withOpacity(0.04),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: _isNotBlank(item.itemImage)
                    ? FirebaseStorageImage(
                        imageUrl: item.itemImage!.trim(),
                        fit: BoxFit.cover,
                        width: 72,
                        height: 72,
                        fallbackIcon: Icons.broken_image_outlined,
                        fallbackIconColor: Colors.white38,
                      )
                    : const Center(
                        child: Icon(Icons.fastfood, color: Colors.white38, size: 32),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isNotBlank(item.itemName))
                    Text(
                      item.itemName!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  if (_isNotBlank(item.itemName)) const SizedBox(height: 6),
                  _buildKeyValueGrid([
                    _kv('id', '${item.id}'),
                    _kv('item_name', item.itemName ?? ''),
                    _kv('restaurant_id', _displayInt(item.restaurantId)),
                    _kv('user_email', item.userEmail ?? ''),
                    _kv(
                      'item_price',
                      item.itemPrice != null ? _formatCurrency(item.itemPrice) : '',
                    ),
                    _kv(
                      'item_quant',
                      item.itemQuant != null ? '${item.itemQuant}' : '',
                    ),
                    _kv('created_at', _formatDateTime(item.createdAt)),
                    _kv('cart_id', _displayInt(item.cartId)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildDriverInfoCard(DriverModel driver, {bool includeRate = false}) {
    final rateStr =
        includeRate && driver.rate > 0 ? driver.rate.toStringAsFixed(1) : '';
    final hasAnyDriverInfo = _isNotBlank(driver.name) ||
        _isNotBlank(driver.email) ||
        _isNotBlank(driver.phone) ||
        _isNotBlank(driver.profileImage) ||
        _isNotBlank(rateStr);
    if (!hasAnyDriverInfo) {
      return const SizedBox.shrink();
    }

    return _buildInfoSectionCard(
      title: 'Driver Data',
      icon: Icons.person,
      color: Colors.lightBlueAccent,
      child: Column(
        children: [
          if (_isNotBlank(driver.profileImage))
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.14)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: FirebaseStorageImage(
                    imageUrl: driver.profileImage!,
                    fit: BoxFit.cover,
                    width: 56,
                    height: 56,
                    fallbackIcon: Icons.person,
                    fallbackIconColor: Colors.white70,
                  ),
                ),
              ),
            ),
          if (_isNotBlank(driver.profileImage)) const SizedBox(height: 10),
          _buildKeyValueGrid([
            _kv('Name', driver.name ?? ''),
            _kv('Email', driver.email ?? ''),
            _kv('Phone', driver.phone ?? ''),
            _kv('Rate', rateStr),
          ]),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String? status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        (status ?? 'N/A').replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildKeyValueGrid(List<MapEntry<String, String>> entries) {
    final visible = entries.where((entry) => _isNotBlank(entry.value)).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Column(
      children: visible
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 118,
                    child: Text(
                      entry.key,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  MapEntry<String, String> _kv(String key, String value) => MapEntry(key, value);

  String _formatCurrency(num? value) => formatMoney(value);

  String _displayInt(int? value) => value?.toString() ?? '';

  String _formatDateTime(DateTime? value) {
    if (value == null) return '';
    return DateFormat('MMM dd, yyyy • HH:mm').format(value);
  }

  String _formatLocation(double? lat, double? lng) {
    if (lat == null || lng == null) return '';
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }

  bool _isNotBlank(String? value) => value != null && value.trim().isNotEmpty;

  Color _getRideStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.greenAccent;
      case 'in_trip':
        return Colors.blueAccent;
      case 'cancelled':
        return Colors.redAccent;
      default:
        return Colors.orangeAccent;
    }
  }

  Color _getOrderStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'done':
      case 'delivered':
        return Colors.greenAccent;
      case 'accepted':
        return Colors.blueAccent;
      case 'cancelled':
        return Colors.redAccent;
      default:
        return Colors.orangeAccent;
    }
  }
}
