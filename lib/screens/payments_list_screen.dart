import 'package:flutter/material.dart';
import '../models/payment_model.dart';
import '../services/supabase_service.dart';
import '../widgets/custom_drawer.dart';

class PaymentsListScreen extends StatefulWidget {
  const PaymentsListScreen({super.key});

  @override
  State<PaymentsListScreen> createState() => _PaymentsListScreenState();
}

class _PaymentsListScreenState extends State<PaymentsListScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();

  List<PaymentModel> _allPayments = [];
  List<PaymentModel> _filteredPayments = [];
  bool _isLoading = true;
  String? _error;
  String _selectedStatus = 'All';

  final List<String> _statuses = ['All', 'pending', 'success', 'failed'];

  @override
  void initState() {
    super.initState();
    _fetchPayments();
  }

  Future<void> _fetchPayments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final payments = await _supabaseService.getPayments();
      setState(() {
        _allPayments = payments;
        _filterPayments();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterPayments() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      _filteredPayments =
          _allPayments.where((payment) {
            bool matchesStatus = true;
            if (_selectedStatus != 'All') {
              matchesStatus =
                  payment.status.toLowerCase() == _selectedStatus.toLowerCase();
            }

            final matchesSearch =
                payment.id.toLowerCase().contains(query) ||
                (payment.rideId?.toLowerCase().contains(query) ?? false) ||
                (payment.paymentMethod?.toLowerCase().contains(query) ?? false);
            return matchesStatus && matchesSearch;
          }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      drawer: const CustomDrawer(activeItem: 'Payments'),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Payments Management',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            onPressed: () {
              _searchController.clear();
              _selectedStatus = 'All';
              _fetchPayments();
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
                        : _filteredPayments.isEmpty
                        ? const Center(child: Text('No payments found.'))
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
            onChanged: (_) => _filterPayments(),
            decoration: InputDecoration(
              hintText: 'Search by ID, Ride ID, or Method...',
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
                          _filterPayments();
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
                    _filterPayments();
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
          headingRowHeight: 60,
          dataRowMaxHeight: 70,
          columns: const [
            DataColumn(label: Text('DATE', style: _headerStyle)),
            DataColumn(label: Text('AMOUNT', style: _headerStyle)),
            DataColumn(label: Text('METHOD', style: _headerStyle)),
            DataColumn(label: Text('RIDE ID', style: _headerStyle)),
            DataColumn(label: Text('STATUS', style: _headerStyle)),
          ],
          rows:
              _allPayments.isEmpty
                  ? []
                  : _filteredPayments
                      .map((payment) => _buildDataRow(payment))
                      .toList(),
        ),
      ),
    );
  }

  DataRow _buildDataRow(PaymentModel payment) {
    final status = payment.status.toLowerCase();
    Color statusColor = Colors.orangeAccent;
    if (status == 'success') statusColor = Colors.greenAccent;
    if (status == 'failed') statusColor = Colors.redAccent;

    return DataRow(
      cells: [
        DataCell(
          Text(
            payment.formattedCreatedAt,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        DataCell(
          Text(
            payment.formattedAmount,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        DataCell(
          Text(
            payment.paymentMethod?.toUpperCase() ?? 'N/A',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ),
        DataCell(
          Text(
            payment.rideId?.substring(0, 8) ?? 'N/A',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withOpacity(0.2)),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
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
            onPressed: _fetchPayments,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    double totalAmount = _allPayments
        .where((p) => p.status.toLowerCase() == 'success')
        .fold(0, (sum, p) => sum + p.amount);

    return Row(
      children: [
        _buildStatCard(
          'Total Success',
          '\$${totalAmount.toStringAsFixed(2)}',
          Icons.payments_outlined,
          Colors.green,
        ),
        const SizedBox(width: 24),
        _buildStatCard(
          'Pending',
          '${_allPayments.where((p) => p.status.toLowerCase() == 'pending').length}',
          Icons.history,
          Colors.orange,
        ),
        const SizedBox(width: 24),
        _buildStatCard(
          'Failed',
          '${_allPayments.where((p) => p.status.toLowerCase() == 'failed').length}',
          Icons.error_outline,
          Colors.red,
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
