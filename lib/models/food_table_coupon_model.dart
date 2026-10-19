import 'package:intl/intl.dart';

class FoodTableCouponModel {
  final String id;
  final String? userId;
  final String? userEmail;
  final String? type;
  final DateTime? validUntil;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? couponFor;

  FoodTableCouponModel({
    required this.id,
    this.userId,
    this.userEmail,
    this.type,
    this.validUntil,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
    this.couponFor,
  });

  factory FoodTableCouponModel.fromJson(Map<String, dynamic> json) {
    return FoodTableCouponModel(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      userEmail: json['user_email'] as String?,
      type: json['type'] as String?,
      validUntil:
          json['valid_until'] != null
              ? DateTime.parse(json['valid_until'] as String)
              : null,
      active: json['active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      couponFor: json['coupon_for'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_email': userEmail,
      'type': type,
      'valid_until': validUntil?.toIso8601String(),
      'active': active,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'coupon_for': couponFor,
    };
  }

  String get formattedCreatedAt => DateFormat('MMM dd, yyyy').format(createdAt);

  String get formattedValidUntil =>
      validUntil != null
          ? DateFormat('MMM dd, yyyy').format(validUntil!)
          : 'No Expiry';

  bool get isExpired =>
      validUntil != null && DateTime.now().isAfter(validUntil!);
}
