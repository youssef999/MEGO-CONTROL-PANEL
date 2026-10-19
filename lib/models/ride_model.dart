import 'package:intl/intl.dart';

class RideModel {
  final String id;
  final String? rideRequestId;
  final String? riderId;
  final DateTime? startTime;
  final DateTime? endTime;
  final double? totalPrice;
  final double? currentDriverLat;
  final double? currentDriverLng;
  final DateTime createdAt;
  final String? driverId;
  final String? status;
  final String? paymentType;
  final double? totalCash;
  final double? totalWallet;
  final bool paymentSent;

  /// What the rider pays after coupon (`user_payment`); null = no coupon.
  final double? userPayment;

  /// Coupon part paid by the app to the driver (`discount_amount`).
  final double? discountAmount;

  RideModel({
    required this.id,
    this.rideRequestId,
    this.riderId,
    this.startTime,
    this.endTime,
    this.totalPrice,
    this.currentDriverLat,
    this.currentDriverLng,
    required this.createdAt,
    this.driverId,
    this.status,
    this.paymentType,
    this.totalCash,
    this.totalWallet,
    this.paymentSent = false,
    this.userPayment,
    this.discountAmount,
  });

  static double? _d(dynamic v) =>
      v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

  factory RideModel.fromJson(Map<String, dynamic> json) {
    return RideModel(
      id: json['id'] as String,
      rideRequestId: json['ride_request_id'] as String?,
      riderId: json['rider_id'] as String?,
      startTime:
          json['start_time'] != null
              ? DateTime.parse(json['start_time'] as String)
              : null,
      endTime:
          json['end_time'] != null
              ? DateTime.parse(json['end_time'] as String)
              : null,
      totalPrice: _d(json['total_price']),
      currentDriverLat: (json['current_driver_lat'] as num?)?.toDouble(),
      currentDriverLng: (json['current_driver_lng'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      driverId: json['driver_id'] as String?,
      status: json['status'] as String?,
      paymentType: json['payment_type'] as String?,
      totalCash: _d(json['total_cash']),
      totalWallet: _d(json['total_wallet']),
      paymentSent: json['payment_sent'] as bool? ?? false,
      userPayment: _d(json['user_payment']),
      discountAmount: _d(json['discount_amount']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ride_request_id': rideRequestId,
      'rider_id': riderId,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'total_price': totalPrice,
      'current_driver_lat': currentDriverLat,
      'current_driver_lng': currentDriverLng,
      'created_at': createdAt.toIso8601String(),
      'driver_id': driverId,
      'status': status,
      'payment_type': paymentType,
      'total_cash': totalCash,
      'total_wallet': totalWallet,
      'payment_sent': paymentSent,
    };
  }

  String get formattedCreatedAt =>
      DateFormat('MMM dd, yyyy HH:mm').format(createdAt);

  String get formattedStartTime =>
      startTime != null ? DateFormat('HH:mm').format(startTime!) : 'N/A';

  String get formattedEndTime =>
      endTime != null ? DateFormat('HH:mm').format(endTime!) : 'N/A';

  /// Driver-agreed fare (`total_price`) — what the driver app shows.
  double get driverFare => totalPrice ?? 0;

  /// Same rule as the client app `riderPayablePrice`.
  bool get hasCouponDiscount =>
      (discountAmount ?? 0) > 0 ||
      (userPayment != null && userPayment! < driverFare);

  /// What the rider paid — what the client app shows.
  double get riderPaid =>
      hasCouponDiscount ? (userPayment ?? driverFare) : driverFare;

  /// Coupon covered by the app (fare − rider paid).
  double get couponCovered =>
      hasCouponDiscount ? (driverFare - riderPaid).clamp(0, double.infinity).toDouble() : 0;

  bool get isCompleted => (status ?? '').toLowerCase() == 'completed';

  String get duration {
    if (startTime == null || endTime == null) return 'N/A';
    final diff = endTime!.difference(startTime!);
    final minutes = diff.inMinutes;
    return '$minutes mins';
  }
}
