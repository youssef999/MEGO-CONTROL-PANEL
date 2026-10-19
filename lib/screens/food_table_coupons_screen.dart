import 'package:flutter/material.dart';
import '../models/food_table_coupon_model.dart';
import '../models/user_model.dart';
import '../services/supabase_service.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/firebase_storage_image.dart';

class FoodTableCouponsScreen extends StatefulWidget {
  const FoodTableCouponsScreen({super.key});

  @override
  State<FoodTableCouponsScreen> createState() => _FoodTableCouponsScreenState();
}

class _FoodTableCouponsScreenState extends State<FoodTableCouponsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();

  List<FoodTableCouponModel> _allCoupons = [];
  List<FoodTableCouponModel> _filteredCoupons = [];
  List<UserModel> _users = [];
  bool _isLoading = true;
  String? _error;
  String _selectedStatus = 'All';

  final List<String> _statuses = ['All', 'Active', 'Inactive', 'Expired'];

  Map<String, UserModel> get _userById => {for (final u in _users) u.id: u};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final coupons = await _supabaseService.getFoodTableCoupons();
      final users = await _supabaseService.getUsers();
      if (!mounted) return;
      setState(() {
        _allCoupons = coupons;
        _users = users;
        _filterCoupons();
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

  void _filterCoupons() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      _filteredCoupons =
          _allCoupons.where((coupon) {
            bool matchesStatus = true;
            if (_selectedStatus == 'Active') {
              matchesStatus = coupon.active && !coupon.isExpired;
            } else if (_selectedStatus == 'Inactive') {
              matchesStatus = !coupon.active;
            } else if (_selectedStatus == 'Expired') {
              matchesStatus = coupon.isExpired;
            }

            final userLabel = _resolveUserLabel(coupon).toLowerCase();
            final matchesSearch =
                coupon.id.toLowerCase().contains(query) ||
                (coupon.userId?.toLowerCase().contains(query) ?? false) ||
                (coupon.userEmail?.toLowerCase().contains(query) ?? false) ||
                (coupon.type?.toLowerCase().contains(query) ?? false) ||
                (coupon.couponFor?.toLowerCase().contains(query) ?? false) ||
                userLabel.contains(query);
            return matchesStatus && matchesSearch;
          }).toList();
    });
  }

  String _resolveUserLabel(FoodTableCouponModel coupon) {
    if (coupon.userId == null || coupon.userId!.isEmpty) {
      return 'All users';
    }
    final u = _userById[coupon.userId!];
    if (u != null) {
      final name = u.name?.trim();
      if (name != null && name.isNotEmpty) return name;
      final em = u.email?.trim();
      if (em != null && em.isNotEmpty) return em;
    }
    return coupon.userEmail?.trim().isNotEmpty == true
        ? coupon.userEmail!.trim()
        : (coupon.userId!.length > 10
            ? '${coupon.userId!.substring(0, 8)}…'
            : coupon.userId!);
  }

  Future<void> _openCouponSheet({FoodTableCouponModel? coupon}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: _FoodTableCouponFormSheet(
            coupon: coupon,
            users: _users,
            supabase: _supabaseService,
            onSaved: () {
              Navigator.pop(ctx);
              _fetchData();
            },
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(FoodTableCouponModel coupon) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2D),
        title: const Text(
          'Delete food table coupon?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Type: ${coupon.type ?? "—"}\nThis cannot be undone.',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _supabaseService.deleteFoodTableCoupon(coupon.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coupon deleted'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      drawer: const CustomDrawer(activeItem: 'Food Table Coupons'),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Food Table Coupons',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : () => _openCouponSheet(),
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add coupon',
          ),
          IconButton(
            onPressed: () {
              _searchController.clear();
              _selectedStatus = 'All';
              _fetchData();
            },
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
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
                        : _filteredCoupons.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('No coupons found.'),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: () => _openCouponSheet(),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create coupon'),
                                ),
                              ],
                            ),
                          )
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
            onChanged: (_) => _filterCoupons(),
            decoration: InputDecoration(
              hintText: 'Search by ID, user, email, type, coupon for…',
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
                          _filterCoupons();
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
                    _filterCoupons();
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
          dataRowMaxHeight: 72,
          columns: const [
            DataColumn(label: Text('CREATED AT', style: _headerStyle)),
            DataColumn(label: Text('TYPE', style: _headerStyle)),
            DataColumn(label: Text('COUPON FOR', style: _headerStyle)),
            DataColumn(label: Text('USER', style: _headerStyle)),
            DataColumn(label: Text('VALID UNTIL', style: _headerStyle)),
            DataColumn(label: Text('STATUS', style: _headerStyle)),
            DataColumn(label: Text('ACTIONS', style: _headerStyle)),
          ],
          rows: _filteredCoupons
              .map((coupon) => _buildDataRow(coupon))
              .toList(),
        ),
      ),
    );
  }

  DataRow _buildDataRow(FoodTableCouponModel coupon) {
    final bool isExpired = coupon.isExpired;
    final bool isActive = coupon.active && !isExpired;
    final allUsers =
        coupon.userId == null ||
        coupon.userId!.trim().isEmpty ||
        coupon.userId!.trim().toLowerCase() == 'all' ||
        coupon.userEmail?.trim().toLowerCase() == 'all';
    final u = !allUsers &&
            coupon.userId != null &&
            coupon.userId!.isNotEmpty
        ? _userById[coupon.userId!]
        : null;

    return DataRow(
      cells: [
        DataCell(
          Text(coupon.formattedCreatedAt, style: const TextStyle(fontSize: 13)),
        ),
        DataCell(
          Text(
            coupon.type?.toUpperCase() ?? 'N/A',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        DataCell(
          Text(
            coupon.couponFor ?? 'N/A',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ),
        DataCell(
          allUsers
              ? Text(
                  'All users',
                  style: TextStyle(
                    color: Colors.tealAccent.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                )
              : u != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FirebaseStorageImage.avatar(
                      imageUrl: u.profile,
                      label: u.name,
                      radius: 16,
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            u.name ?? '—',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            u.email ?? coupon.userEmail ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      coupon.userEmail ?? coupon.userId ?? '—',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (coupon.userId != null)
                      Text(
                        'id: ${coupon.userId!.length > 12 ? "${coupon.userId!.substring(0, 8)}…" : coupon.userId}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 10),
                      ),
                  ],
                ),
        ),
        DataCell(
          Text(
            coupon.formattedValidUntil,
            style: TextStyle(
              color: isExpired ? Colors.redAccent : Colors.grey[400],
              fontSize: 13,
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (isActive
                      ? Colors.greenAccent
                      : (isExpired ? Colors.redAccent : Colors.orangeAccent))
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (isActive
                        ? Colors.greenAccent
                        : (isExpired ? Colors.redAccent : Colors.orangeAccent))
                    .withOpacity(0.2),
              ),
            ),
            child: Text(
              isExpired ? 'EXPIRED' : (isActive ? 'ACTIVE' : 'INACTIVE'),
              style: TextStyle(
                color:
                    isActive
                        ? Colors.greenAccent
                        : (isExpired ? Colors.redAccent : Colors.orangeAccent),
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
              IconButton(
                onPressed: () => _openCouponSheet(coupon: coupon),
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Colors.blueAccent,
                  size: 20,
                ),
                tooltip: 'Edit coupon',
              ),
              IconButton(
                onPressed: () => _confirmDelete(coupon),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 20,
                ),
                tooltip: 'Delete coupon',
              ),
            ],
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
            onPressed: _fetchData,
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
          'Total Table Coupons',
          '${_allCoupons.length}',
          Icons.table_chart_outlined,
          Colors.blue,
        ),
        const SizedBox(width: 24),
        _buildStatCard(
          'Active',
          '${_allCoupons.where((c) => c.active && !c.isExpired).length}',
          Icons.check_circle_outline,
          Colors.green,
        ),
        const SizedBox(width: 24),
        _buildStatCard(
          'Expired',
          '${_allCoupons.where((c) => c.isExpired).length}',
          Icons.history,
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

class _FoodTableCouponFormSheet extends StatefulWidget {
  final FoodTableCouponModel? coupon;
  final List<UserModel> users;
  final SupabaseService supabase;
  final VoidCallback onSaved;

  const _FoodTableCouponFormSheet({
    required this.coupon,
    required this.users,
    required this.supabase,
    required this.onSaved,
  });

  @override
  State<_FoodTableCouponFormSheet> createState() =>
      _FoodTableCouponFormSheetState();
}

class _FoodTableCouponFormSheetState extends State<_FoodTableCouponFormSheet> {
  late bool _forAllUsers;
  UserModel? _selectedUser;
  static const _discountTypes = [
    'discount_10',
    'discount_20',
    'discount_30',
    'discount_40',
    'discount_50',
  ];
  static const _couponForFixed = 'mego_food_coupon';

  late String _selectedType;
  DateTime? _validUntil;
  late bool _active;
  bool _saving = false;

  bool get _isEdit => widget.coupon != null;

  bool _isAllUsersId(String? id) {
    final v = id?.trim().toLowerCase();
    return v == null || v.isEmpty || v == 'all';
  }

  bool _isAllUsersCoupon(FoodTableCouponModel? c) {
    if (c == null) return true;
    if (_isAllUsersId(c.userId)) return true;
    return c.userEmail?.trim().toLowerCase() == 'all';
  }

  @override
  void initState() {
    super.initState();
    final c = widget.coupon;
    _forAllUsers = _isAllUsersCoupon(c);
    UserModel? match;
    if (!_forAllUsers && c != null && c.userId != null) {
      for (final u in widget.users) {
        if (u.id == c.userId) {
          match = u;
          break;
        }
      }
    }
    _selectedUser = match;
    final existingType = c?.type?.trim();
    _selectedType = (existingType != null && _discountTypes.contains(existingType))
        ? existingType
        : _discountTypes.first;
    _validUntil = c?.validUntil ?? DateTime.now().add(const Duration(days: 30));
    _active = c?.active ?? true;
  }

  Future<void> _pickUser() async {
    final picked = await showModalBottomSheet<UserModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FoodTableUserPickerSheet(users: widget.users),
    );
    if (picked != null) {
      setState(() {
        _selectedUser = picked;
        _forAllUsers = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _validUntil ?? now.add(const Duration(days: 30));
    final d = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.deepPurpleAccent,
              surface: Color(0xFF1A1D2D),
            ),
          ),
          child: child!,
        );
      },
    );
    if (d != null) {
      setState(() => _validUntil = d);
    }
  }

  String _userIdForSave() => _forAllUsers ? 'all' : _selectedUser!.id;

  String _emailForSave() {
    if (_forAllUsers) return 'all';
    final e = _selectedUser!.email?.trim();
    return (e != null && e.isNotEmpty) ? e : 'all';
  }

  Future<void> _save() async {
    if (!_forAllUsers && _selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a user or switch to “All users”.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_validUntil == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick an expiry date.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        final c = widget.coupon!;
        final updated = FoodTableCouponModel(
          id: c.id,
          userId: _userIdForSave(),
          userEmail: _emailForSave(),
          type: _selectedType,
          validUntil: _validUntil,
          active: _active,
          createdAt: c.createdAt,
          updatedAt: DateTime.now().toUtc(),
          couponFor: _couponForFixed,
        );
        await widget.supabase.updateFoodTableCoupon(updated);
      } else {
        await widget.supabase.insertFoodTableCoupon(
          userId: _userIdForSave(),
          userEmail: _emailForSave(),
          type: _selectedType,
          validUntil: _validUntil,
          active: _active,
          couponFor: _couponForFixed,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Coupon updated' : 'Coupon created'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1D2D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isEdit ? 'Edit food table coupon' : 'New food table coupon',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Audience',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('All users'),
                        icon: Icon(Icons.groups_outlined, size: 18),
                      ),
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('One user'),
                        icon: Icon(Icons.person_outline, size: 18),
                      ),
                    ],
                    selected: {_forAllUsers},
                    onSelectionChanged: (s) {
                      setState(() {
                        _forAllUsers = s.first;
                        if (_forAllUsers) _selectedUser = null;
                      });
                    },
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.white;
                        }
                        return Colors.grey;
                      }),
                    ),
                  ),
                  if (!_forAllUsers) ...[
                    const SizedBox(height: 12),
                    Material(
                      color: const Color(0xFF252838),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: _pickUser,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              FirebaseStorageImage.avatar(
                                imageUrl: _selectedUser?.profile,
                                label: _selectedUser?.name,
                                radius: 22,
                                emptyIcon: Icons.person_add_alt_1,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedUser == null
                                          ? 'Tap to select user'
                                          : (_selectedUser!.name ?? 'No name'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (_selectedUser != null)
                                      Text(
                                        _selectedUser!.email ?? '—',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 13,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: Colors.grey[600]),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'Discount type',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    dropdownColor: const Color(0xFF252838),
                    style: const TextStyle(color: Colors.white),
                    decoration: _fieldDecoration('Select discount'),
                    items: _discountTypes
                        .map(
                          (t) => DropdownMenuItem<String>(
                            value: t,
                            child: Text(
                              t.replaceAll('_', ' ').toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedType = v);
                    },
                  ),
                  const SizedBox(height: 14),
                  InputDecorator(
                    decoration: _fieldDecoration('Coupon for'),
                    child: Text(
                      _couponForFixed,
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Valid until',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      _validUntil == null
                          ? 'Pick a date (required)'
                          : '${_validUntil!.year}-${_validUntil!.month.toString().padLeft(2, '0')}-${_validUntil!.day.toString().padLeft(2, '0')}',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                    trailing: const Icon(
                      Icons.calendar_today,
                      color: Colors.deepPurpleAccent,
                    ),
                    onTap: _pickDate,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active', style: TextStyle(color: Colors.white)),
                    value: _active,
                    activeTrackColor: Colors.deepPurpleAccent.withOpacity(0.5),
                    onChanged: (v) => setState(() => _active = v),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child:
                        _saving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_isEdit ? 'Save changes' : 'Create coupon'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[600]),
      filled: true,
      fillColor: const Color(0xFF252838),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.deepPurpleAccent),
      ),
    );
  }
}

