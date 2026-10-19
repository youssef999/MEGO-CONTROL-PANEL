import 'package:flutter/material.dart';
import '../models/driver_model.dart';
import '../services/account_decision_notifier.dart';
import '../services/supabase_service.dart';
import '../services/excel_export_service.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/reject_reason_dialog.dart';
import 'driver_detail_screen.dart';
import '../widgets/firebase_storage_image.dart';

class DriversListScreen extends StatefulWidget {
  const DriversListScreen({super.key});

  @override
  State<DriversListScreen> createState() => _DriversListScreenState();
}

class _DriversListScreenState extends State<DriversListScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();

  List<DriverModel> _allDrivers = [];
  List<DriverModel> _filteredDrivers = [];
  bool _isLoading = true;
  bool _isExporting = false;
  String? _error;
  /// `all` | `ride` | `food`
  String _selectedType = 'all';

  @override
  void initState() {
    super.initState();
    _fetchDrivers();
  }

  String _driverType(DriverModel driver) {
    final t = driver.type?.trim().toLowerCase();
    if (t == null || t.isEmpty) return 'ride';
    return t;
  }

  int get _rideCount =>
      _allDrivers.where((d) => _driverType(d) == 'ride').length;
  int get _foodCount =>
      _allDrivers.where((d) => _driverType(d) == 'food').length;

  Future<void> _fetchDrivers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final drivers = await _supabaseService.getDrivers();
      setState(() {
        _allDrivers = drivers;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterDrivers(String query) {
    setState(_applyFilters);
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    _filteredDrivers = _allDrivers.where((driver) {
      final type = _driverType(driver);
      final matchesType =
          _selectedType == 'all' || type == _selectedType;
      if (!matchesType) return false;
      if (query.isEmpty) return true;
      final name = driver.name?.toLowerCase() ?? '';
      final email = driver.email?.toLowerCase() ?? '';
      final phone = driver.phone?.toLowerCase() ?? '';
      final city = driver.city?.toLowerCase() ?? '';
      return name.contains(query) ||
          email.contains(query) ||
          phone.contains(query) ||
          city.contains(query);
    }).toList();
  }

  Future<void> _exportExcel() async {
    if (_isExporting) return;
    if (_filteredDrivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No rows to export')),
      );
      return;
    }
    setState(() => _isExporting = true);
    try {
      await ExcelExportService.exportSheet(
        sheetName: 'Drivers',
        headers: const [
          'ID',
          'Name',
          'Email',
          'Phone',
          'Type',
          'Car Info',
          'Rate',
          'Status',
          'City',
          'Created At',
        ],
        rows: ExcelExportService.rowsFromDrivers(_filteredDrivers),
        fileName: ExcelExportService.fileName('drivers'),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${_filteredDrivers.length} drivers'),
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      drawer: const CustomDrawer(activeItem: 'Drivers'),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Driver Management',
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
              _selectedType = 'all';
              _fetchDrivers();
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
            const SizedBox(height: 24),
            _buildTypeFilters(),
            const SizedBox(height: 16),
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
                        : _filteredDrivers.isEmpty
                        ? const Center(child: Text('No drivers found.'))
                        : _buildDataTable(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeFilters() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _typeTab('All', 'all', _allDrivers.length, Colors.deepPurpleAccent),
          _typeTab('Ride', 'ride', _rideCount, Colors.blueAccent),
          _typeTab('Food', 'food', _foodCount, Colors.orangeAccent),
        ],
      ),
    );
  }

  Widget _typeTab(String label, String value, int count, Color color) {
    final selected = _selectedType == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            _selectedType = value;
            _applyFilters();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.22) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.grey[400],
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withOpacity(0.35)
                      : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            onChanged: _filterDrivers,
            decoration: InputDecoration(
              hintText: 'Search by name, email, phone, or city...',
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
                          _filterDrivers('');
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
            DataColumn(label: Text('PROFILE', style: _headerStyle)),
            DataColumn(label: Text('NAME', style: _headerStyle)),
            DataColumn(label: Text('EMAIL / PHONE', style: _headerStyle)),
            DataColumn(label: Text('CAR INFO', style: _headerStyle)),
            DataColumn(label: Text('TYPE', style: _headerStyle)),
            DataColumn(label: Text('RATE', style: _headerStyle)),
            DataColumn(label: Text('STATUS', style: _headerStyle)),
            DataColumn(label: Text('ACTIONS', style: _headerStyle)),
          ],
          rows:
              _filteredDrivers.map((driver) => _buildDataRow(driver)).toList(),
        ),
      ),
    );
  }

  DataRow _buildDataRow(DriverModel driver) {
    return DataRow(
      cells: [
        DataCell(
          FirebaseStorageImage.avatar(
            imageUrl: driver.profileImage,
            label: driver.name,
            radius: 20,
            backgroundColor: Colors.deepPurple,
          ),
        ),
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                driver.name ?? 'N/A',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                driver.city ?? 'Unknown City',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
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
                driver.email ?? 'N/A',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
              Text(driver.phone ?? 'N/A', style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
        DataCell(
          Text(driver.carDescription, style: const TextStyle(fontSize: 13)),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (driver.type?.toLowerCase() == 'food'
                      ? Colors.orange
                      : Colors.blue)
                  .withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (driver.type?.toLowerCase() == 'food'
                        ? Colors.orange
                        : Colors.blue)
                    .withOpacity(0.3),
              ),
            ),
            child: Text(
              (driver.type?.isNotEmpty == true)
                  ? (driver.type!.toUpperCase())
                  : 'RIDE',
              style: TextStyle(
                color: driver.type?.toLowerCase() == 'food'
                    ? Colors.orangeAccent
                    : Colors.blueAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: Colors.orange, size: 16),
              const SizedBox(width: 4),
              Text(driver.rate.toStringAsFixed(1)),
            ],
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (driver.activated
                      ? Colors.greenAccent
                      : Colors.orangeAccent)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (driver.activated
                        ? Colors.greenAccent
                        : Colors.orangeAccent)
                    .withOpacity(0.2),
              ),
            ),
            child: Text(
              driver.activated ? 'ACTIVATED' : 'PENDING',
              style: TextStyle(
                color:
                    driver.activated ? Colors.greenAccent : Colors.orangeAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DriverDetailScreen(driver: driver),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.visibility_outlined,
                  color: Colors.deepPurpleAccent,
                ),
                tooltip: 'View Rides',
              ),
              if (!driver.activated) ...[
                IconButton(
                  onPressed: () => _updateDriverStatus(driver, true),
                  icon: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.greenAccent,
                  ),
                  tooltip: 'Accept Driver',
                ),
                IconButton(
                  onPressed: () => _rejectDriver(driver, blocked: false),
                  icon: const Icon(
                    Icons.gpp_bad_outlined,
                    color: Colors.orangeAccent,
                  ),
                  tooltip: 'Reject with reason',
                ),
              ],
              if (driver.activated)
                IconButton(
                  onPressed: () => _rejectDriver(driver, blocked: true),
                  icon: const Icon(
                    Icons.block_outlined,
                    color: Colors.orangeAccent,
                  ),
                  tooltip: 'Decline Driver (with reason)',
                ),
              IconButton(
                onPressed: () => _showDeleteConfirmation(driver),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                tooltip: 'Delete Driver',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _updateDriverStatus(DriverModel driver, bool activate) async {
    final action = activate ? 'Accept' : 'Decline';
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1D2D),
            title: Text('$action Driver'),
            content: Text(
              activate
                  ? 'Are you sure you want to $action ${driver.name}?\n\n'
                      'A welcome notification will be sent to their in-app inbox + push.'
                  : 'Are you sure you want to $action ${driver.name}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      activate ? Colors.greenAccent : Colors.orangeAccent,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  action,
                  style: const TextStyle(color: Colors.black87),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await _supabaseService.updateDriverStatus(driver.id, activate);
        final notify =
            activate ? await AccountDecisionNotifier.driverApproved(driver) : null;
        _fetchDrivers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Driver ${driver.name} is now ${activate ? 'activated' : 'deactivated'}.'
                '${notify != null ? ' — ${notify.message}' : ''}',
              ),
              backgroundColor: notify == null || notify.ok
                  ? Colors.green
                  : Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update driver: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Reject a pending driver or deactivate an active one, and notify them
  /// (in-app inbox + push) with the reason.
  Future<void> _rejectDriver(DriverModel driver, {required bool blocked}) async {
    final reason = await showRejectReasonDialog(
      context,
      title: blocked ? 'Decline driver' : 'Reject driver',
      subjectName: driver.name ?? driver.email ?? driver.phone ?? driver.id,
      confirmLabel: blocked ? 'Decline & notify' : 'Reject & notify',
      recipientLabel: 'driver',
      presetReasons: AccountDecisionNotifier.driverReasons,
    );
    if (reason == null || !mounted) return;

    try {
      if (driver.activated) {
        await _supabaseService.updateDriverStatus(driver.id, false);
      }
      final result = await AccountDecisionNotifier.driver(
        driver,
        reason: reason,
        blocked: blocked,
      );
      _fetchDrivers();
      if (!mounted) return;
      final name = driver.name ?? 'Driver';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${blocked ? '$name deactivated' : '$name rejected'} — ${result.message}',
          ),
          backgroundColor: result.ok ? Colors.orange : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update driver: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmation(DriverModel driver) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1D2D),
            title: const Text('Confirm Deletion'),
            content: Text(
              'Are you sure you want to delete driver ${driver.name}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await _supabaseService.deleteDriver(driver.id);
                    _fetchDrivers();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Driver ${driver.name} deleted successfully.',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to delete driver: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
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
            onPressed: _fetchDrivers,
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
          'Total Drivers',
          '${_allDrivers.length}',
          Icons.drive_eta_outlined,
          Colors.green,
        ),
        const SizedBox(width: 24),
        _buildStatCard(
          'Pending Approval',
          '${_allDrivers.where((d) => !d.activated).length}',
          Icons.pending_actions,
          Colors.orange,
        ),
        const SizedBox(width: 24),
        _buildStatCard(
          'Online Now',
          '${_allDrivers.where((d) => d.online).length}',
          Icons.bolt,
          Colors.blue,
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
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
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
  );
}
