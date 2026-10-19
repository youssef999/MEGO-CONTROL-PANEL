import 'package:intl/intl.dart';

/// Matches Supabase table `food_app_commission_trans`.
class FoodAppCommissionModel {
  final int id;
  final String? orderId;
  final double amount;
  final DateTime date;

  FoodAppCommissionModel({
    required this.id,
    this.orderId,
    this.amount = 0,
    required this.date,
  });

  factory FoodAppCommissionModel.fromJson(Map<String, dynamic> json) {
    return FoodAppCommissionModel(
      id: json['id'] as int,
      orderId: json['order_id']?.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
    );
  }

  String get formattedDate =>
      DateFormat('MMM dd, yyyy HH:mm').format(date.toLocal());

  String get formattedAmount => '\$${amount.toStringAsFixed(2)}';
}
