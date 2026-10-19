import 'package:intl/intl.dart';

class FoodCheckoutModel {
  final int id;
  final String? userEmail;
  final int? cartId;

  /// What the customer pays = food − coupon + delivery (as saved by the app).
  final double? total;
  final double? deliveryPrice;

  /// Food before coupon (`food_subtotal`).
  final double? foodSubtotal;

  /// Coupon discount on food, paid by the app (`discount_amount`).
  final double? discountAmount;
  final double? walletPaid;
  final double? refundedAmount;
  final String? paymentType;
  final int? locationId;
  final DateTime createdAt;
  final String? status;
  final int? restaurantId;
  final String? driverId;

  FoodCheckoutModel({
    required this.id,
    this.userEmail,
    this.cartId,
    this.total,
    this.deliveryPrice,
    this.foodSubtotal,
    this.discountAmount,
    this.walletPaid,
    this.refundedAmount,
    this.paymentType,
    this.locationId,
    required this.createdAt,
    this.status,
    this.restaurantId,
    this.driverId,
  });

  static double? _d(dynamic v) =>
      v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

  factory FoodCheckoutModel.fromJson(Map<String, dynamic> json) {
    return FoodCheckoutModel(
      id: json['id'] as int,
      userEmail: json['user_email'] as String?,
      cartId: json['cart_id'] as int?,
      total: _d(json['total']),
      deliveryPrice: _d(json['delivery_price']),
      foodSubtotal: _d(json['food_subtotal']),
      discountAmount: _d(json['discount_amount']),
      walletPaid: _d(json['wallet_paid']),
      refundedAmount: _d(json['refunded_amount']),
      paymentType: json['payment_type'] as String?,
      locationId: json['location_id'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      status: json['status'] as String?,
      restaurantId: json['restaurant_id'] as int?,
      driverId: json['driver_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_email': userEmail,
      'cart_id': cartId,
      'total': total,
      'delivery_price': deliveryPrice,
      'location_id': locationId,
      'created_at': createdAt.toIso8601String(),
      'status': status,
      'restaurant_id': restaurantId,
      'driver_id': driverId,
    };
  }

  String get formattedCreatedAt =>
      DateFormat('MMM dd, yyyy HH:mm').format(createdAt);

  /// Customer paid — `total` already includes delivery and the coupon.
  double get grandTotal => total ?? 0;

  /// Food before coupon (old rows without `food_subtotal`: total − delivery + coupon).
  double get foodAmount =>
      foodSubtotal ??
      ((total ?? 0) - (deliveryPrice ?? 0) + (discountAmount ?? 0))
          .clamp(0, double.infinity)
          .toDouble();

  double get couponDiscount => discountAmount ?? 0;

  /// Apps finish orders as `delivered` (`done` = legacy).
  bool get isCompleted {
    final s = (status ?? '').toLowerCase();
    return s == 'delivered' || s == 'done';
  }

  bool get isCancelled => (status ?? '').toLowerCase() == 'cancelled';
}
