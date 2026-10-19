import 'package:flutter/material.dart';
import '../core/auth_storage.dart';
import '../core/menu_category_order.dart';
import '../models/restaurant_model.dart';
import '../models/menu_model.dart';
import '../models/category_model.dart';
import '../services/imgbb_image_upload_service.dart';
import '../services/supabase_service.dart';
import '../widgets/firebase_storage_image.dart';
import '../widgets/menu_sections_order_dialog.dart';
import 'restaurant_admin_login_screen.dart';
import 'restaurant_wallet_screen.dart';

class RestaurantAdminDashboard extends StatefulWidget {
  final RestaurantModel restaurant;

  const RestaurantAdminDashboard({super.key, required this.restaurant});

  @override
  State<RestaurantAdminDashboard> createState() =>
      _RestaurantAdminDashboardState();
}

class _RestaurantAdminDashboardState extends State<RestaurantAdminDashboard> {
  final SupabaseService _supabaseService = SupabaseService();
  late RestaurantModel _restaurant;
  List<MenuModel> _menuItems = [];
  List<CategoryModel> _categories = [];
  bool _isLoading = true;
  String? _error;
  double _walletBalance = 0;

  @override
  void initState() {
    super.initState();
    _restaurant = widget.restaurant;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _fetchMenu(),
      _fetchCategories(),
      _fetchWalletBalance(),
    ]);
  }

  Future<void> _fetchWalletBalance() async {
    try {
      final balance = await _supabaseService.getRestaurantWalletBalance(
        _restaurant.id,
      );
      if (!mounted) return;
      setState(() => _walletBalance = balance);
    } catch (e) {
      print('Error fetching wallet balance: $e');
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final categories = await _supabaseService.getCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      print('Error fetching categories: $e');
    }
  }

  Future<void> _fetchMenu() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await _supabaseService.getMenuByRestaurantId(
        _restaurant.id,
      );
      setState(() {
        _menuItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _showMenuDialog({MenuModel? item}) async {
    final isEditing = item != null;
    final nameController = TextEditingController(text: item?.name);
    final priceController = TextEditingController(
      text: item?.price?.toString(),
    );
    final imageController = TextEditingController(text: item?.image);
    String? selectedCategory = item?.itemCategory;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        var uploadingImage = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1D2D),
              title: Text(
                isEditing ? 'Edit Item' : 'Add Item',
                style: const TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTextField(nameController, 'Name', isRequired: true),
                      const SizedBox(height: 16),
                      _buildTextField(
                        priceController,
                        'Price',
                        isNumber: true,
                        isRequired: true,
                      ),
                      const SizedBox(height: 16),
                      _buildCategoryDropdown(
                        initialValue: selectedCategory,
                        onChanged: (value) => selectedCategory = value,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTextField(
                              imageController,
                              'Image URL (or upload)',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: IconButton(
                              tooltip: 'Pick image, compress & upload (ImgBB)',
                              onPressed: uploadingImage
                                  ? null
                                  : () async {
                                      setDialogState(
                                        () => uploadingImage = true,
                                      );
                                      try {
                                        final url =
                                            await ImgbbImageUploadService.pickCompressAndUpload();
                                        if (url != null) {
                                          imageController.text = url;
                                        }
                                      } catch (e) {
                                        if (dialogContext.mounted) {
                                          ScaffoldMessenger.of(
                                            dialogContext,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Upload failed: $e',
                                              ),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (dialogContext.mounted) {
                                          setDialogState(
                                            () => uploadingImage = false,
                                          );
                                        }
                                      }
                                    },
                              icon: uploadingImage
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.photo_library_outlined,
                                      color: Colors.deepPurpleAccent,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(dialogContext);
                      _saveMenuItem(
                        isEditing ? item.id : 0,
                        nameController.text,
                        priceController.text,
                        imageController.text,
                        selectedCategory ?? '',
                        isEditing,
                      );
                    }
                  },
                  child: Text(isEditing ? 'Update' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  TextFormField _buildTextField(
    TextEditingController controller,
    String label, {
    bool isRequired = false,
    bool isNumber = false,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return '$label is required';
        }
        if (isNumber && value != null && value.isNotEmpty) {
          if (double.tryParse(value) == null) {
            return 'Enter a valid number';
          }
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[400]),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.deepPurpleAccent),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown({
    String? initialValue,
    required Function(String?) onChanged,
    bool isRequired = false,
  }) {
    // Ensure initialValue is in the categories list or null
    final hasInitialValue =
        initialValue != null && _categories.any((c) => c.name == initialValue);

    return DropdownButtonFormField<String>(
      value: hasInitialValue ? initialValue : null,
      dropdownColor: const Color(0xFF1A1D2D),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Category',
        labelStyle: TextStyle(color: Colors.grey[400]),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.deepPurpleAccent),
        ),
      ),
      items: _categories.map((category) {
        return DropdownMenuItem<String>(
          value: category.name,
          child: Text(category.name ?? 'Unknown'),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'Category is required';
        }
        return null;
      },
    );
  }

  Future<void> _saveMenuItem(
    int id,
    String name,
    String priceStr,
    String image,
    String category,
    bool isEditing,
  ) async {
    setState(() => _isLoading = true);
    try {
      final double? price = double.tryParse(priceStr);
      final item = MenuModel(
        id: id,
        name: name,
        price: price,
        image: image.isNotEmpty ? image : null,
        itemCategory: category.isNotEmpty ? category : null,
        restaurantId: _restaurant.id,
      );

      if (isEditing) {
        await _supabaseService.updateMenuItem(item);
      } else {
        await _supabaseService.addMenuItem(item);
      }
      _fetchMenu();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _showEditProfileDialog() async {
    final nameController = TextEditingController(text: _restaurant.name);
    String? selectedCategory = _restaurant.category;
    final detailsController = TextEditingController(text: _restaurant.details);
    final emailController = TextEditingController(text: _restaurant.email);
    final passwordController = TextEditingController(
      text: _restaurant.password,
    );
    final imageController = TextEditingController(text: _restaurant.image);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        var uploadingImage = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1D2D),
              title: const Text(
                'Edit Profile',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTextField(nameController, 'Name', isRequired: true),
                      const SizedBox(height: 16),
                      _buildCategoryDropdown(
                        initialValue: selectedCategory,
                        onChanged: (value) => selectedCategory = value,
                        isRequired: true,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(detailsController, 'Description/Details'),
                      const SizedBox(height: 16),
                      _buildTextField(
                        emailController,
                        'Email',
                        isRequired: true,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        passwordController,
                        'Password',
                        isRequired: true,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTextField(
                              imageController,
                              'Image URL (or upload)',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: IconButton(
                              tooltip: 'Pick image, compress & upload (ImgBB)',
                              onPressed: uploadingImage
                                  ? null
                                  : () async {
                                      setDialogState(
                                        () => uploadingImage = true,
                                      );
                                      try {
                                        final url =
                                            await ImgbbImageUploadService.pickCompressAndUpload();
                                        if (url != null) {
                                          imageController.text = url;
                                        }
                                      } catch (e) {
                                        if (dialogContext.mounted) {
                                          ScaffoldMessenger.of(
                                            dialogContext,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Upload failed: $e',
                                              ),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (dialogContext.mounted) {
                                          setDialogState(
                                            () => uploadingImage = false,
                                          );
                                        }
                                      }
                                    },
                              icon: uploadingImage
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.photo_library_outlined,
                                      color: Colors.deepPurpleAccent,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(dialogContext);
                      _updateRestaurantProfile(
                        nameController.text,
                        selectedCategory ?? '',
                        detailsController.text,
                        emailController.text,
                        passwordController.text,
                        imageController.text,
                      );
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateRestaurantProfile(
    String name,
    String category,
    String details,
    String email,
    String password,
    String image,
  ) async {
    setState(() => _isLoading = true);
    try {
      final updatedRestaurant = RestaurantModel(
        id: _restaurant.id,
        name: name,
        category: category,
        details: details,
        email: email,
        password: password,
        image: image.isNotEmpty ? image : null,
        rate: _restaurant.rate,
        rateCount: _restaurant.rateCount,
        fcmToken: _restaurant.fcmToken,
        deviceToken: _restaurant.deviceToken,
        isAccepted: _restaurant.isAccepted,
        menuCategoryOrder: _restaurant.menuCategoryOrder,
      );

      await _supabaseService.updateRestaurant(updatedRestaurant);

      setState(() {
        _restaurant = updatedRestaurant;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _showDeleteConfirmation(MenuModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2D),
        title: const Text(
          'Confirm Delete',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${item.name}"?',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteMenuItem(item.id);
    }
  }

  Future<void> _deleteMenuItem(int id) async {
    setState(() => _isLoading = true);
    try {
      await _supabaseService.deleteMenuItem(id);
      _fetchMenu();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              await AuthStorage.clear();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => const RestaurantAdminLoginScreen(),
                ),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Text(
                      'Error: $_error',
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : _buildMenuGrid(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMenuDialog(),
        backgroundColor: Colors.deepPurpleAccent,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _restaurant.image != null
                ? SizedBox(
                    width: 100,
                    height: 100,
                    child: FirebaseStorageImage(
                      imageUrl: _restaurant.image!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      fallbackIcon: Icons.restaurant,
                    ),
                  )
                : Container(
                    width: 100,
                    height: 100,
                    color: Colors.grey[800],
                    child: const Icon(Icons.restaurant, color: Colors.grey),
                  ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _restaurant.name ?? 'Restaurant Name',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                RestaurantWalletScreen(restaurant: _restaurant),
                          ),
                        );
                        _fetchWalletBalance();
                      },
                      icon: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.tealAccent,
                      ),
                      tooltip: 'Wallet',
                    ),
                    IconButton(
                      onPressed: _arrangeSections,
                      icon: const Icon(
                        Icons.swap_vert_rounded,
                        color: Colors.deepPurpleAccent,
                      ),
                      tooltip: 'Arrange menu sections',
                    ),
                    IconButton(
                      onPressed: _showEditProfileDialog,
                      icon: const Icon(Icons.edit, color: Colors.blueAccent),
                      tooltip: 'Edit Profile',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            RestaurantWalletScreen(restaurant: _restaurant),
                      ),
                    );
                    _fetchWalletBalance();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.tealAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.tealAccent.withOpacity(0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 16,
                          color: Colors.tealAccent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Wallet: \$${_walletBalance.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.tealAccent,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: Colors.tealAccent.withOpacity(0.8),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.category, size: 16, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      _restaurant.category ?? 'Category',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      _restaurant.rateLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_restaurant.email != null)
                  Row(
                    children: [
                      Icon(Icons.email, size: 16, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        _restaurant.email!,
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ],
                  ),
                if (_restaurant.details != null &&
                    _restaurant.details!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _restaurant.details!,
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Menu sections in the restaurant's saved order ('' = no category, last).
  List<String> get _sections {
    final sections = orderMenuCategories(
      _menuItems.map((m) => m.itemCategory ?? ''),
      _restaurant.menuCategoryOrder,
    );
    if (_menuItems.any((m) => (m.itemCategory ?? '').trim().isEmpty)) {
      sections.add('');
    }
    return sections;
  }

  List<MenuModel> _itemsIn(String section) => _menuItems
      .where(
        (m) =>
            menuCategoryKey(m.itemCategory ?? '') == menuCategoryKey(section),
      )
      .toList();

  Future<void> _arrangeSections() async {
    final named = _sections.where((s) => s.isNotEmpty).toList();
    if (named.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add items in at least 2 categories to arrange them.'),
        ),
      );
      return;
    }
    final order = await showMenuSectionsOrderDialog(
      context,
      sections: named,
      itemCounts: {for (final s in named) s: _itemsIn(s).length},
    );
    if (order == null || !mounted) return;
    try {
      await _supabaseService.updateRestaurantMenuCategoryOrder(
        _restaurant.id,
        order,
      );
      if (!mounted) return;
      setState(() {
        _restaurant = _restaurant.copyWith(menuCategoryOrder: order);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Menu sections order saved — customers see it now'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildMenuGrid() {
    if (_menuItems.isEmpty) {
      return const Center(
        child: Text(
          'No menu items found. Add some!',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    final sections = _sections;
    return CustomScrollView(
      slivers: [
        for (final (index, section) in sections.indexed) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.deepPurpleAccent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    section.isEmpty ? 'Other' : '${index + 1}. $section',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_itemsIn(section).length} items',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                  if (index == 0) ...[
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _arrangeSections,
                      icon: const Icon(Icons.swap_vert_rounded, size: 18),
                      label: const Text('Arrange sections'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.deepPurpleAccent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 0.8,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _itemsIn(section).length,
              itemBuilder: (context, i) => _buildMenuCard(_itemsIn(section)[i]),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }

  Widget _buildMenuCard(MenuModel item) {
    return Card(
      color: const Color(0xFF252A41),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: item.image != null
                ? FirebaseStorageImage(
                    imageUrl: item.image!,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.fastfood,
                  )
                : Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.fastfood, color: Colors.grey),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${item.price?.toStringAsFixed(2) ?? "0.00"}',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () => _showMenuDialog(item: item),
                icon: const Icon(
                  Icons.edit,
                  color: Colors.blueAccent,
                  size: 18,
                ),
                constraints: const BoxConstraints(),
              ),
              IconButton(
                onPressed: () => _showDeleteConfirmation(item),
                icon: const Icon(
                  Icons.delete,
                  color: Colors.redAccent,
                  size: 18,
                ),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
