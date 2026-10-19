import 'package:flutter/material.dart';
import '../core/money.dart';
import '../models/food_checkout_model.dart';
import '../models/restaurant_model.dart';
import '../services/supabase_service.dart';
import '../services/excel_export_service.dart';
import '../widgets/custom_drawer.dart';
import 'food_checkout_detail_screen.dart';

class FoodCheckoutListScreen extends StatefulWidget {
  const FoodCheckoutListScreen({super.key});

  @override
  State<FoodCheckoutListScreen> createState() => _FoodCheckoutListScreenState();
}

class _FoodCheckoutListScreenState extends State<FoodCheckoutListScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();

  List<FoodCheckoutModel> _allCheckouts = [];
  List<FoodCheckoutModel> _filteredCheckouts = [];
  Map<int, RestaurantModel> _restaurantsMap = {};
  bool _isLoading = true;
  bool _isExporting = false;
  String? _error;
  String _selectedStatus = 'All';

  final List<String> _statuses = [
    'All',
    'pending',
    'accepted',
    'assigned',
    'delivered',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _fetchCheckouts();
  }

  Future<void> _fetchCheckouts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final checkouts = await _supabaseService.getFoodCheckouts();
      final restaurants = await _supabaseService.getRestaurants();

      final Map<int, RestaurantModel> resMap = {
        for (var r in restaurants) r.id: r,
      };

      setState(() {
        _allCheckouts = checkouts;
        _restaurantsMap = resMap;
        _filterCheckouts();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _openCheckoutDetail(FoodCheckoutModel checkout) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => FoodCheckoutDetailScreen(checkout: checkout),
      ),
    );
  }

  void _filterCheckouts() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      _filteredCheckouts =
          _allCheckouts.where((checkout) {
            final restaurant = _restaurantsMap[checkout.restaurantId];
            final restaurantName = restaurant?.name?.toLowerCase() ?? '';
            final matchesStatus =
                _selectedStatus == 'All' ||
                (_selectedStatus == 'delivered'
                    ? checkout.isCompleted
                    : checkout.status?.toLowerCase() ==
                        _selectedStatus.toLowerCase());
            final matchesSearch =
                checkout.id.toString().contains(query) ||
                (checkout.userEmail?.toLowerCase().contains(query) ?? false) ||
                restaurantName.contains(query);
            return matchesStatus && matchesSearch;
          }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _exportExcel() async {
    if (_isExporting) return;
    if (_filteredCheckouts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No rows to export')),
      );
      return;
    }
    setState(() => _isExporting = true);
    try {
      await ExcelExportService.exportSheet(
        sheetName: 'Food Orders',
        headers: const [
          'Order ID',
          'Date',
          'User Email',
          'Restaurant',
          'Status',
          'Payment',
          'Food',
          'Coupon',
          'Delivery',
          'Customer Paid',
          'Cart ID',
          'Driver ID',
        ],
        rows: ExcelExportService.rowsFromFoodOrders(
          _filteredCheckouts,
          _restaurantsMap,
        ),
        fileName: ExcelExportService.fileName('food_orders'),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${_filteredCheckouts.length} food orders'),
          backgroundColor: Colors.green.shade800,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not export Excel file')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      drawer: const CustomDrawer(activeItem: 'Food Checkout'),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Food Checkout Management',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading || _isExporting ? null : _exportExcel,
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download_outlined),
            tooltip: 'Export Excel',
          ),
          IconButton(
            onPressed: () {
              _searchController.clear();
              _selectedStatus = 'All';
              _fetchCheckouts();
            },
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsHeader(),
            const SizedBox(height: 32),
            _buildSearchAndFilters(),
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1D2D),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null
                        ? _buildErrorWidget()
                        : _filteredCheckouts.isEmpty
                        ? const Center(child: Text('No checkouts found.'))
                        : _buildDataTable(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: _searchController,
            onChanged: (_) => _filterCheckouts(),
            decoration: InputDecoration(
              hintText: 'Search by ID, Email, or Restaurant ID...',
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.deepPurpleAccent,
              ),
              suffixIcon:
                  _searchController.text.isNotEmpty
                      ? IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.grey,
                          size: 20,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _filterCheckouts();
                        },
                      )
                      : null,
              filled: true,
              fillColor: const Color(0xFF1A1D2D),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.deepPurpleAccent),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D2D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedStatus,
              dropdownColor: const Color(0xFF1A1D2D),
              style: const TextStyle(color: Colors.white),
              items:
                  _statuses.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(status.toUpperCase()),
                    );
                  }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedStatus = value;
                    _filterCheckouts();
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          showCheckboxColumn: false,
          headingRowHeight: 60,
          dataRowMaxHeight: 70,
          columns: const [
            DataColumn(label: Text('DATE', style: _headerStyle)),
            DataColumn(label: Text('USER EMAIL', style: _headerStyle)),
            DataColumn(label: Text('CUSTOMER PAID', style: _headerStyle)),
            DataColumn(label: Text('DELIVERY', style: _headerStyle)),
            DataColumn(label: Text('STATUS', style: _headerStyle)),
            DataColumn(label: Text('RESTAURANT', style: _headerStyle)),
            DataColumn(label: Text('ACTIONS', style: _headerStyle)),
          ],
          rows:
              _filteredCheckouts
                  .map((checkout) => _buildDataRow(checkout))
                  .toList(),
        ),
      ),
    );
  }

  DataRow _buildDataRow(FoodCheckoutModel checkout) {
    return DataRow(
      onSelectChanged: (_) => _openCheckoutDetail(checkout),
      cells: [
        DataCell(
          Text(
            checkout.formattedCreatedAt,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        DataCell(
          Text(
            checkout.userEmail ?? 'N/A',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ),
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatMoney(checkout.grandTotal),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Food: ${formatMoney(checkout.foodAmount)}'
                '${checkout.couponDiscount > 0 ? ' • Coupon −${formatMoney(checkout.couponDiscount)}' : ''}',
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
            ],
          ),
        ),
        DataCell(
          Text(
            formatMoney(checkout.deliveryPrice),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(checkout.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getStatusColor(checkout.status).withOpacity(0.2),
              ),
            ),
            child: Text(
              checkout.status?.toUpperCase() ?? 'UNKNOWN',
              style: TextStyle(
                color: _getStatusColor(checkout.status),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        DataCell(
          Row(
            children: [
              Text(
                _restaurantsMap[checkout.restaurantId]?.name ??
                    'ID: ${checkout.restaurantId ?? 'N/A'}',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
              if (checkout.restaurantId != null &&
                  _restaurantsMap.containsKey(checkout.restaurantId))
                IconButton(
                  onPressed: () => _openCheckoutDetail(checkout),
                  icon: const Icon(
                    Icons.info_outline,
                    color: Colors.deepPurpleAccent,
                    size: 16,
                  ),
                  tooltip: 'View full order',
                ),
            ],
          ),
        ),
        DataCell(
          IconButton(
            onPressed: () => _openCheckoutDetail(checkout),
            icon: const Icon(
              Icons.remove_red_eye_outlined,
              color: Colors.blueAccent,
            ),
            tooltip: 'View full details',
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'done':
      case 'delivered':
        return Colors.greenAccent;
      case 'assigned':
        return Colors.tealAccent;
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

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $_error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchCheckouts,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Row(
      children: [
        _buildStatCard(
          'Total Orders',
          '${_allCheckouts.length}',
          Icons.shopping_cart_outlined,
          Colors.blue,
        ),
        const SizedBox(width: 24),
        _buildStatCard(
          'Completed',
          '${_allCheckouts.where((c) => c.isCompleted).length}',
          Icons.check_circle_outline,
          Colors.green,
        ),
        const SizedBox(width: 24),
        _buildStatCard(
          'Revenue',
          formatMoney(
            _allCheckouts
                .where((c) => c.isCompleted)
                .fold<double>(0, (sum, c) => sum + c.grandTotal),
          ),
          Icons.attach_money,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D2D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static const _headerStyle = TextStyle(
    fontWeight: FontWeight.bold,
    color: Colors.deepPurpleAccent,
    letterSpacing: 1.1,
    fontSize: 12,
  );
}
