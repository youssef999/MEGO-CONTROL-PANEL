import 'package:flutter/material.dart';
import '../core/auth_storage.dart';
import '../models/admin_model.dart';
import '../services/supabase_service.dart';
import '../widgets/custom_drawer.dart';
import 'users_list_screen.dart';

class AdminsListScreen extends StatefulWidget {
  const AdminsListScreen({super.key});

  @override
  State<AdminsListScreen> createState() => _AdminsListScreenState();
}

class _AdminsListScreenState extends State<AdminsListScreen> {
  final _supabase = SupabaseService();
  List<AdminModel> _admins = [];
  bool _loading = true;
  String? _error;
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    if (!AuthStorage.isSuperAdmin) {
      _denied = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only the super admin can manage admin accounts.'),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UsersListScreen()),
        );
      });
      return;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _supabase.getAdmins();
      if (mounted) {
        setState(() {
          _admins = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _showAdminDialog({AdminModel? existing}) async {
    final isEdit = existing != null;
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final passCtrl = TextEditingController(text: existing?.password ?? '');
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2D),
        title: Text(
          isEdit ? 'Edit admin' : 'Add admin',
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: emailCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _fieldDecoration('Email'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _fieldDecoration('Password'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
        ],
      ),
    );

    final email = emailCtrl.text;
    final password = passCtrl.text;
    emailCtrl.dispose();
    passCtrl.dispose();

    if (ok != true || !mounted) return;

    try {
      if (isEdit) {
        await _supabase.updateAdmin(
          AdminModel(id: existing.id, email: email, password: password),
        );
        if (!mounted) return;
        _showSuccessThenGoDashboard('Admin updated successfully');
      } else {
        await _supabase.insertAdmin(
          AdminModel(id: 0, email: email, password: password),
        );
        if (!mounted) return;
        _showSuccessThenGoDashboard('Admin added successfully');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  static InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[400]),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.deepPurpleAccent),
      ),
    );
  }

  Future<void> _confirmDelete(AdminModel a) async {
    if (a.id == AuthStorage.superAdminId) return;
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1D2D),
            title: const Text(
              'Delete admin?',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              a.email,
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
    );
    if (yes != true || !mounted) return;
    try {
      await _supabase.deleteAdmin(a.id);
      if (!mounted) return;
      _showSuccessThenGoDashboard('Admin removed successfully');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  void _showSuccessThenGoDashboard(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green.shade800),
    );
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const UsersListScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_denied) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F111A),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      drawer: const CustomDrawer(activeItem: 'Admins'),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Admin accounts',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
        actions: [
          IconButton(
            onPressed: () => _showAdminDialog(),
            icon: const Icon(Icons.person_add_alt_1, color: Colors.greenAccent),
            tooltip: 'Add admin',
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
                : Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1D2D),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('ID')),
                          DataColumn(label: Text('Email')),
                          DataColumn(label: Text('Role')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows:
                            _admins.map((a) {
                              final superA = a.id == AuthStorage.superAdminId;
                              return DataRow(
                                cells: [
                                  DataCell(Text('${a.id}')),
                                  DataCell(Text(a.email)),
                                  DataCell(
                                    Text(
                                      superA ? 'Super admin' : 'Admin',
                                      style: TextStyle(
                                        color:
                                            superA
                                                ? Colors.amberAccent
                                                : Colors.white70,
                                        fontWeight:
                                            superA
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 20,
                                            color: Colors.blueAccent,
                                          ),
                                          onPressed:
                                              () => _showAdminDialog(
                                                existing: a,
                                              ),
                                        ),
                                        if (!superA)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 20,
                                              color: Colors.redAccent,
                                            ),
                                            onPressed: () => _confirmDelete(a),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                      ),
                    ),
                  ),
                ),
      ),
    );
  }
}
