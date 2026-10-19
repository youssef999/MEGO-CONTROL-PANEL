import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/auth_storage.dart';
import '../services/supabase_service.dart';
import 'restaurant_admin_dashboard.dart';
import 'users_list_screen.dart';

class RestaurantAdminLoginScreen extends StatefulWidget {
  const RestaurantAdminLoginScreen({super.key});
  @override
  State<RestaurantAdminLoginScreen> createState() =>
      _RestaurantAdminLoginScreenState();
}
class _RestaurantAdminLoginScreenState
    extends State<RestaurantAdminLoginScreen> {

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _supabaseService = SupabaseService();
  bool _isLoading = false;
  bool _bootstrapLoading = true;
  bool _isRestaurant = false;
  String? _errorMessage;


  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    if (!AuthStorage.hasSession) {
      if (mounted) setState(() => _bootstrapLoading = false);
      return;
    }

    final type = AuthStorage.sessionType;
    try {
      if (type == AuthStorage.typeRestaurant) {
        final id = AuthStorage.restaurantId;
        if (id == null) {
          await AuthStorage.clear();
          if (mounted) setState(() => _bootstrapLoading = false);
          return;
        }
        final restaurant = await _supabaseService.getRestaurantById(id);
        if (!mounted) return;
        if (restaurant != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  RestaurantAdminDashboard(restaurant: restaurant),
            ),
          );
          return;
        }
        // Restaurant row gone — clear stale session.
        await AuthStorage.clear();
      } else if (type == AuthStorage.typeAdmin) {
        if (AuthStorage.adminId == null) {
          await AuthStorage.clear();
        } else if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const UsersListScreen()),
          );
          return;
        }
      }
    } catch (_) {
      // Keep stored session on transient errors so next launch can retry.
    }
    if (mounted) setState(() => _bootstrapLoading = false);
  }

  Future<void> _login() async {
    if (_isRestaurant) {
      if (!_formKey.currentState!.validate()) return;

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final restaurant = await _supabaseService.loginRestaurant(
          _emailController.text,
          _passwordController.text,
        );

        if (restaurant != null) {
          await AuthStorage.saveRestaurantSession(
            restaurant.id,
            email: _emailController.text.trim(),
          );
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  RestaurantAdminDashboard(restaurant: restaurant),
            ),
          );
        } else {
          setState(() {
            _errorMessage = 'Invalid email or password';
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'An error occurred: $e';
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      if (!_formKey.currentState!.validate()) return;

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final admin = await _supabaseService.loginAdmin(
          _emailController.text,
          _passwordController.text,
        );

        if (!mounted) return;

        if (admin != null) {
          await AuthStorage.saveAdminSession(
            admin.id,
            email: _emailController.text.trim(),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const UsersListScreen()),
          );
        } else {
          setState(() {
            _errorMessage =
                "You don't have permission to access the admin dashboard.";
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'An error occurred: $e';
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bootstrapLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F111A),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        title: const Text('Restaurant Admin Login'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D2D),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/logo.svg',
                    height: 80,
                    placeholderBuilder:
                        (context) => const Icon(
                          Icons.admin_panel_settings,
                          size: 64,
                          color: Colors.deepPurpleAccent,
                        ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Login to manage your restaurant',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 32),
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  TextFormField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        color: Colors.grey,
                      ),
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.deepPurpleAccent,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: Colors.grey,
                      ),
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.deepPurpleAccent,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(unselectedWidgetColor: Colors.grey),
                    child: CheckboxListTile(
                      title: const Text(
                        'Are you a restaurant?',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      value: _isRestaurant,
                      onChanged: (value) {
                        setState(() {
                          _isRestaurant = value ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: Colors.deepPurpleAccent,
                      checkColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurpleAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child:
                          _isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
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
}
