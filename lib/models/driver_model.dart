import 'package:intl/intl.dart';

class DriverModel {
  final String id;
  final String? name;
  final String? email;
  final String? phone;
  final String? licenceImage;
  final Map<String, dynamic>? licenceData;
  /// `drivers.rate` — computed by the DB from ride + food ratings.
  /// Read-only, never part of [toJson].
  final double rate;
  final Map<String, dynamic>? carInfo;
  final bool activated;
  final bool online;
  final double? lat;
  final double? lng;
  final String? city;
  final String? profileImage;
  final String? fcmToken;
  final DateTime createdAt;
  final String? licenseFrontSide;
  final String? licenseBackSide;
  final String? idFrontSide;
  final String? idBackSide;
  final String? video;
  final String? backgroundCheck;
  final String? deviceToken;
  final String? type;

  DriverModel({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.licenceImage,
    this.licenceData,
    this.rate = 0.0,
    this.carInfo,
    this.activated = false,
    this.online = false,
    this.lat,
    this.lng,
    this.city,
    this.profileImage,
    this.fcmToken,
    required this.createdAt,
    this.licenseFrontSide,
    this.licenseBackSide,
    this.idFrontSide,
    this.idBackSide,
    this.video,
    this.backgroundCheck,
    this.deviceToken,
    this.type,
  });

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      id: json['id'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      licenceImage: json['licence_image'] as String?,
      licenceData: json['licence_data'] as Map<String, dynamic>?,
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      carInfo: json['car_info'] as Map<String, dynamic>?,
      activated: json['activated'] as bool? ?? false,
      online: json['online'] as bool? ?? false,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      city: json['city'] as String?,
      profileImage: json['profile_image'] as String?,
      fcmToken: json['fcm_token'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      licenseFrontSide: json['license_front_side'] as String?,
      licenseBackSide: json['license_back_side'] as String?,
      idFrontSide: json['id_front_side'] as String?,
      idBackSide: json['id_back_side'] as String?,
      video: json['video'] as String?,
      backgroundCheck: json['background_check'] as String?,
      deviceToken: json['device_token'] as String?,
      type: json['type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'licence_image': licenceImage,
      'licence_data': licenceData,
      'car_info': carInfo,
      'activated': activated,
      'online': online,
      'lat': lat,
      'lng': lng,
      'city': city,
      'profile_image': profileImage,
      'fcm_token': fcmToken,
      'created_at': createdAt.toIso8601String(),
      'license_front_side': licenseFrontSide,
      'license_back_side': licenseBackSide,
      'id_front_side': idFrontSide,
      'id_back_side': idBackSide,
      'video': video,
      'background_check': backgroundCheck,
      'device_token': deviceToken,
      'type': type,
    };
  }

  String get formattedDate =>
      DateFormat('MMM dd, yyyy HH:mm').format(createdAt);

  String get carDescription {
    if (carInfo == null) return 'N/A';
    final brand = carInfo!['brand'] ?? carInfo!['make'] ?? '';
    final model = carInfo!['model'] ?? '';
    final year = carInfo!['year'] ?? '';
    final color = carInfo!['color'] ?? '';
    final plate = carInfo!['plate_number'] ?? '';
    final parts = [year, color, brand, model].where((e) => e.toString().isNotEmpty);
    final desc = parts.join(' ').trim();
    return plate.toString().isNotEmpty ? '$desc • $plate' : (desc.isEmpty ? 'N/A' : desc);
  }

  String? get carImage => carInfo != null && carInfo!['image'] != null
      ? carInfo!['image'] as String?
      : null;
}
