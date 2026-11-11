import 'package:flutter/material.dart';

/// Food order status colors (same as the orders list screen).
Color orderStatusColor(String? status) {
  switch (status?.toLowerCase()) {
    case 'done':
    case 'delivered':
      return Colors.greenAccent;
    case 'assigned':
      return Colors.tealAccent;
    case 'accepted':
      return Colors.blueAccent;
    case 'pending':
      return Colors.orangeAccent;
    case 'cancelled':
      return Colors.redAccent;
    default:
      return Colors.grey;
  }
}

/// `done` is the legacy name of `delivered`.
String orderStatusLabel(String? status) {
  final s = (status ?? '').toLowerCase();
  if (s.isEmpty) return 'UNKNOWN';
  return (s == 'done' ? 'delivered' : s).toUpperCase();
}
