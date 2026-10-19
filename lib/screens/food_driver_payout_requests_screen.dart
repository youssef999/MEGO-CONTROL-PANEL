import 'package:flutter/material.dart';
import '../models/driver_model.dart';
import '../models/food_driver_money_request_model.dart';
import '../models/partner_payout_method_model.dart';
import '../services/supabase_service.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/food_driver_money_request_card.dart';

/// Food driver "Request money" list (`food_driver_request_money`) with each
/// driver's payout method so the admin knows where to send the money.
class FoodDriverPayoutRequestsScreen extends StatefulWidget {
  const FoodDriverPayoutRequestsScreen({super.key});

  @override
  State<FoodDriverPayoutRequestsScreen> createState() =>
      _FoodDriverPayoutRequestsScreenState();
}

class _FoodDriverPayoutRequestsScreenState
    extends State<FoodDriverPayoutRequestsScreen> {
  static const _filters = ['Pending', 'Paid', 'All'];

  final SupabaseService _supabaseService = SupabaseService();
  List<FoodDriverMoneyRequestModel> _requests = [];
  Map<String, DriverModel> _drivers = {};
  Map<String, PartnerPayoutMethodModel> _payoutMethods = {};
  String _filter = 'Pending';
  bool _isLoading = true;
  bool _updating = false;
  String? _error;

  List<FoodDriverMoneyRequestModel> get _visible => switch (_filter) {
        'Pending' => _requests.where((r) => !r.sent).toList(),
        'Paid' => _requests.where((r) => r.sent).toList(),
        _ => _requests,
      };

  double get _pendingTotal => _requests
      .where((r) => !r.sent)
      .fold<double>(0, (sum, r) => sum + r.value);

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final requests = await _supabaseService.getFoodDriverMoneyRequests();
      final ids = requests.map((r) => r.driverId).toSet().toList();
      final results = await Future.wait([
        _supabaseService.getDriversByIds(ids),
        _supabaseService.getPayoutMethods(
          PartnerPayoutMethodModel.typeDriver,
          ids,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _drivers = {
          for (final d in results[0] as List<DriverModel>) d.id: d,
        };
        _payoutMethods = results[1] as Map<String, PartnerPayoutMethodModel>;
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

  Future<void> _confirmMarkPaid(FoodDriverMoneyRequestModel request) async {
    final name = _drivers[request.driverId]?.name ?? 'this driver';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2D),
        title: const Text(
          'Confirm payout sent?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you sent ${request.formattedValue} to "$name"?\n\n'
          'The request will be marked as paid (sent = true).',
          style: TextStyle(color: Colors.grey[300], height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, paid'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _markPaid(request);
  }

  Future<void> _markPaid(FoodDriverMoneyRequestModel request) async {
    setState(() => _updating = true);
    try {
      await _supabaseService.markFoodDriverMoneyRequestSent(request.id);
      if (!mounted) return;
      setState(() {
        _requests = _requests
            .map((r) => r.id == request.id ? r.copyWith(sent: true) : r)
            .toList();
        _updating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request marked as paid'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _updating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      drawer: const CustomDrawer(activeItem: 'Food Driver Payouts'),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Food Driver Payout Requests',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading || _updating ? null : _fetch,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: _fetch,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: _buildList(),
                        ),
                      ),
                    ),
                    if (_updating)
                      Container(
                        color: Colors.black45,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
    );
  }

  Widget _buildList() {
    final visible = _visible;
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: visible.isEmpty ? 2 : visible.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _buildHeader();
        if (visible.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D2D),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'No ${_filter.toLowerCase()} requests.',
              style: TextStyle(color: Colors.grey[400]),
            ),
          );
        }
        final request = visible[index - 1];
        return FoodDriverMoneyRequestCard(
          request: request,
          driver: _drivers[request.driverId],
          payoutMethod: _payoutMethods[request.driverId],
          busy: _updating,
          onMarkPaid: () => _confirmMarkPaid(request),
        );
      },
    );
  }

  Widget _buildHeader() {
    final pendingCount = _requests.where((r) => !r.sent).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pending: $pendingCount request${pendingCount == 1 ? '' : 's'} · '
            '\$${_pendingTotal.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _filters
                .map(
                  (f) => ChoiceChip(
                    label: Text(f),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                    selectedColor: Colors.deepPurpleAccent.withOpacity(0.3),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Error: $_error',
            style: const TextStyle(color: Colors.redAccent),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _fetch, child: const Text('Retry')),
        ],
      ),
    );
  }
}