class _FoodTableUserPickerSheet extends StatefulWidget {
  final List<UserModel> users;

  const _FoodTableUserPickerSheet({required this.users});

  @override
  State<_FoodTableUserPickerSheet> createState() =>
      _FoodTableUserPickerSheetState();
}

class _FoodTableUserPickerSheetState extends State<_FoodTableUserPickerSheet> {
  final TextEditingController _search = TextEditingController();
  List<UserModel> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = List<UserModel>.from(widget.users);
    _search.addListener(_apply);
  }

  void _apply() {
    final q = _search.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = List<UserModel>.from(widget.users);
      } else {
        _filtered =
            widget.users.where((u) {
              final name = u.name?.toLowerCase() ?? '';
              final email = u.email?.toLowerCase() ?? '';
              final phone = u.phone?.toLowerCase() ?? '';
              return name.contains(q) || email.contains(q) || phone.contains(q);
            }).toList();
      }
    });
  }

  @override
  void dispose() {
    _search.removeListener(_apply);
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1D2D),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _search,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, phone…',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon: const Icon(Icons.search, color: Colors.deepPurpleAccent),
                    filled: true,
                    fillColor: const Color(0xFF252838),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _filtered.length,
                  itemBuilder: (context, i) {
                    final u = _filtered[i];
                    return ListTile(
                      leading: FirebaseStorageImage.avatar(
                        imageUrl: u.profile,
                        label: u.name,
                        radius: 20,
                      ),
                      title: Text(
                        u.name ?? 'No name',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        u.email ?? u.phone ?? u.id,
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.pop(context, u),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
