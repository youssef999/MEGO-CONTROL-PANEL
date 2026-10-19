import 'food_checkout_model.dart';

/// Money split of one food order, as written by the driver app on delivery
/// (`food_app_commission_trans`, `resturant_wallet`, `food_driver_wallet`).
/// A null amount = no ledger row yet → the app formula is used instead.
class FoodOrderSettlementModel {
  /// Same rate as the driver app settlement (12% of food before coupon).
  static const double appCommissionRate = 0.12;

  final double? commission;
  final double? restaurant;

  /// Sum of `food_driver_wallet.value` for the order: +delivery (card/wallet)
  /// or −food (cash: the driver collected the food money from the customer).
  final double? driverWalletEntry;

  const FoodOrderSettlementModel({
    this.commission,
    this.restaurant,
    this.driverWalletEntry,
  });

  bool get isSettled => commission != null || restaurant != null;

  static double _money(double v) => double.parse(v.toStringAsFixed(2));

  static double expectedCommission(FoodCheckoutModel o) =>
      _money(o.foodAmount * appCommissionRate);

  static double expectedRestaurant(FoodCheckoutModel o) =>
      _money(o.foodAmount - expectedCommission(o));

  double commissionFor(FoodCheckoutModel o) =>
      commission ?? expectedCommission(o);

  double restaurantFor(FoodCheckoutModel o) =>
      restaurant ?? expectedRestaurant(o);

  /// The driver always earns the delivery fee (cash: kept from the customer).
  double driverEarningsFor(FoodCheckoutModel o) => o.deliveryPrice ?? 0;
}
