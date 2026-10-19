import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/admin_notification_sender.dart';
import '../services/supabase_service.dart';
import '../services/excel_export_service.dart';
import '../widgets/custom_drawer.dart';
import 'user_detail_screen.dart';
import '../widgets/firebase_storage_image.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key, this.snackbarOnOpen});

  /// Shown once after navigation (e.g. after adding an admin).
  final String? snackbarOnOpen;

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();

  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;
  bool _isExporting = false;
  String? _error;

  String? _pushTokenFor(UserModel user) {
    final device = user.deviceToken?.trim();
    if (device != null && device.isNotEmpty) return device;
    final fcm = user.fcmToken?.trim();
    if (fcm != null && fcm.isNotEmpty) return fcm;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    final msg = widget.snackbarOnOpen;
    if (msg != null && msg.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.green.shade800,
          ),
        );
      });
    }
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final users = await _supabaseService.getUsers();
      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterUsers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _allUsers;
      } else {
        _filteredUsers =
            _allUsers.where((user) {
              final name = user.name?.toLowerCase() ?? '';
              final email = user.email?.toLowerCase() ?? '';
              final phone = user.phone?.toLowerCase() ?? '';
              final searchLower = query.toLowerCase();
              return name.contains(searchLower) ||
                  email.contains(searchLower) ||
                  phone.contains(searchLower);
            }).toList();
      }
    });
  }

  Future<void> _exportExcel() async {
    if (_isExporting) return;
    if (_filteredUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No rows to export')),
      );
      return;
    }
    setState(() => _isExporting = true);
    try {
      await ExcelExportService.exportSheet(
        sheetName: 'Users',
        headers: const ['ID', 'Name', 'Email', 'Phone', 'Type', 'Created At'],
        rows: ExcelExportService.rowsFromUsers(_filteredUsers),
        fileName: ExcelExportService.fileName('users'),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${_filteredUsers.length} users'),
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
      drawer: const CustomDrawer(activeItem: 'Users'),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'User Management',
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
              _fetchUsers();
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
                        : _filteredUsers.isEmpty
                        ? const Center(child: Text('No users found.'))
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
          child: TextField(
            controller: _searchController,
            onChanged: _filterUsers,
            decoration: InputDecoration(
              hintText: 'Search by name, email, or phone...',
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
                          _filterUsers('');
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
            DataColumn(label: Text('EMAIL', style: _headerStyle)),
            DataColumn(label: Text('PHONE', style: _headerStyle)),
            DataColumn(label: Text('TYPE', style: _headerStyle)),
            DataColumn(label: Text('CREATED AT', style: _headerStyle)),
            DataColumn(label: Text('ACTIONS', style: _headerStyle)),
          ],
          rows: _filteredUsers.map((user) => _buildDataRow(user)).toList(),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(UserModel user) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1D2D),
            title: const Text('Confirm Deletion'),
            content: Text('Are you sure you want to delete user ${user.name}?'),
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
                onPressed: () {
                  Navigator.pop(context);
                  _deleteUser(user);
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

  Future<void> _deleteUser(UserModel user) async {
    try {
      await _supabaseService.deleteUser(user.id);
      setState(() {
        _allUsers.removeWhere((u) => u.id == user.id);
        _filteredUsers.removeWhere((u) => u.id == user.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User ${user.name} deleted successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
            onPressed: _fetchUsers,
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
          'Total Users',
          '${_allUsers.length}',
          Icons.people_outline,
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

  DataRow _buildDataRow(UserModel user) {
    return DataRow(
      cells: [
        DataCell(
          FirebaseStorageImage.avatar(
            imageUrl: user.profile,
            label: user.name,
            radius: 20,
            backgroundColor: Colors.deepPurple,
          ),
        ),
        DataCell(
          Text(
            user.name ?? 'N/A',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        DataCell(
          Text(user.email ?? 'N/A', style: TextStyle(color: Colors.grey[400])),
        ),
        DataCell(Text(user.phone ?? 'N/A')),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getTypeColor(user.userType).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getTypeColor(user.userType).withOpacity(0.2),
              ),
            ),
            child: Text(
              user.userType?.toUpperCase() ?? 'UNKNOWN',
              style: TextStyle(
                color: _getTypeColor(user.userType),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        DataCell(
          Text(user.formattedDate, style: TextStyle(color: Colors.grey[400])),
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
                      builder: (context) => UserDetailScreen(user: user),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.visibility_outlined,
                  color: Colors.deepPurpleAccent,
                ),
                tooltip: 'View Rides & Orders',
              ),
              IconButton(
                onPressed: _pushTokenFor(user) != null
                    ? () => _showNotificationDialog(user)
                    : null,
                icon: Icon(
                  Icons.notifications_outlined,
                  color: _pushTokenFor(user) != null
                      ? Colors.blueAccent
                      : Colors.grey,
                ),
                tooltip: _pushTokenFor(user) != null
                    ? 'Send Notification'
                    : 'No device token',
              ),
              IconButton(
                onPressed: () => _showDeleteConfirmation(user),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                tooltip: 'Delete User',
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showNotificationDialog(UserModel user) {
    final token = _pushTokenFor(user);
    if (token == null) return;

    final titleController = TextEditingController();
    final messageController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2D),
        title: Text('Send Notification to ${user.name ?? 'user'}'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(color: Colors.grey),
                    hintText: 'Enter notification title',
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: messageController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    labelStyle: TextStyle(color: Colors.grey),
                    hintText: 'Enter notification message',
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Message is required' : null,
                ),
              ],
            ),
          ),
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
              backgroundColor: Colors.blueAccent,
            ),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context, {
                'title': titleController.text.trim(),
                'body': messageController.text.trim(),
              });
            },
            child: const Text(
              'Send',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    ).then((result) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        titleController.dispose();
        messageController.dispose();
      });
      if (result == null || !mounted) return;
      _sendNotification(user, token, result['title']!, result['body']!);
    });
  }

  Future<void> _sendNotification(
    UserModel user,
    String token,
    String title,
    String message,
  ) async {
    final result = await AdminNotificationSender.send(
      recipientType: 'user',
      recipientId: user.id,
      deviceToken: token,
      title: title,
      body: message,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${user.name ?? 'User'}: ${result.message}'),
        backgroundColor: result.ok ? Colors.green : Colors.red,
      ),
    );
  }

  Color _getTypeColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'admin':
        return Colors.redAccent;
      case 'driver':
        return Colors.greenAccent;
      case 'user':
        return Colors.blueAccent;
      default:
        return Colors.grey;
    }
  }

  static const _headerStyle = TextStyle(
    fontWeight: FontWeight.bold,
    color: Colors.deepPurpleAccent,
    letterSpacing: 1.1,
  );
}
