import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/money.dart';
import '../models/cart_item_model.dart';
import '../models/driver_model.dart';
import '../models/food_checkout_model.dart';
import '../models/food_order_settlement_model.dart';
import '../models/food_ride_model.dart';
import '../models/restaurant_model.dart';
import '../models/user_food_location_model.dart';
import '../models/user_model.dart';
import '../services/supabase_service.dart';
import '../widgets/firebase_storage_image.dart';

class FoodCheckoutDetailScreen extends StatefulWidget {
  final FoodCheckoutModel checkout;

  const FoodCheckoutDetailScreen({super.key, required this.checkout});

  @override
  State<FoodCheckoutDetailScreen> createState() => _FoodCheckoutDetailScreenState();
}

class _FoodCheckoutDetailScreenState extends State<FoodCheckoutDetailScreen> {
  final _supabase = SupabaseService();

  UserModel? _user;
  DriverModel? _driver;
  FoodRideModel? _foodRide;
  RestaurantModel? _restaurant;
  UserFoodLocationModel? _location;
  List<CartItemModel> _cartItems = [];
  FoodOrderSettlementModel _settlement = const FoodOrderSettlementModel();
  bool _loading = true;
  String? _error;

  FoodCheckoutModel get _o => widget.checkout;

  String? get _resolvedDriverId {
    final fromRide = _foodRide?.driverId?.trim();
    if (fromRide != null && fromRide.isNotEmpty) return fromRide;
    final fromOrder = _o.driverId?.trim();
    if (fromOrder != null && fromOrder.isNotEmpty) return fromOrder;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final email = _o.userEmail?.trim();
      final userTask = (email != null && email.isNotEmpty)
          ? _supabase.getUserByEmail(email)
          : Future<UserModel?>.value(null);
      final foodRideTask = _supabase.getFoodRideByOrderId(_o.id);
      final restaurantTask =
          _o.restaurantId != null
              ? _supabase.getRestaurantById(_o.restaurantId!)
              : Future<RestaurantModel?>.value(null);
      final locationTask =
          _o.locationId != null
              ? _supabase
                  .getUserFoodLocationsByIds([_o.locationId!])
                  .then((list) => list.isNotEmpty ? list.first : null)
              : Future<UserFoodLocationModel?>.value(null);
      final cartTask =
          _o.cartId != null
              ? _supabase.getCartItemsByCartIds([_o.cartId!])
              : Future<List<CartItemModel>>.value([]);

      final foodRide = await foodRideTask;
      final rideDriverId = foodRide?.driverId?.trim();
      final checkoutDriverId = _o.driverId?.trim();
      final driverId = (rideDriverId != null && rideDriverId.isNotEmpty)
          ? rideDriverId
          : ((checkoutDriverId != null && checkoutDriverId.isNotEmpty)
              ? checkoutDriverId
              : null);

      final results = await Future.wait<Object?>([
        userTask,
        driverId != null
            ? _supabase.getDriverById(driverId)
            : Future<DriverModel?>.value(null),
        restaurantTask,
        locationTask,
        cartTask,
        _supabase.getFoodOrderSettlement(_o.id),
      ]);

      if (!mounted) return;
      setState(() {
        _foodRide = foodRide;
        _user = results[0] as UserModel?;
        _driver = results[1] as DriverModel?;
        _restaurant = results[2] as RestaurantModel?;
        _location = results[3] as UserFoodLocationModel?;
        _cartItems = results[4] as List<CartItemModel>;
        _settlement = results[5] as FoodOrderSettlementModel;
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

  @override
  Widget build(BuildContext context) {
    final statusColor = _orderStatusColor(_o.status);
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Order #${_o.id}',
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _headerCard(statusColor),
                  const SizedBox(height: 14),
                  _section(
                    title: 'Order',
                    icon: Icons.receipt_long,
                    color: Colors.deepPurpleAccent,
                    child: _kvGrid([
                      _e('status', _o.status ?? ''),
                      _e('user_email', _o.userEmail ?? ''),
                      _e('payment_type', _o.paymentType ?? ''),
                      _e('food_subtotal', formatMoney(_o.foodAmount)),
                      _e(
                        'discount_amount',
                        _o.couponDiscount > 0
                            ? formatMoney(_o.couponDiscount)
                            : '',
                      ),
                      _e('delivery_price', formatMoney(_o.deliveryPrice)),
                      _e('total (customer paid)', formatMoney(_o.total)),
                      _e(
                        'wallet_paid',
                        (_o.walletPaid ?? 0) > 0
                            ? formatMoney(_o.walletPaid)
                            : '',
                      ),
                      _e(
                        'refunded_amount',
                        (_o.refundedAmount ?? 0) > 0
                            ? formatMoney(_o.refundedAmount)
                            : '',
                      ),
                      _e('created_at', _dt(_o.createdAt)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  _userSection(),
                  const SizedBox(height: 12),
                  _foodRideSection(),
                  const SizedBox(height: 12),
                  _driverSection(),
                  const SizedBox(height: 12),
                  _restaurantSection(),
                  const SizedBox(height: 12),
                  _locationSection(),
                  if (_o.cartId != null) ...[
                    const SizedBox(height: 12),
                    _cartSection(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _headerCard(Color statusColor) {
    final delivery = _o.deliveryPrice ?? 0;
    final settled = _settlement.isSettled;
    final appCommission = _settlement.commissionFor(_o);
    final restaurantProfit = _settlement.restaurantFor(_o);
    final driverWallet = _settlement.driverWalletEntry;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.shopping_bag, color: statusColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _o.formattedCreatedAt,
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                    if (_restaurant?.name != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _restaurant!.name!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _statusPill(_o.status, statusColor),
            ],
          ),
          const SizedBox(height: 18),
          _moneyRow(
            'Customer paid',
            formatMoney(_o.grandTotal),
            Colors.white,
            bold: true,
            large: true,
          ),
          const SizedBox(height: 10),
          _moneyRow(
            'Food (before coupon)',
            formatMoney(_o.foodAmount),
            Colors.grey[300]!,
          ),
          if (_o.couponDiscount > 0) ...[
            const SizedBox(height: 6),
            _moneyRow(
              'Coupon (paid by app)',
              '−${formatMoney(_o.couponDiscount)}',
              Colors.pinkAccent,
            ),
          ],
          const SizedBox(height: 6),
          _moneyRow('Delivery fee', formatMoney(delivery), Colors.orangeAccent),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white.withOpacity(0.08), height: 1),
          ),
          _moneyRow(
            'App commission (12% of food)',
            formatMoney(appCommission),
            Colors.deepPurpleAccent,
            bold: true,
          ),
          const SizedBox(height: 8),
          _moneyRow(
            'Restaurant share',
            formatMoney(restaurantProfit),
            const Color(0xFF3DDC97),
            bold: true,
            large: true,
          ),
          const SizedBox(height: 8),
          _moneyRow(
            'Driver earns (delivery)',
            formatMoney(_settlement.driverEarningsFor(_o)),
            Colors.lightBlueAccent,
          ),
          if (driverWallet != null) ...[
            const SizedBox(height: 6),
            _moneyRow(
              'Driver wallet entry',
              formatMoney(driverWallet),
              Colors.grey[400]!,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            settled
                ? 'Settled amounts — same rows the restaurant / driver wallets show.'
                : 'Not settled yet — expected split (same formula as the driver app).',
            style: TextStyle(
              color: settled ? Colors.greenAccent[100] : Colors.grey[600],
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _moneyRow(
    String label,
    String value,
    Color valueColor, {
    bool bold = false,
    bool large = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: large ? 14 : 13,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: large ? 22 : 15,
            fontWeight: bold || large ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _userSection() {
    if (_user != null) {
      final u = _user!;
      return _section(
        title: 'Customer (user)',
        icon: Icons.person_outline,
        color: Colors.tealAccent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_nonEmpty(u.profile))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FirebaseStorageImage(
                    imageUrl: u.profile!.trim(),
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.person,
                  ),
                ),
              ),
            _kvGrid([
              _e('name', u.name ?? ''),
              _e('email', u.email ?? ''),
              _e('phone', u.phone ?? ''),
              _e('user_type', u.userType ?? ''),
              _e('created_at', u.formattedDate),
            ]),
          ],
        ),
      );
    }
    return _section(
      title: 'Customer (user)',
      icon: Icons.person_outline,
      color: Colors.tealAccent,
      child: _kvGrid([
        _e('user_email', _o.userEmail ?? ''),
        _e(
          'note',
          _nonEmpty(_o.userEmail ?? '')
              ? 'No matching row in users for this email.'
              : 'No email on this checkout.',
        ),
      ]),
    );
  }

  Widget _foodRideSection() {
    final ride = _foodRide;
    if (ride == null) {
      return _section(
        title: 'Food ride',
        icon: Icons.two_wheeler,
        color: Colors.cyanAccent,
        child: Text(
          'No food_ride row linked to this order yet.',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }
    return _section(
      title: 'Food ride',
      icon: Icons.two_wheeler,
      color: Colors.cyanAccent,
      child: _kvGrid([
        _e('status', ride.status ?? ''),
        _e('created_at', ride.formattedCreatedAt),
      ]),
    );
  }

  Widget _driverSection() {
    if (_driver != null) {
      final d = _driver!;
      return _section(
        title: 'Driver',
        icon: Icons.delivery_dining,
        color: Colors.lightBlueAccent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_nonEmpty(d.profileImage))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FirebaseStorageImage(
                    imageUrl: d.profileImage!.trim(),
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.person,
                  ),
                ),
              ),
            _kvGrid([
              _e('name', d.name ?? ''),
              _e('email', d.email ?? ''),
              _e('phone', d.phone ?? ''),
              _e('rate', d.rate.toStringAsFixed(1)),
              _e('type', d.type ?? ''),
              _e('activated', d.activated ? 'true' : 'false'),
              _e('online', d.online ? 'true' : 'false'),
            ]),
          ],
        ),
      );
    }
    if (_nonEmpty(_resolvedDriverId)) {
      return _section(
        title: 'Driver',
        icon: Icons.delivery_dining,
        color: Colors.lightBlueAccent,
        child: Text(
          'Driver linked to this order, but profile details were not found.',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }
    return _section(
      title: 'Driver',
      icon: Icons.delivery_dining,
      color: Colors.lightBlueAccent,
      child: Text(
        'No driver assigned for this order.',
        style: TextStyle(color: Colors.grey[600]),
      ),
    );
  }

  Widget _restaurantSection() {
    if (_restaurant != null) {
      final r = _restaurant!;
      return _section(
        title: 'Restaurant',
        icon: Icons.restaurant,
        color: Colors.orangeAccent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_nonEmpty(r.image))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FirebaseStorageImage(
                    imageUrl: r.image!.trim(),
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            _kvGrid([
              _e('name', r.name ?? ''),
              _e('category', r.category ?? ''),
              _e('rate', r.rateLabel),
              _e('details', r.details ?? ''),
              _e('email', r.email ?? ''),
            ]),
          ],
        ),
      );
    }
    if (_o.restaurantId != null) {
      return _section(
        title: 'Restaurant',
        icon: Icons.restaurant,
        color: Colors.orangeAccent,
        child: Text(
          'Restaurant not found.',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }
    return _section(
      title: 'Restaurant',
      icon: Icons.restaurant,
      color: Colors.orangeAccent,
      child: Text('No restaurant on this order.', style: TextStyle(color: Colors.grey[600])),
    );
  }

  Widget _locationSection() {
    if (_location != null) {
      final l = _location!;
      return _section(
        title: 'Delivery location',
        icon: Icons.location_on,
        color: Colors.greenAccent,
        child: _kvGrid([
          _e('location_name', l.locationName ?? ''),
          _e('user_name', l.userName ?? ''),
          _e('user_phone', l.userPhone ?? ''),
          _e('floor', l.floor ?? ''),
          _e('apartment', l.apartment ?? ''),
          _e('landmark', l.landmark ?? ''),
          _e('notes', l.notes ?? ''),
          _e(
            'coordinates',
            l.lat != null && l.lng != null
                ? '${l.lat!.toStringAsFixed(5)}, ${l.lng!.toStringAsFixed(5)}'
                : '',
          ),
        ]),
      );
    }
    if (_o.locationId != null) {
      return _section(
        title: 'Delivery location',
        icon: Icons.location_on,
        color: Colors.greenAccent,
        child: Text(
          'Location details not found.',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _cartSection() {
    final sorted = [..._cartItems]..sort((a, b) {
      final ta = a.createdAt;
      final tb = b.createdAt;
      if (ta != null && tb != null) return ta.compareTo(tb);
      return a.id.compareTo(b.id);
    });
    return _section(
      title: 'cart_items (cart_id: ${_o.cartId})',
      icon: Icons.shopping_basket,
      color: Colors.amberAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sorted.isEmpty)
            Text(
              'No rows in cart_items for this cart.',
              style: TextStyle(color: Colors.grey[600]),
            )
          else
            for (int i = 0; i < sorted.length; i++) ...[
              _cartLine(sorted[i]),
              if (i < sorted.length - 1)
                Divider(color: Colors.white.withOpacity(0.08), height: 20),
            ],
        ],
      ),
    );
  }

  Widget _cartLine(CartItemModel item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
            color: Colors.white.withOpacity(0.04),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: _nonEmpty(item.itemImage)
                ? FirebaseStorageImage(
                    imageUrl: item.itemImage!.trim(),
                    fit: BoxFit.cover,
                    width: 64,
                    height: 64,
                    fallbackIcon: Icons.fastfood,
                    fallbackIconColor: Colors.white38,
                  )
                : const Icon(Icons.fastfood, color: Colors.white38),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_nonEmpty(item.itemName))
                Text(
                  item.itemName!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              const SizedBox(height: 4),
              _kvGrid([
                _e('id', '${item.id}'),
                _e('item_quant', item.itemQuant != null ? '${item.itemQuant}' : ''),
                _e('item_price', item.itemPrice != null ? _gbp(item.itemPrice) : ''),
                _e('created_at', _dt(item.createdAt)),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _kvGrid(List<MapEntry<String, String>> entries) {
    final rows = entries.where((e) => _nonEmpty(e.value)).toList();
    if (rows.isEmpty) {
      return Text('—', style: TextStyle(color: Colors.grey[600]));
    }
    return Column(
      children: rows
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 124,
                    child: Text(
                      e.key,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
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

  MapEntry<String, String> _e(String k, String v) => MapEntry(k, v);

  String _gbp(num? n) => formatMoney(n);

  String _dt(DateTime? t) =>
      t == null ? '' : DateFormat('MMM dd, yyyy • HH:mm').format(t);

  bool _nonEmpty(String? s) => s != null && s.trim().isNotEmpty;

  Widget _statusPill(String? status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Text(
        (status ?? 'N/A').replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Color _orderStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'done':
      case 'delivered':
        return Colors.greenAccent;
      case 'accepted':
        return Colors.blueAccent;
      case 'pending':
        return Colors.orangeAccent;
      case 'cancelled':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }
}
