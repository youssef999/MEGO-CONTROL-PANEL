class CustomerSupportModel {
  final int id;
  final String? name;
  final String? email;
  final String? password;
  final double rate;
  final String? type;
  final String? deviceToken;

  const CustomerSupportModel({
    required this.id,
    this.name,
    this.email,
    this.password,
    this.rate = 0,
    this.type,
    this.deviceToken,
  });

  factory CustomerSupportModel.fromJson(Map<String, dynamic> json) {
    return CustomerSupportModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String?,
      email: json['email'] as String?,
      password: json['password'] as String?,
      rate: (json['rate'] as num?)?.toDouble() ?? 0,
      type: json['type'] as String?,
      deviceToken: json['device_token'] as String?,
    );
  }

  Map<String, dynamic> toInsertJson() => {
    'name': name?.trim(),
    'email': email?.trim(),
    'password': password,
    'rate': rate,
    'type': type?.trim(),
    'device_token': deviceToken?.trim(),
  };

  Map<String, dynamic> toUpdateJson() => {
    'name': name?.trim(),
    'email': email?.trim(),
    'password': password,
    'rate': rate,
    'type': type?.trim(),
    'device_token': deviceToken?.trim(),
  };
}
