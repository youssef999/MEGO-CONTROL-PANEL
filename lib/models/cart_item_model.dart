class CartItemModel {
  final int id;
  final String? itemName;
  final int? restaurantId;
  final String? userEmail;
  final double? itemPrice;
  final int? itemQuant;
  final String? itemImage;
  final DateTime? createdAt;
  final int? cartId;

  CartItemModel({
    required this.id,
    this.itemName,
    this.restaurantId,
    this.userEmail,
    this.itemPrice,
    this.itemQuant,
    this.itemImage,
    this.createdAt,
    this.cartId,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      id: json['id'] as int,
      itemName: json['item_name'] as String?,
      restaurantId: json['restaurant_id'] as int?,
      userEmail: json['user_email'] as String?,
      itemPrice: (json['item_price'] as num?)?.toDouble(),
      itemQuant: json['item_quant'] as int?,
      itemImage: json['item_image'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      cartId: json['cart_id'] as int?,
    );
  }
}
