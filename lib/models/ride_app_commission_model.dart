import 'package:intl/intl.dart';

/// Matches Supabase table `ride_app_commission_trans`.
class RideAppCommissionModel {
  final int id;
  final String? rideId;
  final double amount;
  final DateTime date;

  RideAppCommissionModel({
    required this.id,
    this.rideId,
    this.amount = 0,
    required this.date,
  });

  factory RideAppCommissionModel.fromJson(Map<String, dynamic> json) {
    return RideAppCommissionModel(
      id: json['id'] as int,
      rideId: json['ride_id']?.toString(),
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
