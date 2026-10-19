class AdminModel {
  final int id;
  final String email;
  final String password;

  const AdminModel({
    required this.id,
    required this.email,
    required this.password,
  });

  factory AdminModel.fromJson(Map<String, dynamic> json) {
    return AdminModel(
      id: (json['id'] as num).toInt(),
      email: (json['email'] as String?)?.trim() ?? '',
      password: json['password'] as String? ?? '',
    );
  }

  Map<String, dynamic> toInsertJson() => {
    'email': email.trim(),
    'password': password,
  };

  Map<String, dynamic> toUpdateJson() => {
    'email': email.trim(),
    'password': password,
  };
}
