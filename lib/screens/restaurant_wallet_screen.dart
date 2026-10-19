import 'package:flutter/material.dart';
import '../models/partner_payout_method_model.dart';
import '../models/restaurant_model.dart';
import '../models/restaurant_wallet_model.dart';
import '../services/supabase_service.dart';
import '../widgets/payout_method_box.dart';

class RestaurantWalletScreen extends StatefulWidget {
  final RestaurantModel restaurant;

  const RestaurantWalletScreen({super.key, required this.restaurant});

  @override
  State<RestaurantWalletScreen> createState() => _RestaurantWalletScreenState();
}

class _RestaurantWalletScreenState extends State<RestaurantWalletScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<RestaurantWalletModel> _entries = [];
  PartnerPayoutMethodModel? _payoutMethod;
  bool _isLoading = true;
  bool _updating = false;
  String? _error;

  List<RestaurantWalletModel> get _pending =>
      _entries.where((e) => e.countsInBalance).toList();

  List<RestaurantWalletModel> get _sent =>
      _entries.where((e) => !e.countsInBalance).toList();

  /// Same balance the restaurant app shows (`sent` / `via_stripe` = false).
  double get _balance =>
      _pending.fold<double>(0, (sum, e) => sum + e.amount);

  double get _alreadyPaid =>
      _sent.fold<double>(0, (sum, e) => sum + e.amount);

  @override
  void initState() {
    super.initState();
    _fetchWallet();
  }

  Future<void> _fetchWallet() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _supabaseService.getRestaurantWalletByResId(widget.restaurant.id),
        _supabaseService.getPayoutMethod(
          PartnerPayoutMethodModel.typeRestaurant,
          widget.restaurant.id.toString(),
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _entries = results[0] as List<RestaurantWalletModel>;
        _payoutMethod = results[1] as PartnerPayoutMethodModel?;
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

  Future<void> _confirmMarkReceived(RestaurantWalletModel entry) async {
    final name = widget.restaurant.name ?? 'this restaurant';
    final label = entry.orderId != null
        ? 'order #${entry.orderId}'
        : 'entry #${entry.id}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2D),
        title: const Text(
          'Confirm payment received?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure "$name" received ${entry.formattedAmount} for $label?\n\n'
          'This will set sent = true and remove it from the wallet balance.',
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
            child: const Text('Yes, received'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _markSent(entry);
    }
  }

  Future<void> _confirmMarkAllPendingReceived() async {
    if (_pending.isEmpty) return;
    final name = widget.restaurant.name ?? 'this restaurant';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2D),
        title: const Text(
          'Confirm full payout?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure "$name" received the full pending amount '
          '\$${_balance.toStringAsFixed(2)} '
          '(${_pending.length} transaction${_pending.length == 1 ? '' : 's'})?\n\n'
          'All pending rows will be marked sent = true.',
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
            child: const Text('Yes, all received'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _markAllPendingSent();
    }
  }

  Future<void> _markSent(RestaurantWalletModel entry) async {
    setState(() => _updating = true);
    try {
      await _supabaseService.markRestaurantWalletSent(entry.id);
      if (!mounted) return;
      setState(() {
        _entries = _entries
            .map((e) => e.id == entry.id ? e.copyWith(isSent: true) : e)
            .toList();
        _updating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marked as received — removed from balance'),
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

  Future<void> _markAllPendingSent() async {
    setState(() => _updating = true);
    try {
      final ids = _pending.map((e) => e.id).toList();
      await _supabaseService.markRestaurantWalletEntriesSent(ids);
      if (!mounted) return;
      setState(() {
        _entries = _entries.map((e) => e.copyWith(isSent: true)).toList();
        _updating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All pending amounts marked as received'),
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
    final name = widget.restaurant.name ?? 'Restaurant';
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '$name wallet',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading || _updating ? null : _fetchWallet,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Error: $_error',
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchWallet,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: _fetchWallet,
                      child: ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          _buildBalanceCard(),
                          const SizedBox(height: 16),
                          PayoutMethodBox(method: _payoutMethod),
                          const SizedBox(height: 20),
                          _sectionTitle(
                            'Pending payout (${_pending.length})',
                            'Only these count in balance',
                          ),
                          const SizedBox(height: 10),
                          if (_pending.isEmpty)
                            _emptyBox('No pending amounts. All paid out.')
                          else
                            ..._pending.map(_buildEntryCard),
                          const SizedBox(height: 20),
                          _sectionTitle(
                            'Already paid (${_sent.length})',
                            'sent / via Stripe — not in balance',
                          ),
                          const SizedBox(height: 10),
                          if (_sent.isEmpty)
                            _emptyBox('No paid-out transactions yet.')
                          else
                            ..._sent.map(_buildEntryCard),
                        ],
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

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
      ],
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: TextStyle(color: Colors.grey[400])),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.shade700,
            Colors.deepPurpleAccent.shade200,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                'Amount owed (same as restaurant app)',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '\$${_balance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Already paid out: \$${_alreadyPaid.toStringAsFixed(2)}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 12.5,
            ),
          ),
          if (_pending.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _updating ? null : _confirmMarkAllPendingReceived,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.deepPurple.shade800,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.verified_outlined),
                label: const Text(
                  'Mark all pending as received',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEntryCard(RestaurantWalletModel entry) {
    final sent = !entry.countsInBalance;
    final accent = sent ? Colors.grey : const Color(0xFF3DDC97);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: sent
              ? Colors.white.withOpacity(0.04)
              : accent.withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              sent ? Icons.check_circle_outline : Icons.pending_actions,
              color: accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.orderId != null
                      ? 'Order #${entry.orderId}'
                      : 'Wallet entry #${entry.id}',
                  style: TextStyle(
                    color: sent ? Colors.grey[400] : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.formattedDate,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  sent
                      ? (entry.viaStripe ? 'Paid via Stripe' : 'Received (sent)')
                      : 'Pending payout',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                entry.formattedAmount,
                style: TextStyle(
                  color: sent ? Colors.grey[400] : accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              if (!sent) ...[
                const SizedBox(height: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.tealAccent,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed:
                      _updating ? null : () => _confirmMarkReceived(entry),
                  child: const Text(
                    'Mark received',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
