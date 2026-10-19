import 'package:flutter/material.dart';
import '../models/menu_model.dart';
import '../models/category_model.dart';
import '../services/supabase_service.dart';
import '../services/imgbb_image_upload_service.dart';
import '../widgets/firebase_storage_image.dart';

class RestaurantMenuScreen extends StatefulWidget {
  final int restaurantId;
  final String restaurantName;

  const RestaurantMenuScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<RestaurantMenuScreen> createState() => _RestaurantMenuScreenState();
}

class _RestaurantMenuScreenState extends State<RestaurantMenuScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<MenuModel> _menuItems = [];
  List<CategoryModel> _categories = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([_fetchMenu(), _fetchCategories()]);
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
        widget.restaurantId,
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
                      _buildTextField(
                        nameController,
                        'Name',
                        isRequired: true,
                      ),
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
                              onPressed:
                                  uploadingImage
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
                              icon:
                                  uploadingImage
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
      keyboardType:
          isNumber
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
      items:
          _categories.map((category) {
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
        restaurantId: widget.restaurantId,
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

  Future<void> _showDeleteConfirmation(MenuModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Menu: ${widget.restaurantName}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => _showMenuDialog(),
            icon: const Icon(
              Icons.add_circle_outline,
              color: Colors.greenAccent,
            ),
            tooltip: 'Add Menu Item',
          ),
          IconButton(onPressed: _fetchMenu, icon: const Icon(Icons.refresh)),
          const SizedBox(width: 16),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Text(
                  'Error: $_error',
                  style: const TextStyle(color: Colors.red),
                ),
              )
              : _menuItems.isEmpty
              ? const Center(
                child: Text(
                  'No menu items found.',
                  style: TextStyle(color: Colors.white),
                ),
              )
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5, // Increased for smaller items
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _menuItems.length,
                  itemBuilder: (context, index) {
                    final item = _menuItems[index];
                    return Card(
                      color: const Color(0xFF1A1D2D),
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child:
                                item.image != null
                                    ? FirebaseStorageImage(
                                      imageUrl: item.image!,
                                      fit: BoxFit.cover,
                                      fallbackIcon: Icons.fastfood,
                                    )
                                    : Container(
                                      color: Colors.grey[800],
                                      child: const Icon(
                                        Icons.fastfood,
                                        color: Colors.grey,
                                      ),
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
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '\$${item.price?.toStringAsFixed(2) ?? "0.00"}',
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
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
                                ),
                                constraints: const BoxConstraints(),
                              ),
                              IconButton(
                                onPressed: () => _showDeleteConfirmation(item),
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
    );
  }
}
