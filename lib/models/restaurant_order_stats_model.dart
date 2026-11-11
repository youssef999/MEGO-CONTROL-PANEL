import 'food_checkout_model.dart';

/// Order counters for one restaurant (`food_checkout` rows).
class RestaurantOrderStatsModel {
  final int total;

  /// pending / accepted / assigned — not finished yet.
  final int inProgress;
  final int delivered;
  final int cancelled;

  /// Food sales (before coupon) of delivered orders — the restaurant's revenue.
  final double sales;

  const RestaurantOrderStatsModel({
    this.total = 0,
    this.inProgress = 0,
    this.delivered = 0,
    this.cancelled = 0,
    this.sales = 0,
  });

  static const empty = RestaurantOrderStatsModel();

  factory RestaurantOrderStatsModel.fromOrders(
    Iterable<FoodCheckoutModel> orders,
  ) {
    var total = 0, inProgress = 0, delivered = 0, cancelled = 0;
    var sales = 0.0;
    for (final o in orders) {
      total++;
      if (o.isCompleted) {
        delivered++;
        sales += o.foodAmount;
      } else if (o.isCancelled) {
        cancelled++;
      } else {
        inProgress++;
      }
    }
    return RestaurantOrderStatsModel(
      total: total,
      inProgress: inProgress,
      delivered: delivered,
      cancelled: cancelled,
      sales: sales,
    );
  }
}
