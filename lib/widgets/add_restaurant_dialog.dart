import 'package:flutter/material.dart';

import '../core/geo_coordinates.dart';
import '../core/phone_format.dart';
import '../models/category_model.dart';
import '../models/new_restaurant_model.dart';
import '../services/image_upload_service.dart';
import 'restaurant_form_fields.dart';

/// Returns an error message to show, or null on success.
typedef CreateRestaurantCallback =
    Future<String?> Function(NewRestaurantModel restaurant);

/// Full restaurant sign-up from the dashboard (same data as the partner app).
/// Returns true when the restaurant was created.
Future<bool?> showAddRestaurantDialog(
  BuildContext context, {
  required List<CategoryModel> categories,
  required CreateRestaurantCallback onSubmit,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        AddRestaurantDialog(categories: categories, onSubmit: onSubmit),
  );
}

class AddRestaurantDialog extends StatefulWidget {
  final List<CategoryModel> categories;
  final CreateRestaurantCallback onSubmit;

  const AddRestaurantDialog({
    super.key,
    required this.categories,
    required this.onSubmit,
  });

  @override
  State<AddRestaurantDialog> createState() => _AddRestaurantDialogState();
}

class _AddRestaurantDialogState extends State<AddRestaurantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _details = TextEditingController();
  final _image = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _locationName = TextEditingController();
  final _locationDetails = TextEditingController();
  final _coordinates = TextEditingController();

  String? _category;
  int _openAt = 9 * 60;
  int _closeAt = 22 * 60;
  bool _uploading = false;
  bool _saving = false;
  bool _showPassword = false;
  String? _error;

  ({double lat, double lng})? get _coords =>
      parseCoordinates(_coordinates.text);

  @override
  void dispose() {
    for (final c in [
      _name,
      _details,
      _image,
      _email,
      _password,
      _phone,
      _locationName,
      _locationDetails,
      _coordinates,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _uploadImage() async {
    setState(() => _uploading = true);
    try {
      final url = await ImageUploadService.pickCompressAndUpload(
        folder: ImageUploadService.folderRestaurants,
      );
      if (url != null) setState(() => _image.text = url);
    } catch (e) {
      setState(() => _error = 'Image upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    final coords = _coords!;
    setState(() => _saving = true);
    final error = await widget.onSubmit(
      NewRestaurantModel(
        name: _name.text.trim(),
        image: _image.text.trim(),
        category: _category!,
        details: _details.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        phone: formatPhoneE164(_phone.text),
        lat: coords.lat,
        lng: coords.lng,
        locationName: _locationName.text.trim(),
        locationDetails: _locationDetails.text.trim(),
        openAtMinutes: _openAt,
        closeAtMinutes: _closeAt,
      ),
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  String? _required(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '$label is required' : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1D2D),
      title: Row(
        children: [
          const Expanded(
            child: Text(
              'Add Restaurant',
              style: TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _liveNote(),
                ..._basicSection(),
                ..._accountSection(),
                ..._locationSection(),
                ..._hoursSection(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving || _uploading ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create restaurant'),
        ),
      ],
    );
  }

  Widget _liveNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      child: Text(
        'The restaurant is activated immediately and can receive orders. '
        'Rating starts empty and only comes from customer reviews.',
        style: TextStyle(color: Colors.grey[300], fontSize: 12.5, height: 1.4),
      ),
    );
  }

  List<Widget> _basicSection() => [
    const DashFormSection(title: 'Restaurant', icon: Icons.storefront),
    DashFormField(
      controller: _name,
      label: 'Name *',
      validator: (v) => _required(v, 'Name'),
    ),
    const SizedBox(height: 14),
    DropdownButtonFormField<String>(
      value: _category,
      dropdownColor: const Color(0xFF1A1D2D),
      style: const TextStyle(color: Colors.white),
      decoration: dashInputDecoration('Category *'),
      items: [
        for (final c in widget.categories)
          if ((c.name ?? '').isNotEmpty)
            DropdownMenuItem(value: c.name, child: Text(c.name!)),
      ],
      onChanged: (v) => setState(() => _category = v),
      validator: (v) => v == null ? 'Category is required' : null,
    ),
    const SizedBox(height: 14),
    DashFormField(controller: _details, label: 'Details', maxLines: 2),
    const SizedBox(height: 14),
    DashFormField(
      controller: _image,
      label: 'Image URL * (or upload)',
      onChanged: (_) => setState(() {}),
      validator: (v) {
        final value = v?.trim() ?? '';
        if (value.isEmpty) return 'Restaurant image is required';
        if (!value.startsWith('http')) return 'Enter a valid image URL';
        return null;
      },
      suffix: IconButton(
        tooltip: 'Pick image, compress & upload',
        onPressed: _uploading ? null : _uploadImage,
        icon: _uploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.upload, color: Colors.deepPurpleAccent),
      ),
    ),
    if (_image.text.trim().startsWith('http')) ...[
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          _image.text.trim(),
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    ],
  ];

  List<Widget> _accountSection() => [
    const SizedBox(height: 8),
    const DashFormSection(title: 'Login & contact', icon: Icons.lock_outline),
    DashFormField(
      controller: _email,
      label: 'Email *',
      keyboardType: TextInputType.emailAddress,
      validator: (v) {
        final value = v?.trim() ?? '';
        if (value.isEmpty) return 'Email is required';
        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
          return 'Enter a valid email';
        }
        return null;
      },
    ),
    const SizedBox(height: 14),
    DashFormField(
      controller: _password,
      label: 'Password * (min 6)',
      obscureText: !_showPassword,
      validator: (v) => (v ?? '').length < 6
          ? 'Password must be at least 6 characters'
          : null,
      suffix: IconButton(
        onPressed: () => setState(() => _showPassword = !_showPassword),
        icon: Icon(
          _showPassword ? Icons.visibility_off : Icons.visibility,
          color: Colors.grey,
        ),
      ),
    ),
    const SizedBox(height: 14),
    DashFormField(
      controller: _phone,
      label: 'Phone *',
      hint: 'US (+1) or Egypt (+20)',
      keyboardType: TextInputType.phone,
      validator: (v) {
        if ((v ?? '').trim().isEmpty) return 'Phone is required';
        return isValidPhone(v!) ? null : 'Enter a valid US or Egypt phone';
      },
    ),
  ];

  List<Widget> _locationSection() {
    final coords = _coords;
    return [
      const SizedBox(height: 8),
      const DashFormSection(
        title: 'Location',
        icon: Icons.location_on_outlined,
      ),
      DashFormField(
        controller: _locationName,
        label: 'Location name *',
        hint: 'e.g. Downtown Houston',
        validator: (v) => _required(v, 'Location name'),
      ),
      const SizedBox(height: 14),
      DashFormField(
        controller: _coordinates,
        label: 'Coordinates *',
        hint: '29.7604, -95.3698  or paste a Google Maps link',
        onChanged: (_) => setState(() {}),
        validator: (v) {
          final c = parseCoordinates(v ?? '');
          if (c == null) return 'Paste "lat, lng" or a Google Maps link';
          if (!isAllowedRestaurantLocation(c.lat, c.lng)) {
            return 'Location must be in the USA or Egypt';
          }
          return null;
        },
      ),
      if (coords != null)
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Text(
            'lat ${coords.lat}, lng ${coords.lng}',
            style: TextStyle(color: Colors.greenAccent[200], fontSize: 12),
          ),
        ),
      const SizedBox(height: 14),
      DashFormField(
        controller: _locationDetails,
        label: 'Location details *',
        hint: 'Street, building, landmark',
        maxLines: 2,
        validator: (v) => _required(v, 'Location details'),
      ),
    ];
  }

  List<Widget> _hoursSection() => [
    const SizedBox(height: 8),
    const DashFormSection(title: 'Working hours', icon: Icons.schedule),
    Row(
      children: [
        Expanded(
          child: DashTimeField(
            label: 'Opens at',
            minutes: _openAt,
            onChanged: (m) => setState(() => _openAt = m),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DashTimeField(
            label: 'Closes at',
            minutes: _closeAt,
            onChanged: (m) => setState(() => _closeAt = m),
          ),
        ),
      ],
    ),
  ];
}
