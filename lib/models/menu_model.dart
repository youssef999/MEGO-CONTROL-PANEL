class MenuModel {
  final int id;
  final String? name;
  final double? price;
  final String? image;
  final String? category;
  final String? restaurant;
  final int? restaurantId;
  final String? itemCategory;

  MenuModel({
    required this.id,
    this.name,
    this.price,
    this.image,
    this.category,
    this.restaurant,
    this.restaurantId,
    this.itemCategory,
  });

  factory MenuModel.fromJson(Map<String, dynamic> json) {
    return MenuModel(
      id: json['id'] as int,
      name: json['name'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      image: json['image'] as String?,
      category: json['category'] as String?,
      restaurant: json['restaurant'] as String?,
      restaurantId: json['restaurant_id'] as int?,
      itemCategory: json['item_category'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'image': image,
      'category': category,
      'restaurant': restaurant,
      'restaurant_id': restaurantId,
      'item_category': itemCategory,
    };
  }
}
