import 'package:flutter/material.dart';
import '../models/restaurant_model.dart';
import '../models/category_model.dart';
import '../services/account_decision_notifier.dart';
import '../services/supabase_service.dart';
import '../services/excel_export_service.dart';
import '../services/imgbb_image_upload_service.dart';
import '../widgets/firebase_storage_image.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/reject_reason_dialog.dart';
import 'restaurant_menu_screen.dart';
import 'restaurant_wallet_screen.dart';

class RestaurantsListScreen extends StatefulWidget {
  const RestaurantsListScreen({super.key});

  @override
  State<RestaurantsListScreen> createState() => _RestaurantsListScreenState();
}

class _RestaurantsListScreenState extends State<RestaurantsListScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();

  List<RestaurantModel> _allRestaurants = [];
  List<RestaurantModel> _filteredRestaurants = [];
  List<CategoryModel> _categories = [];
  bool _isLoading = true;
  bool _isExporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([_fetchRestaurants(), _fetchCategories()]);
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

  Future<void> _fetchRestaurants() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final restaurants = await _supabaseService.getRestaurants();
      setState(() {
        _allRestaurants = restaurants;
        _filterRestaurants();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterRestaurants() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      _filteredRestaurants =
          _allRestaurants.where((restaurant) {
            final matchesSearch =
                (restaurant.name?.toLowerCase().contains(query) ?? false) ||
                (restaurant.category?.toLowerCase().contains(query) ?? false) ||
                (restaurant.details?.toLowerCase().contains(query) ?? false);
            return matchesSearch;
          }).toList();
    });
  }

  Future<void> _exportExcel() async {
    if (_isExporting) return;
    if (_filteredRestaurants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No rows to export')),
      );
      return;
    }
    setState(() => _isExporting = true);
    try {
      await ExcelExportService.exportSheet(
        sheetName: 'Restaurants',
        headers: const [
          'ID',
          'Name',
          'Category',
          'Status',
          'Rating',
          'Email',
          'Details',
        ],
        rows: ExcelExportService.rowsFromRestaurants(_filteredRestaurants),
        fileName: ExcelExportService.fileName('restaurants'),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${_filteredRestaurants.length} restaurants'),
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
      drawer: const CustomDrawer(activeItem: 'Restaurants'),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Restaurants Management',
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
            onPressed: () => _showRestaurantDialog(),
            icon: const Icon(
              Icons.add_circle_outline,
              color: Colors.greenAccent,
            ),
            tooltip: 'Add Restaurant',
          ),
          IconButton(
            onPressed: () {
              _searchController.clear();
              _fetchRestaurants();
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
            _buildSearch(),
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
                        : _filteredRestaurants.isEmpty
                        ? const Center(child: Text('No restaurants found.'))
                        : _buildDataTable(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => _filterRestaurants(),
      decoration: InputDecoration(
        hintText: 'Search by Name, Category, or Details...',
        prefixIcon: const Icon(Icons.search, color: Colors.deepPurpleAccent),
        suffixIcon:
            _searchController.text.isNotEmpty
                ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _filterRestaurants();
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
            DataColumn(label: Text('IMAGE', style: _headerStyle)),
            DataColumn(label: Text('NAME', style: _headerStyle)),
            DataColumn(label: Text('CATEGORY', style: _headerStyle)),
            DataColumn(label: Text('STATUS', style: _headerStyle)),
            DataColumn(label: Text('RATING', style: _headerStyle)),
            DataColumn(label: Text('ACTIONS', style: _headerStyle)),
          ],
          rows:
              _filteredRestaurants
                  .map((restaurant) => _buildDataRow(restaurant))
                  .toList(),
        ),
      ),
    );
  }

  DataRow _buildDataRow(RestaurantModel restaurant) {
    final accepted = restaurant.isAccepted;
    return DataRow(
      cells: [
        DataCell(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child:
                  restaurant.image != null
                      ? FirebaseStorageImage(
                        imageUrl: restaurant.image!,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        fallbackIcon: Icons.restaurant,
                      )
                      : Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey[800],
                        child: const Icon(Icons.restaurant, color: Colors.grey),
                      ),
            ),
          ),
        ),
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                restaurant.name ?? 'Unknown',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              _buildAcceptanceBadge(accepted),
              if (restaurant.details != null) ...[
                const SizedBox(height: 4),
                Text(
                  restaurant.details!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ],
          ),
        ),
        DataCell(
          Text(
            restaurant.category ?? 'N/A',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ),
        DataCell(_buildAcceptanceBadge(accepted, compact: false)),
        DataCell(
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text(
                restaurant.rateLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => accepted
                    ? _rejectRestaurant(restaurant, blocked: true)
                    : _confirmToggleAccepted(restaurant),
                icon: Icon(
                  accepted ? Icons.block : Icons.check_circle_outline,
                  color: accepted ? Colors.redAccent : Colors.greenAccent,
                  size: 20,
                ),
                tooltip: accepted
                    ? 'Block restaurant (with reason)'
                    : 'Activate restaurant',
              ),
              if (!accepted)
                IconButton(
                  onPressed: () =>
                      _rejectRestaurant(restaurant, blocked: false),
                  icon: const Icon(
                    Icons.gpp_bad_outlined,
                    color: Colors.orangeAccent,
                    size: 20,
                  ),
                  tooltip: 'Reject with reason',
                ),
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        RestaurantWalletScreen(restaurant: restaurant),
                  ),
                ),
                icon: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.tealAccent,
                  size: 20,
                ),
                tooltip: 'Restaurant wallet',
              ),
              IconButton(
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => RestaurantMenuScreen(
                              restaurantId: restaurant.id,
                              restaurantName: restaurant.name ?? 'Restaurant',
                            ),
                      ),
                    ),
                icon: const Icon(
                  Icons.restaurant_menu,
                  color: Colors.purpleAccent,
                  size: 20,
                ),
                tooltip: 'View Menu',
              ),
              IconButton(
                onPressed: () => _showRestaurantDialog(restaurant: restaurant),
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Colors.blueAccent,
                  size: 20,
                ),
                tooltip: 'Edit Restaurant',
              ),
              IconButton(
                onPressed: () => _showDeleteConfirmation(restaurant),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 20,
                ),
                tooltip: 'Delete Restaurant',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAcceptanceBadge(bool accepted, {bool compact = true}) {
    final color = accepted ? const Color(0xFF3DDC97) : const Color(0xFFFF8A65);
    final title = accepted ? 'Activated' : 'Needs activation';
    final subtitle = accepted
        ? 'Live & ready for orders'
        : 'Blocked — activate to go live';
    final icon = accepted ? Icons.verified_rounded : Icons.hourglass_top_rounded;

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 10.5,
                    height: 1.2,
                  ),
                ),
              ],
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
            onPressed: _fetchRestaurants,
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
          'Total Restaurants',
          '${_allRestaurants.length}',
          Icons.restaurant_outlined,
          Colors.blue,
        ),
        const SizedBox(width: 24),
        _buildStatCard(
          'Activated',
          '${_allRestaurants.where((r) => r.isAccepted).length}',
          Icons.verified_rounded,
          const Color(0xFF3DDC97),
        ),
        const SizedBox(width: 24),
        _buildStatCard(
          'Needs activation',
          '${_allRestaurants.where((r) => !r.isAccepted).length}',
          Icons.hourglass_top_rounded,
          const Color(0xFFFF8A65),
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

  Future<void> _showRestaurantDialog({RestaurantModel? restaurant}) async {
    final isEditing = restaurant != null;
    final nameController = TextEditingController(text: restaurant?.name);
    String? selectedCategory = restaurant?.category;
    final detailsController = TextEditingController(text: restaurant?.details);
    final emailController = TextEditingController(text: restaurant?.email);
    final passwordController = TextEditingController(
      text: restaurant?.password,
    );
    final imageController = TextEditingController(text: restaurant?.image);
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
                isEditing ? 'Edit Restaurant' : 'Add Restaurant',
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
                      _buildCategoryDropdown(
                        initialValue: selectedCategory,
                        onChanged: (value) => selectedCategory = value,
                        isRequired: true,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(detailsController, 'Details'),
                      const SizedBox(height: 16),
                      _buildTextField(emailController, 'Email'),
                      const SizedBox(height: 16),
                      _buildTextField(passwordController, 'Password'),
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
                                          print('Upload failed: $e');
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
                      _saveRestaurant(
                        isEditing ? restaurant.id : 0,
                        nameController.text,
                        selectedCategory ?? '',
                        detailsController.text,
                        emailController.text,
                        passwordController.text,
                        imageController.text,
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

  Future<void> _saveRestaurant(
    int id,
    String name,
    String category,
    String details,
    String email,
    String password,
    String image,
    bool isEditing,
  ) async {
    setState(() => _isLoading = true);
    try {
      final existing = isEditing
          ? _allRestaurants.where((r) => r.id == id).toList()
          : <RestaurantModel>[];
      final restaurant = RestaurantModel(
        id: id, // ID is ignored for Add in SupabaseService
        name: name,
        category: category,
        details: details,
        email: email.isNotEmpty ? email : null,
        password: password.isNotEmpty ? password : null,
        image: image.isNotEmpty ? image : null,
        isAccepted: existing.isNotEmpty ? existing.first.isAccepted : false,
      );

      if (isEditing) {
        await _supabaseService.updateRestaurant(restaurant);
      } else {
        await _supabaseService.addRestaurant(restaurant);
      }
      _fetchRestaurants();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmToggleAccepted(RestaurantModel restaurant) async {
    final willAccept = !restaurant.isAccepted;
    final name = restaurant.name ?? 'this restaurant';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2D),
        title: Text(
          willAccept ? 'Activate restaurant?' : 'Block restaurant?',
          style: const TextStyle(color: Colors.white),
        ),
          content: Text(
            willAccept
                ? 'Activate "$name"?\n\nis_accepted will become true. The restaurant will be live and ready for orders.\n\nA welcome notification will be sent to its in-app inbox + push.'
                : 'Block "$name"?\n\nis_accepted will become false. The restaurant will be blocked and needs activation again.',
            style: TextStyle(color: Colors.grey[300], height: 1.4),
          ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  willAccept ? Colors.greenAccent : Colors.redAccent,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(willAccept ? 'Yes, activate' : 'Yes, block'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _setRestaurantAccepted(restaurant, willAccept);
    }
  }

  /// Reject a pending restaurant or block an active one, and notify it
  /// (in-app inbox + push) with the reason.
  Future<void> _rejectRestaurant(
    RestaurantModel restaurant, {
    required bool blocked,
  }) async {
    final reason = await showRejectReasonDialog(
      context,
      title: blocked ? 'Block restaurant' : 'Reject restaurant',
      subjectName: restaurant.name ?? 'Restaurant #${restaurant.id}',
      confirmLabel: blocked ? 'Block & notify' : 'Reject & notify',
      recipientLabel: 'restaurant',
      presetReasons: AccountDecisionNotifier.restaurantReasons,
    );
    if (reason == null || !mounted) return;

    try {
      if (restaurant.isAccepted) {
        await _supabaseService.updateRestaurantAccepted(restaurant.id, false);
        if (!mounted) return;
        setState(() {
          _allRestaurants = _allRestaurants
              .map((r) =>
                  r.id == restaurant.id ? r.copyWith(isAccepted: false) : r)
              .toList();
          _filterRestaurants();
        });
      }
      final result = await AccountDecisionNotifier.restaurant(
        restaurant,
        reason: reason,
        blocked: blocked,
      );
      if (!mounted) return;
      final name = restaurant.name ?? 'Restaurant';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${blocked ? '$name blocked' : '$name rejected'} — ${result.message}',
          ),
          backgroundColor: result.ok ? Colors.orange : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _setRestaurantAccepted(
    RestaurantModel restaurant,
    bool isAccepted,
  ) async {
    try {
      await _supabaseService.updateRestaurantAccepted(
        restaurant.id,
        isAccepted,
      );
      if (!mounted) return;
      setState(() {
        _allRestaurants = _allRestaurants
            .map(
              (r) => r.id == restaurant.id
                  ? r.copyWith(isAccepted: isAccepted)
                  : r,
            )
            .toList();
        _filterRestaurants();
      });
      final notify = isAccepted
          ? await AccountDecisionNotifier.restaurantApproved(restaurant)
          : null;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAccepted
                ? '${restaurant.name ?? 'Restaurant'} is now Activated — ${notify!.message}'
                : '${restaurant.name ?? 'Restaurant'} is Blocked — needs activation',
          ),
          backgroundColor: !isAccepted
              ? Colors.orange
              : notify!.ok
                  ? Colors.green
                  : Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showDeleteConfirmation(RestaurantModel restaurant) async {
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
              'Are you sure you want to delete "${restaurant.name}"?',
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
      _deleteRestaurant(restaurant.id);
    }
  }

  Future<void> _deleteRestaurant(int id) async {
    setState(() => _isLoading = true);
    try {
      await _supabaseService.deleteRestaurant(id);
      _fetchRestaurants();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  static const _headerStyle = TextStyle(
    fontWeight: FontWeight.bold,
    color: Colors.deepPurpleAccent,
    letterSpacing: 1.1,
    fontSize: 12,
  );
}
