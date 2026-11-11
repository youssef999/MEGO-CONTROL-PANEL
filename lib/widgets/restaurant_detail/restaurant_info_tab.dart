import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/restaurant_model.dart';

/// Contact, location and working hours of a restaurant.
class RestaurantInfoTab extends StatelessWidget {
  final RestaurantModel restaurant;

  const RestaurantInfoTab({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final coords = (r.lat != null && r.lng != null)
        ? '${r.lat}, ${r.lng}'
        : null;
    final rows = <(IconData, String, String?)>[
      (Icons.email_outlined, 'Email', r.email),
      (Icons.phone_outlined, 'Phone', r.phone),
      (Icons.schedule, 'Working hours', r.hoursLabel),
      (Icons.place_outlined, 'Location', r.locationName),
      (Icons.signpost_outlined, 'Address details', r.locationDetails),
      (Icons.my_location, 'Coordinates', coords),
      (Icons.notes, 'Details', r.details),
      (
        Icons.notifications_active_outlined,
        'Push notifications',
        (r.deviceToken ?? '').isEmpty
            ? 'Not registered (restaurant has not logged in yet)'
            : 'Registered',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D2D),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              for (final (i, row) in rows.indexed) ...[
                if (i > 0)
                  Divider(height: 1, color: Colors.white.withOpacity(0.06)),
                _InfoRow(icon: row.$1, label: row.$2, value: row.$3),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;

  const _InfoRow({required this.icon, required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    final text = (value ?? '').trim();
    return ListTile(
      leading: Icon(icon, color: Colors.deepPurpleAccent, size: 20),
      title: Text(
        label,
        style: TextStyle(color: Colors.grey[400], fontSize: 12),
      ),
      subtitle: Text(
        text.isEmpty ? '—' : text,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      trailing: text.isEmpty
          ? null
          : IconButton(
              tooltip: 'Copy',
              icon: Icon(Icons.copy, size: 16, color: Colors.grey[500]),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('$label copied')));
              },
            ),
    );
  }
}
