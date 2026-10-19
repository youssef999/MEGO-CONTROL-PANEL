import 'package:flutter/material.dart';
import '../core/auth_storage.dart';
import '../models/stripe_keys_model.dart';
import '../services/supabase_service.dart';
import '../widgets/custom_drawer.dart';
import 'users_list_screen.dart';

class StripeSettingsScreen extends StatefulWidget {
  const StripeSettingsScreen({super.key});

  @override
  State<StripeSettingsScreen> createState() => _StripeSettingsScreenState();
}

class _StripeSettingsScreenState extends State<StripeSettingsScreen> {
  static const _bg = Color(0xFF0F111A);
  static const _card = Color(0xFF1A1D2D);

  final _supabase = SupabaseService();
  final _formKey = GlobalKey<FormState>();
  final _publishableCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();

  StripeKeysModel? _saved;
  bool _loading = true;
  bool _saving = false;
  bool _denied = false;
  bool _showPublishable = false;
  bool _showSecret = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!AuthStorage.isSuperAdmin) {
      _denied = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only the super admin can manage Stripe keys.'),
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
    _publishableCtrl.dispose();
    _secretCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final keys = await _supabase.getStripeKeys();
      if (!mounted) return;
      setState(() {
        _saved = keys;
        _publishableCtrl.text = keys?.publishableKey ?? '';
        _secretCtrl.text = keys?.secretKey ?? '';
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

  String? _validatePublishable(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Publishable key is required';
    if (!v.startsWith('pk_test_') && !v.startsWith('pk_live_')) {
      return 'Must start with pk_test_ or pk_live_';
    }
    if (v.length < 20) return 'This key looks too short';
    return null;
  }

  String? _validateSecret(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Secret key is required';
    if (!v.startsWith('sk_test_') && !v.startsWith('sk_live_')) {
      return 'Must start with sk_test_ or sk_live_';
    }
    if (v.length < 20) return 'This key looks too short';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final saved = await _supabase.saveStripeKeys(
        StripeKeysModel(
          id: _saved?.id,
          publishableKey: _publishableCtrl.text.trim(),
          secretKey: _secretCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Stripe keys saved privately.'),
          backgroundColor: Colors.green.shade800,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not save Stripe keys. Try again.'),
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
      drawer: const CustomDrawer(activeItem: 'Stripe'),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Stripe keys',
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
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 880;
                    return Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _privacyBanner(),
                                const SizedBox(height: 20),
                                if (wide)
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: _statusCard()),
                                      const SizedBox(width: 16),
                                      Expanded(child: _modeCard()),
                                    ],
                                  )
                                else ...[
                                  _statusCard(),
                                  const SizedBox(height: 16),
                                  _modeCard(),
                                ],
                                const SizedBox(height: 20),
                                _keysCard(),
                                const SizedBox(height: 24),
                                SizedBox(
                                  height: 52,
                                  child: ElevatedButton.icon(
                                    onPressed: _saving ? null : _save,
                                    icon: _saving
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Icons.lock_outline),
                                    label: Text(_saving ? 'Saving…' : 'Save keys privately'),
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
                    );
                  },
                ),
    );
  }

  Widget _privacyBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF15241F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.verified_user_outlined, color: Colors.greenAccent),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure and private',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'These Stripe keys are stored privately in your database and are only visible to admin accounts. Never share the Secret key outside this dashboard.',
                  style: TextStyle(color: Colors.white70, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard() {
    final configured = _saved?.hasPublishable == true && _saved?.hasSecret == true;
    return _miniCard(
      icon: configured ? Icons.check_circle_outline : Icons.info_outline,
      iconColor: configured ? Colors.greenAccent : Colors.amberAccent,
      title: configured ? 'Keys connected' : 'Keys not set',
      subtitle: configured
          ? 'Publishable ${_saved!.maskedPublishable}\nSecret ${_saved!.maskedSecret}'
          : 'Add both keys below to connect Stripe.',
    );
  }

  Widget _modeCard() {
    final live = _saved?.isLiveMode == true;
    final test = _saved?.isTestMode == true;
    final label = live
        ? 'Live mode'
        : test
            ? 'Test mode'
            : 'Mode unknown';
    final color = live
        ? Colors.orangeAccent
        : test
            ? Colors.lightBlueAccent
            : Colors.grey;
    return _miniCard(
      icon: Icons.payments_outlined,
      iconColor: color,
      title: label,
      subtitle: live
          ? 'These keys will charge real customers.'
          : test
              ? 'Safe for testing. No real charges.'
              : 'Save valid Stripe keys to detect live or test mode.',
    );
  }

  Widget _miniCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white60, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _keysCard() {
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
            'Stripe credentials',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Paste the keys from your Stripe Dashboard. They stay hidden by default.',
            style: TextStyle(color: Colors.grey[400], height: 1.4),
          ),
          const SizedBox(height: 22),
          _keyField(
            controller: _publishableCtrl,
            label: 'Publishable key',
            hint: 'pk_live_… or pk_test_…  •  stored privately',
            helper: 'Safe to use in apps. Still keep it inside admin only.',
            obscure: !_showPublishable,
            onToggle: () => setState(() => _showPublishable = !_showPublishable),
            validator: _validatePublishable,
          ),
          const SizedBox(height: 18),
          _keyField(
            controller: _secretCtrl,
            label: 'Secret key',
            hint: 'sk_live_… or sk_test_…  •  secure and private',
            helper: 'Full access to charges. Never share this key.',
            obscure: !_showSecret,
            onToggle: () => setState(() => _showSecret = !_showSecret),
            validator: _validateSecret,
          ),
        ],
      ),
    );
  }

  Widget _keyField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String helper,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(color: Colors.white, letterSpacing: 0.4),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 2,
        helperStyle: TextStyle(color: Colors.grey[500]),
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF12141F),
        prefixIcon: const Icon(Icons.key_outlined, color: Colors.white38),
        suffixIcon: IconButton(
          tooltip: obscure ? 'Show key' : 'Hide key',
          onPressed: onToggle,
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: Colors.white54,
          ),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.deepPurpleAccent),
        ),
      ),
    );
  }
}
