import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../services/imgbb_image_upload_service.dart';
import '../services/supabase_service.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/firebase_storage_image.dart';

class FoodCategoriesListScreen extends StatefulWidget {
  const FoodCategoriesListScreen({super.key});

  @override
  State<FoodCategoriesListScreen> createState() =>
      _FoodCategoriesListScreenState();
}

class _FoodCategoriesListScreenState extends State<FoodCategoriesListScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();

  List<CategoryModel> _all = [];
  List<CategoryModel> _filtered = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final rows = await _supabaseService.getCategories();
      if (!mounted) return;
      setState(() {
        _all = rows;
        _applyFilter();
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

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    _filtered = _all.where((c) {
      if (q.isEmpty) return true;
      return (c.name?.toLowerCase().contains(q) ?? false) ||
          c.id.toString().contains(q);
    }).toList();
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
      drawer: const CustomDrawer(activeItem: 'Food Categories'),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Food Categories',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            onPressed: () => _showCategoryDialog(),
            icon: const Icon(Icons.add_circle_outline, color: Colors.greenAccent),
            tooltip: 'Add category',
          ),
          IconButton(
            onPressed: _isLoading ? null : _fetch,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStats(),
            const SizedBox(height: 20),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(_applyFilter),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search categories…',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.deepPurpleAccent),
                filled: true,
                fillColor: const Color(0xFF1A1D2D),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.deepPurpleAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.category_outlined,
              color: Colors.deepPurpleAccent,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total categories',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                '${_all.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error: $_error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _fetch, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_filtered.isEmpty) {
      return Center(
        child: Text(
          'No categories found.',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: _filtered.length,
      itemBuilder: (context, index) => _buildCategoryCard(_filtered[index]),
    );
  }

  Widget _buildCategoryCard(CategoryModel category) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: category.image != null && category.image!.trim().isNotEmpty
                  ? FirebaseStorageImage(
                      imageUrl: category.image,
                      fit: BoxFit.cover,
                      fallbackIcon: Icons.category_outlined,
                    )
                  : Container(
                      color: Colors.deepPurple.withOpacity(0.2),
                      child: const Icon(
                        Icons.category_outlined,
                        color: Colors.deepPurpleAccent,
                        size: 48,
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Text(
              category.name ?? 'Untitled',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () => _viewCategory(category),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  color: Colors.tealAccent,
                  tooltip: 'View',
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () => _showCategoryDialog(category: category),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: Colors.blueAccent,
                  tooltip: 'Edit',
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () => _confirmDelete(category),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: Colors.redAccent,
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _viewCategory(CategoryModel category) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2D),
        title: Text(
          category.name ?? 'Category',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: category.image != null &&
                          category.image!.trim().isNotEmpty
                      ? FirebaseStorageImage(
                          imageUrl: category.image,
                          fit: BoxFit.cover,
                          fallbackIcon: Icons.category_outlined,
                        )
                      : Container(
                          color: Colors.deepPurple.withOpacity(0.2),
                          child: const Icon(
                            Icons.category_outlined,
                            color: Colors.deepPurpleAccent,
                            size: 48,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCategoryDialog({CategoryModel? category}) async {
    final isEdit = category != null;
    final nameCtrl = TextEditingController(text: category?.name ?? '');
    final imageCtrl = TextEditingController(text: category?.image ?? '');
    final formKey = GlobalKey<FormState>();
    var uploading = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1D2D),
              title: Text(
                isEdit ? 'Edit category' : 'Add category',
                style: const TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          labelStyle: TextStyle(color: Colors.grey),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: imageCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Image URL',
                          labelStyle: const TextStyle(color: Colors.grey),
                          suffixIcon: IconButton(
                            tooltip: 'Upload image',
                            onPressed: uploading
                                ? null
                                : () async {
                                    setDialogState(() => uploading = true);
                                    try {
                                      final url =
                                          await ImgbbImageUploadService
                                              .pickCompressAndUpload();
                                      if (url != null) {
                                        imageCtrl.text = url;
                                      }
                                    } finally {
                                      setDialogState(() => uploading = false);
                                    }
                                  },
                            icon: uploading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.cloud_upload_outlined,
                                    color: Colors.deepPurpleAccent,
                                  ),
                          ),
                        ),
                      ),
                      if (imageCtrl.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            height: 120,
                            width: double.infinity,
                            child: FirebaseStorageImage(
                              imageUrl: imageCtrl.text.trim(),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(dialogContext);
                    await _saveCategory(
                      isEdit: isEdit,
                      existing: category,
                      name: nameCtrl.text.trim(),
                      image: imageCtrl.text.trim(),
                    );
                  },
                  child: Text(
                    isEdit ? 'Save' : 'Create',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveCategory({
    required bool isEdit,
    CategoryModel? existing,
    required String name,
    required String image,
  }) async {
    try {
      if (isEdit && existing != null) {
        await _supabaseService.updateCategory(
          CategoryModel(
            id: existing.id,
            name: name,
            image: image.isEmpty ? null : image,
          ),
        );
      } else {
        await _supabaseService.addCategory(
          name: name,
          image: image.isEmpty ? null : image,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEdit ? 'Category updated' : 'Category created'),
          backgroundColor: Colors.green,
        ),
      );
      await _fetch();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDelete(CategoryModel category) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2D),
        title: const Text('Delete category?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete "${category.name ?? 'this category'}"? This cannot be undone.',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _supabaseService.deleteCategory(category.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Category deleted'),
          backgroundColor: Colors.green,
        ),
      );
      await _fetch();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
