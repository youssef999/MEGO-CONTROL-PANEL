import 'package:flutter/material.dart';

import '../models/food_checkout_model.dart';
import '../models/menu_model.dart';
import '../models/restaurant_model.dart';
import '../models/restaurant_order_stats_model.dart';
import '../services/supabase_service.dart';
import '../widgets/restaurant_detail/restaurant_detail_header.dart';
import '../widgets/restaurant_detail/restaurant_info_tab.dart';
import '../widgets/restaurant_detail/restaurant_menu_tab.dart';
import '../widgets/restaurant_detail/restaurant_orders_tab.dart';
import 'food_checkout_detail_screen.dart';
import 'restaurant_menu_screen.dart';
import 'restaurant_wallet_screen.dart';

/// One restaurant: profile, order counters, its orders and its menu.
class RestaurantDetailScreen extends StatefulWidget {
  final RestaurantModel restaurant;

  const RestaurantDetailScreen({super.key, required this.restaurant});

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  final _supabase = SupabaseService();

  late RestaurantModel _restaurant = widget.restaurant;
  List<FoodCheckoutModel> _orders = [];
  List<MenuModel> _menu = [];
  Map<String, int> _soldByName = {};
  bool _loading = true;
  String? _error;

  RestaurantOrderStatsModel get _stats =>
      RestaurantOrderStatsModel.fromOrders(_orders);

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
      final id = widget.restaurant.id;
      final results = await Future.wait([
        _supabase.getFoodCheckoutsByRestaurantId(id),
        _supabase.getMenuByRestaurantId(id),
        _supabase.getRestaurantById(id),
      ]);
      final orders = results[0] as List<FoodCheckoutModel>;
      final menu = results[1] as List<MenuModel>;
      final fresh = results[2] as RestaurantModel?;
      final sold = await _soldPerItem(orders);
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _menu = menu;
        _soldByName = sold;
        if (fresh != null) _restaurant = fresh;
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

  /// Units ordered per menu item name from this restaurant's non-cancelled orders.
  Future<Map<String, int>> _soldPerItem(List<FoodCheckoutModel> orders) async {
    final cartIds = orders
        .where((o) => !o.isCancelled)
        .map((o) => o.cartId)
        .whereType<int>()
        .toSet()
        .toList();
    if (cartIds.isEmpty) return {};
    try {
      final items = await _supabase.getCartItemsByCartIds(cartIds);
      final sold = <String, int>{};
      for (final item in items) {
        final key = (item.itemName ?? '').trim().toLowerCase();
        if (key.isEmpty) continue;
        sold[key] = (sold[key] ?? 0) + (item.itemQuant ?? 1);
      }
      return sold;
    } catch (_) {
      return {};
    }
  }

  void _open(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(_restaurant.name ?? 'Restaurant'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Error: $_error'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _load,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            )
          : _content(),
    );
  }

  Widget _content() {
    return DefaultTabController(
      length: 3,
      child: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            sliver: SliverToBoxAdapter(
              child: RestaurantDetailHeader(
                restaurant: _restaurant,
                stats: _stats,
                menuItemsCount: _menu.length,
                onManageMenu: () => _open(
                  RestaurantMenuScreen(
                    restaurantId: _restaurant.id,
                    restaurantName: _restaurant.name ?? 'Restaurant',
                  ),
                ),
                onWallet: () =>
                    _open(RestaurantWalletScreen(restaurant: _restaurant)),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverToBoxAdapter(
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: Colors.deepPurpleAccent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey[500],
                tabs: [
                  Tab(text: 'Orders (${_orders.length})'),
                  Tab(text: 'Menu (${_menu.length})'),
                  const Tab(text: 'Info'),
                ],
              ),
            ),
          ),
        ],
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TabBarView(
            children: [
              RestaurantOrdersTab(
                orders: _orders,
                onOpenOrder: (o) =>
                    _open(FoodCheckoutDetailScreen(checkout: o)),
              ),
              RestaurantMenuTab(
                items: _menu,
                sectionOrder: _restaurant.menuCategoryOrder,
                soldByName: _soldByName,
              ),
              RestaurantInfoTab(restaurant: _restaurant),
            ],
          ),
        ),
      ),
    );
  }
}
