import 'package:flutter/material.dart';
import '../models/customer_support_model.dart';
import '../services/supabase_service.dart';
import '../widgets/custom_drawer.dart';
import 'users_list_screen.dart';

class CustomerSupportListScreen extends StatefulWidget {
  const CustomerSupportListScreen({super.key});

  @override
  State<CustomerSupportListScreen> createState() =>
      _CustomerSupportListScreenState();
}

class _CustomerSupportListScreenState extends State<CustomerSupportListScreen> {
  final _supabase = SupabaseService();
  List<CustomerSupportModel> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _supabase.getCustomerSupportUsers();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _showDialogForm({CustomerSupportModel? existing}) async {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final passCtrl = TextEditingController(text: existing?.password ?? '');
    final rateCtrl = TextEditingController(
      text: existing != null ? existing.rate.toString() : '0',
    );
    final typeCtrl = TextEditingController(text: existing?.type ?? '');
    final tokenCtrl = TextEditingController(text: existing?.deviceToken ?? '');
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1D2D),
            title: Text(
              isEdit ? 'Edit Customer Support' : 'Add Customer Support',
              style: const TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _field(nameCtrl, 'Name'),
                    const SizedBox(height: 12),
                    _field(emailCtrl, 'Email'),
                    const SizedBox(height: 12),
                    _field(passCtrl, 'Password'),
                    const SizedBox(height: 12),
                    _field(rateCtrl, 'Rate', isNumber: true),
                    const SizedBox(height: 12),
                    _field(typeCtrl, 'Type'),
                    const SizedBox(height: 12),
                    _field(tokenCtrl, 'Device Token'),
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

    if (ok != true) {
      nameCtrl.dispose();
      emailCtrl.dispose();
      passCtrl.dispose();
      rateCtrl.dispose();
      typeCtrl.dispose();
      tokenCtrl.dispose();
      return;
    }

    final model = CustomerSupportModel(
      id: existing?.id ?? 0,
      name: nameCtrl.text,
      email: emailCtrl.text,
      password: passCtrl.text,
      rate: double.tryParse(rateCtrl.text.trim()) ?? 0,
      type: typeCtrl.text,
      deviceToken: tokenCtrl.text,
    );

    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    rateCtrl.dispose();
    typeCtrl.dispose();
    tokenCtrl.dispose();

    try {
      if (isEdit) {
        await _supabase.updateCustomerSupport(model);
        if (!mounted) return;
        _showSuccessThenGoDashboard('Customer support updated successfully');
      } else {
        await _supabase.insertCustomerSupport(model);
        if (!mounted) return;
        _showSuccessThenGoDashboard('Customer support added successfully');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _delete(CustomerSupportModel item) async {
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1D2D),
            title: const Text(
              'Delete customer support?',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              item.email ?? 'ID: ${item.id}',
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
    if (yes != true) return;
    try {
      await _supabase.deleteCustomerSupport(item.id);
      if (!mounted) return;
      _showSuccessThenGoDashboard('Customer support removed successfully');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
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

  static Widget _field(
    TextEditingController ctrl,
    String label, {
    bool isNumber = false,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      drawer: const CustomDrawer(activeItem: 'Customer Support'),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Customer Support',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
        actions: [
          IconButton(
            onPressed: () => _showDialogForm(),
            icon: const Icon(Icons.person_add_alt_1, color: Colors.greenAccent),
            tooltip: 'Add',
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
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
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
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Email')),
                          DataColumn(label: Text('Rate')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Device Token')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows:
                            _items
                                .map(
                                  (e) => DataRow(
                                    cells: [
                                      DataCell(Text('${e.id}')),
                                      DataCell(Text(e.name ?? '')),
                                      DataCell(Text(e.email ?? '')),
                                      DataCell(Text(e.rate.toString())),
                                      DataCell(Text(e.type ?? '')),
                                      DataCell(
                                        SizedBox(
                                          width: 180,
                                          child: Text(
                                            e.deviceToken ?? '',
                                            overflow: TextOverflow.ellipsis,
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
                                                color: Colors.blueAccent,
                                                size: 20,
                                              ),
                                              onPressed:
                                                  () => _showDialogForm(
                                                    existing: e,
                                                  ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.redAccent,
                                                size: 20,
                                              ),
                                              onPressed: () => _delete(e),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  ),
                ),
      ),
    );
  }
}
