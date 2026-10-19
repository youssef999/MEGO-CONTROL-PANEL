import 'package:intl/intl.dart';

class PaymentModel {
  final String id;
  final String? rideId;
  final double amount;
  final String? paymentMethod;
  final String status;
  final DateTime createdAt;

  PaymentModel({
    required this.id,
    this.rideId,
    required this.amount,
    this.paymentMethod,
    this.status = 'pending',
    required this.createdAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as String,
      rideId: json['ride_id'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ride_id': rideId,
      'amount': amount,
      'payment_method': paymentMethod,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get formattedCreatedAt =>
      DateFormat('MMM dd, yyyy HH:mm').format(createdAt);

  String get formattedAmount => '\$${amount.toStringAsFixed(2)}';
}
