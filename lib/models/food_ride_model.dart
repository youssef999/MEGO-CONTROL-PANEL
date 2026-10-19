import 'package:intl/intl.dart';

/// Matches Supabase table `food_ride`.
class FoodRideModel {
  final String id;
  final String? resId;
  final String? driverId;
  final String? orderId;
  final String? status;
  final DateTime createdAt;

  FoodRideModel({
    required this.id,
    this.resId,
    this.driverId,
    this.orderId,
    this.status,
    required this.createdAt,
  });

  factory FoodRideModel.fromJson(Map<String, dynamic> json) {
    return FoodRideModel(
      id: json['id'].toString(),
      resId: json['res_id']?.toString(),
      driverId: json['driver_id']?.toString(),
      orderId: json['order_id']?.toString(),
      status: json['status'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'res_id': resId,
      'driver_id': driverId,
      'order_id': orderId,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get formattedCreatedAt =>
      DateFormat('MMM dd, yyyy HH:mm').format(createdAt.toLocal());
}
