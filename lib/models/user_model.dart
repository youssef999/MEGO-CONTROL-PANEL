import 'package:intl/intl.dart';

class UserModel {
  final String id;
  final String? name;
  final String? email;
  final String? phone;
  final String? userType;
  final DateTime createdAt;
  final String? profile;
  final String? fcmToken;
  final String? deviceToken;

  UserModel({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.userType,
    required this.createdAt,
    this.profile,
    this.fcmToken,
    this.deviceToken,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      userType: json['user_type'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      profile: json['profile'] as String?,
      fcmToken: json['fcm_token'] as String?,
      deviceToken: json['device_token'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'user_type': userType,
      'created_at': createdAt.toIso8601String(),
      'profile': profile,
      'fcm_token': fcmToken,
      'device_token': deviceToken,
    };
  }

  String get formattedDate =>
      DateFormat('MMM dd, yyyy HH:mm').format(createdAt);
}
