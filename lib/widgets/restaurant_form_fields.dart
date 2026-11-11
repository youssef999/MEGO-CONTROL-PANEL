import 'package:flutter/material.dart';

/// Dark dashboard form inputs used by the add-restaurant dialog.
class DashFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;

  const DashFormField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.onChanged,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      onChanged: onChanged,
      validator: validator,
      decoration: dashInputDecoration(label, hint: hint, suffix: suffix),
    );
  }
}

InputDecoration dashInputDecoration(
  String label, {
  String? hint,
  Widget? suffix,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
    labelStyle: TextStyle(color: Colors.grey[400]),
    suffixIcon: suffix,
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Colors.deepPurpleAccent),
    ),
    errorBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Colors.redAccent),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Colors.redAccent),
    ),
  );
}

/// Section title inside the dialog.
class DashFormSection extends StatelessWidget {
  final String title;
  final IconData icon;

  const DashFormSection({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.deepPurpleAccent),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Opening / closing time picker field (minutes from midnight).
class DashTimeField extends StatelessWidget {
  final String label;
  final int minutes;
  final ValueChanged<int> onChanged;

  const DashTimeField({
    super.key,
    required this.label,
    required this.minutes,
    required this.onChanged,
  });

  static String format(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
        );
        if (picked != null) onChanged(picked.hour * 60 + picked.minute);
      },
      child: InputDecorator(
        decoration: dashInputDecoration(
          label,
          suffix: const Icon(Icons.schedule, color: Colors.grey),
        ),
        child: Text(
          format(minutes),
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
