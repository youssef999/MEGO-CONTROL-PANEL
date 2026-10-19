import 'package:intl/intl.dart';

/// Matches Supabase table `resturant_wallet`.
///
/// Paid-out state uses the same columns as the restaurant app:
/// `sent` (paid by admin) and `via_stripe` (paid by Stripe Connect).
/// `is_sent` is a legacy column, only kept in sync on writes.
class RestaurantWalletModel {
  final int id;
  final int? resId;
  final int? orderId;
  final double amount;
  final DateTime? date;
  final bool isSent;
  final bool viaStripe;

  RestaurantWalletModel({
    required this.id,
    this.resId,
    this.orderId,
    this.amount = 0,
    this.date,
    this.isSent = false,
    this.viaStripe = false,
  });

  factory RestaurantWalletModel.fromJson(Map<String, dynamic> json) {
    return RestaurantWalletModel(
      id: json['id'] as int,
      resId: json['res_id'] as int?,
      orderId: json['order_id'] as int?,
      amount: num.tryParse(json['amount']?.toString() ?? '')?.toDouble() ?? 0,
      date: _parseDate(json['date']),
      isSent: json['sent'] == true,
      viaStripe: json['via_stripe'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'res_id': resId,
      'order_id': orderId,
      'amount': amount,
      'date': date?.toIso8601String(),
      'sent': isSent,
      'is_sent': isSent,
      'via_stripe': viaStripe,
    };
  }

  /// Same rule as the restaurant app balance.
  bool get countsInBalance => !isSent && !viaStripe;

  RestaurantWalletModel copyWith({bool? isSent}) {
    return RestaurantWalletModel(
      id: id,
      resId: resId,
      orderId: orderId,
      amount: amount,
      date: date,
      isSent: isSent ?? this.isSent,
      viaStripe: viaStripe,
    );
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  String get formattedAmount => '\$${amount.toStringAsFixed(2)}';

  String get formattedDate {
    if (date == null) return '—';
    return DateFormat('MMM dd, yyyy HH:mm').format(date!.toLocal());
  }
}
