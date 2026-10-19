import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/auth_storage.dart';
import '../models/delivery_fee_model.dart';
import '../services/supabase_service.dart';
import '../widgets/custom_drawer.dart';
import 'users_list_screen.dart';

class DeliveryFeeScreen extends StatefulWidget {
  const DeliveryFeeScreen({super.key});

  @override
  State<DeliveryFeeScreen> createState() => _DeliveryFeeScreenState();
}

class _DeliveryFeeScreenState extends State<DeliveryFeeScreen> {
  static const _bg = Color(0xFF0F111A);
  static const _card = Color(0xFF1A1D2D);

  final _supabase = SupabaseService();
  final _formKey = GlobalKey<FormState>();
  final _priceCtrl = TextEditingController();

  DeliveryFeeModel? _saved;
  bool _loading = true;
  bool _saving = false;
  bool _denied = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (AuthStorage.sessionType != AuthStorage.typeAdmin) {
      _denied = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only admin accounts can manage delivery fee.'),
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

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  String _formatPrice(double? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fee = await _supabase.getDeliveryFee();
      if (!mounted) return;
      setState(() {
        _saved = fee;
        _priceCtrl.text = _formatPrice(fee?.pricePerKm);
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

  String? _validatePrice(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return 'Price per km is required';
    final parsed = double.tryParse(raw);
    if (parsed == null) return 'Enter a valid number';
    if (parsed < 0) return 'Price cannot be negative';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final parsed = double.parse(_priceCtrl.text.trim());
    setState(() => _saving = true);
    try {
      final saved = await _supabase.saveDeliveryFee(
        DeliveryFeeModel(id: _saved?.id, pricePerKm: parsed),
      );
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _priceCtrl.text = _formatPrice(saved.pricePerKm);
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Delivery fee updated.'),
          backgroundColor: Colors.green.shade800,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not save delivery fee. Try again.'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_denied) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      drawer: const CustomDrawer(activeItem: 'Delivery Fee'),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Delivery fee',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
        actions: [
          IconButton(
            onPressed: _loading || _saving ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 36,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _infoBanner(),
                            const SizedBox(height: 20),
                            _currentCard(),
                            const SizedBox(height: 20),
                            _editorCard(),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: _saving ? null : _save,
                                icon: _saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: Text(
                                  _saving ? 'Saving…' : 'Save price per km',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurpleAccent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _infoBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2238),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.deepPurpleAccent.withValues(alpha: 0.3),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.route_outlined, color: Colors.deepPurpleAccent),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'This value is used as the delivery price per kilometer. Changing it updates the live fee for new food orders.',
              style: TextStyle(color: Colors.white70, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _currentCard() {
    final price = _saved?.pricePerKm;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            price == null ? Icons.info_outline : Icons.check_circle_outline,
            color: price == null ? Colors.amberAccent : Colors.greenAccent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current price per km',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  price == null ? 'Not set yet' : _formatPrice(price),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _editorCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Edit delivery fee',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter the numeric price charged for each kilometer.',
            style: TextStyle(color: Colors.grey[400], height: 1.4),
          ),
          const SizedBox(height: 22),
          TextFormField(
            controller: _priceCtrl,
            validator: _validatePrice,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              labelText: 'Price per km',
              hintText: 'e.g. 1.50',
              helperText: 'Must be 0 or greater',
              helperStyle: TextStyle(color: Colors.grey[500]),
              labelStyle: const TextStyle(color: Colors.white70),
              hintStyle: TextStyle(color: Colors.grey[600]),
              filled: true,
              fillColor: const Color(0xFF12141F),
              prefixIcon: const Icon(
                Icons.attach_money,
                color: Colors.white38,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.deepPurpleAccent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
