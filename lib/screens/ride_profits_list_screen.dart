import 'package:flutter/material.dart';
import '../models/ride_app_commission_model.dart';
import '../services/supabase_service.dart';
import '../widgets/custom_drawer.dart';

enum _ProfitPeriod { day, week, month, year }

class RideProfitsListScreen extends StatefulWidget {
  const RideProfitsListScreen({super.key});

  @override
  State<RideProfitsListScreen> createState() => _RideProfitsListScreenState();
}

class _RideProfitsListScreenState extends State<RideProfitsListScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();

  List<RideAppCommissionModel> _all = [];
  List<RideAppCommissionModel> _filtered = [];
  bool _isLoading = true;
  String? _error;
  _ProfitPeriod _period = _ProfitPeriod.month;

  static const _headerStyle = TextStyle(
    color: Colors.deepPurpleAccent,
    fontWeight: FontWeight.bold,
    fontSize: 12,
  );

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  DateTime get _periodStart {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_period) {
      case _ProfitPeriod.day:
        return today;
      case _ProfitPeriod.week:
        return today.subtract(Duration(days: today.weekday - 1));
      case _ProfitPeriod.month:
        return DateTime(now.year, now.month, 1);
      case _ProfitPeriod.year:
        return DateTime(now.year, 1, 1);
    }
  }

  String get _periodLabel {
    switch (_period) {
      case _ProfitPeriod.day:
        return 'Today';
      case _ProfitPeriod.week:
        return 'This week';
      case _ProfitPeriod.month:
        return 'This month';
      case _ProfitPeriod.year:
        return 'This year';
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final rows = await _supabaseService.getRideAppCommissions();
      if (!mounted) return;
      setState(() {
        _all = rows;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    final start = _periodStart;
    _filtered = _all.where((row) {
      final local = row.date.toLocal();
      final inPeriod = !local.isBefore(start);
      if (!inPeriod) return false;
      if (query.isEmpty) return true;
      return row.id.toString().contains(query) ||
          (row.rideId?.toLowerCase().contains(query) ?? false) ||
          row.amount.toString().contains(query);
    }).toList();
  }

  double get _totalProfit =>
      _filtered.fold<double>(0, (sum, e) => sum + e.amount);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      drawer: const CustomDrawer(activeItem: 'Mego Ride Profits'),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Mego Ride Profits',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _fetch,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPeriodFilter(),
            const SizedBox(height: 20),
            _buildStats(),
            const SizedBox(height: 20),
            _buildSearch(),
            const SizedBox(height: 16),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodFilter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: SegmentedButton<_ProfitPeriod>(
        segments: const [
          ButtonSegment(
            value: _ProfitPeriod.day,
            label: Text('Day'),
            icon: Icon(Icons.today_outlined, size: 16),
          ),
          ButtonSegment(
            value: _ProfitPeriod.week,
            label: Text('Week'),
            icon: Icon(Icons.date_range_outlined, size: 16),
          ),
          ButtonSegment(
            value: _ProfitPeriod.month,
            label: Text('Month'),
            icon: Icon(Icons.calendar_month_outlined, size: 16),
          ),
          ButtonSegment(
            value: _ProfitPeriod.year,
            label: Text('Year'),
            icon: Icon(Icons.calendar_today_outlined, size: 16),
          ),
        ],
        selected: {_period},
        onSelectionChanged: (s) {
          setState(() {
            _period = s.first;
            _applyFilters();
          });
        },
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            return Colors.grey;
          }),
        ),
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        _statCard(
          'Total profit ($_periodLabel)',
          '\$${_totalProfit.toStringAsFixed(2)}',
          Icons.trending_up,
          const Color(0xFF3DDC97),
        ),
        const SizedBox(width: 16),
        _statCard(
          'Transactions',
          '${_filtered.length}',
          Icons.receipt_long_outlined,
          Colors.deepPurpleAccent,
        ),
        const SizedBox(width: 16),
        _statCard(
          'All time rows',
          '${_all.length}',
          Icons.storage_outlined,
          Colors.blueAccent,
        ),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D2D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(_applyFilters),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search by ride id or amount…',
        hintStyle: TextStyle(color: Colors.grey[600]),
        prefixIcon: const Icon(Icons.search, color: Colors.deepPurpleAccent),
        filled: true,
        fillColor: const Color(0xFF1A1D2D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error: $_error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _fetch, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_filtered.isEmpty) {
      return Center(
        child: Text(
          'No ride profits for $_periodLabel.',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('DATE', style: _headerStyle)),
                Expanded(flex: 2, child: Text('RIDE ID', style: _headerStyle)),
                Expanded(
                  flex: 2,
                  child: Text(
                    'AMOUNT',
                    style: _headerStyle,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withOpacity(0.06)),
          Expanded(
            child: ListView.separated(
              itemCount: _filtered.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.white.withOpacity(0.04)),
              itemBuilder: (context, index) {
                final row = _filtered[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          row.formattedDate,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          row.rideId ?? '—',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          row.formattedAmount,
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            color: Color(0xFF3DDC97),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
