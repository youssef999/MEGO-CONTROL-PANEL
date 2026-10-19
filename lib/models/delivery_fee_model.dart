class DeliveryFeeModel {
  final int? id;
  final double? pricePerKm;

  const DeliveryFeeModel({this.id, this.pricePerKm});

  factory DeliveryFeeModel.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'];
    final priceRaw = json['price_per_km'];
    return DeliveryFeeModel(
      id: idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw'),
      pricePerKm: priceRaw is num
          ? priceRaw.toDouble()
          : double.tryParse('$priceRaw'),
    );
  }

  Map<String, dynamic> toTableJson() => {
    'price_per_km': pricePerKm,
  };
}
