import 'package:flutter/material.dart';
import '../core/money.dart';
import '../models/ride_model.dart';
import '../services/supabase_service.dart';
import '../widgets/custom_drawer.dart';
import 'ride_detail_screen.dart';

class RidesListScreen extends StatefulWidget {
  const RidesListScreen({super.key});

  @override
  State<RidesListScreen> createState() => _RidesListScreenState();
}

class _RidesListScreenState extends State<RidesListScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();

  List<RideModel> _allRides = [];
  List<RideModel> _filteredRides = [];
  bool _isLoading = true;
  String? _error;
  String _selectedStatus = 'All';

  final List<String> _statuses = [
    'All',
    'arrived',
    'in_progress',
    'in_trip',
    'completed',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _fetchRides();
  }

  Future<void> _fetchRides() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final rides = await _supabaseService.getRides();
      setState(() {
        _allRides = rides;
        _filterRides();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterRides() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      _filteredRides =
          _allRides.where((ride) {
            final matchesStatus =
                _selectedStatus == 'All' ||
                ride.status?.toLowerCase() == _selectedStatus.toLowerCase();
            final matchesSearch =
                ride.id.toLowerCase().contains(query) ||
                (ride.riderId?.toLowerCase().contains(query) ?? false) ||
                (ride.driverId?.toLowerCase().contains(query) ?? false);
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
      drawer: const CustomDrawer(activeItem: 'Rides'),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Rides Management',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            onPressed: () {
              _searchController.clear();
              _selectedStatus = 'All';
              _fetchRides();
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
                        : _filteredRides.isEmpty
                        ? const Center(child: Text('No rides found.'))
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
            onChanged: (_) => _filterRides(),
            decoration: InputDecoration(
              hintText: 'Search by Ride ID, Rider ID, or Driver ID...',
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
                          _filterRides();
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
                    _filterRides();
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
            DataColumn(label: Text('RIDER ID', style: _headerStyle)),
            DataColumn(label: Text('DRIVER ID', style: _headerStyle)),
            DataColumn(label: Text('FARE', style: _headerStyle)),
            DataColumn(label: Text('TIME', style: _headerStyle)),
            DataColumn(label: Text('STATUS', style: _headerStyle)),
            DataColumn(label: Text('ACTIONS', style: _headerStyle)),
          ],
          rows: _filteredRides.map((ride) => _buildDataRow(ride)).toList(),
        ),
      ),
    );
  }

  DataRow _buildDataRow(RideModel ride) {
    return DataRow(
      cells: [
        DataCell(
          Text(ride.formattedCreatedAt, style: const TextStyle(fontSize: 13)),
        ),
        DataCell(
          Text(
            _shortUuid(ride.riderId),
            style: TextStyle(color: Colors.grey[400]),
          ),
        ),
        DataCell(
          Text(
            _shortUuid(ride.driverId),
            style: TextStyle(color: Colors.grey[400]),
          ),
        ),
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatMoney(ride.driverFare),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (ride.hasCouponDiscount)
                Text(
                  'Rider paid ${formatMoney(ride.riderPaid)} • '
                  'Coupon ${formatMoney(ride.couponCovered)}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
            ],
          ),
        ),
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${ride.formattedStartTime} - ${ride.formattedEndTime}',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                ride.duration,
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
            ],
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(ride.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getStatusColor(ride.status).withOpacity(0.2),
              ),
            ),
            child: Text(
              ride.status?.toUpperCase() ?? 'UNKNOWN',
              style: TextStyle(
                color: _getStatusColor(ride.status),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        DataCell(
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => RideDetailScreen(ride: ride),
                ),
              );
            },
            icon: const Icon(
              Icons.remove_red_eye_outlined,
              color: Colors.blueAccent,
            ),
            tooltip: 'View Details',
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.greenAccent;
      case 'in_trip':
        return Colors.blueAccent;
      case 'in_progress':
        return Colors.orangeAccent;
      case 'arrived':
        return Colors.yellowAccent;
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
            onPressed: _fetchRides,
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
          'Total Rides',
          '${_allRides.length}',
          Icons.local_taxi_outlined,
          Colors.blue,
        ),
        const SizedBox(width: 24),
        _buildStatCard(
          'Completed',
          '${_allRides.where((r) => r.status == 'completed').length}',
          Icons.check_circle_outline,
          Colors.green,
        ),
        const SizedBox(width: 24),
        _buildStatCard(
          'Ongoing',
          '${_allRides.where((r) => !r.isCompleted && (r.status ?? '').toLowerCase() != 'cancelled').length}',
          Icons.play_circle_outline,
          Colors.orange,
        ),
        const SizedBox(width: 24),
        _buildStatCard(
          'Fares (completed)',
          formatMoney(
            _allRides
                .where((r) => r.isCompleted)
                .fold<double>(0, (sum, r) => sum + r.driverFare),
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

  static String _shortUuid(String? id) {
    if (id == null || id.isEmpty) return 'N/A';
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}…';
  }

  static const _headerStyle = TextStyle(
    fontWeight: FontWeight.bold,
    color: Colors.deepPurpleAccent,
    letterSpacing: 1.1,
    fontSize: 12,
  );
}
