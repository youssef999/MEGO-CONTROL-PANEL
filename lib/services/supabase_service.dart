import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/driver_model.dart';
import '../models/ride_model.dart';
import '../models/coupon_model.dart';
import '../models/food_checkout_model.dart';
import '../models/food_order_settlement_model.dart';
import '../models/restaurant_model.dart';
import '../models/food_table_coupon_model.dart';
import '../models/payment_model.dart';
import '../models/ride_app_commission_model.dart';
import '../models/food_app_commission_model.dart';
import '../models/menu_model.dart';
import '../models/category_model.dart';
import '../models/user_food_location_model.dart';
import '../models/cart_item_model.dart';
import '../models/ride_request_model.dart';
import '../models/admin_model.dart';
import '../models/customer_support_model.dart';
import '../models/restaurant_wallet_model.dart';
import '../models/partner_payout_method_model.dart';
import '../models/food_driver_money_request_model.dart';
import '../models/food_ride_model.dart';
import '../models/food_complain_model.dart';
import '../models/stripe_keys_model.dart';
import '../models/delivery_fee_model.dart';
import '../widgets/firebase_storage_image.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;

  String _normalizeFirebaseStorageHttpUrl(String? raw) {
    return FirebaseStorageImage.normalizeUrl(raw) ?? '';
  }

  Future<void> migrateLegacyFirebaseImageUrlsOnce() async {
    try {
      final restaurants = await _supabase.from('restaurants').select('id,image');
      for (final row in (restaurants as List)) {
        final id = row['id'];
        final current = row['image'] as String?;
        final fixed = _normalizeFirebaseStorageHttpUrl(current);
        if (current != null && fixed.isNotEmpty && fixed != current) {
          await _supabase.from('restaurants').update({'image': fixed}).eq('id', id);
        }
      }

      final menuItems = await _supabase.from('menu').select('id,image');
      for (final row in (menuItems as List)) {
        final id = row['id'];
        final current = row['image'] as String?;
        final fixed = _normalizeFirebaseStorageHttpUrl(current);
        if (current != null && fixed.isNotEmpty && fixed != current) {
          await _supabase.from('menu').update({'image': fixed}).eq('id', id);
        }
      }
    } catch (e) {
      print('Error migrating Firebase image URLs: $e');
      rethrow;
    }
  }

  Future<List<UserModel>> getUsers() async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => UserModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching users: $e');
      rethrow;
    }
  }

  Future<void> deleteUser(String id) async {
    try {
      await _supabase.from('users').delete().eq('id', id);
    } catch (e) {
      print('Error deleting user: $e');
      rethrow;
    }
  }

  Future<List<UserModel>> getUsersByIds(List<String> ids) async {
    try {
      if (ids.isEmpty) return [];
      final response = await _supabase.from('users').select().inFilter('id', ids);
      return (response as List)
          .map((json) => UserModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching users by ids: $e');
      rethrow;
    }
  }

  Future<UserModel?> getUserById(String id) async {
    try {
      final trimmed = id.trim();
      if (trimmed.isEmpty) return null;
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', trimmed)
          .maybeSingle();
      if (response == null) return null;
      return UserModel.fromJson(response);
    } catch (e) {
      print('Error fetching user by id: $e');
      rethrow;
    }
  }

  Future<UserModel?> getUserByEmail(String email) async {
    try {
      final trimmed = email.trim();
      if (trimmed.isEmpty) return null;
      final response = await _supabase
          .from('users')
          .select()
          .eq('email', trimmed)
          .maybeSingle();
      if (response == null) return null;
      return UserModel.fromJson(response);
    } catch (e) {
      print('Error fetching user by email: $e');
      rethrow;
    }
  }

  Future<List<DriverModel>> getDrivers() async {
    try {
      final response = await _supabase
          .from('drivers')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => DriverModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching drivers: $e');
      rethrow;
    }
  }

  Future<DriverModel?> getDriverById(String id) async {
    try {
      final response = await _supabase
          .from('drivers')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (response == null) return null;
      return DriverModel.fromJson(response);
    } catch (e) {
      print('Error fetching driver by id: $e');
      rethrow;
    }
  }

  Future<List<DriverModel>> getDriversByIds(List<String> ids) async {
    try {
      if (ids.isEmpty) return [];
      final response = await _supabase.from('drivers').select().inFilter('id', ids);
      return (response as List)
          .map((json) => DriverModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching drivers by ids: $e');
      rethrow;
    }
  }

  Future<void> updateDriverStatus(String id, bool activated) async {
    try {
      await _supabase
          .from('drivers')
          .update({'activated': activated})
          .eq('id', id);
    } catch (e) {
      print('Error updating driver status: $e');
      rethrow;
    }
  }

  Future<void> deleteDriver(String id) async {
    try {
      await _supabase.from('drivers').delete().eq('id', id);
    } catch (e) {
      print('Error deleting driver: $e');
      rethrow;
    }
  }

  Future<List<RideModel>> getRides() async {
    try {
      final response = await _supabase
          .from('rides')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => RideModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching rides: $e');
      rethrow;
    }
  }

  Future<List<RideModel>> getRidesByRiderId(String riderId) async {
    try {
      final response = await _supabase
          .from('rides')
          .select()
          .eq('rider_id', riderId)
          .order('created_at', ascending: false);
      return (response as List)
          .map((json) => RideModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching rides by rider: $e');
      rethrow;
    }
  }

  Future<List<RideRequestModel>> getRideRequestsByIds(List<String> ids) async {
    try {
      if (ids.isEmpty) return [];
      final response = await _supabase
          .from('ride_requests')
          .select('id, pickup_place, dropoff_place')
          .inFilter('id', ids);
      return (response as List)
          .map((json) => RideRequestModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching ride requests by ids: $e');
      rethrow;
    }
  }

  Future<List<RideModel>> getRidesByDriverId(String driverId) async {
    try {
      final response = await _supabase
          .from('rides')
          .select()
          .eq('driver_id', driverId)
          .order('created_at', ascending: false);
      return (response as List)
          .map((json) => RideModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching rides by driver: $e');
      rethrow;
    }
  }

  Future<List<CouponModel>> getCoupons() async {
    try {
      final response = await _supabase
          .from('coupons')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => CouponModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching coupons: $e');
      rethrow;
    }
  }

  Future<CouponModel> insertCoupon({
    String? userId,
    String? type,
    DateTime? validUntil,
    bool active = true,
    String? couponFor,
  }) async {
    try {
      final uid = userId != null && userId.trim().isNotEmpty ? userId.trim() : null;
      final t = type != null && type.trim().isNotEmpty ? type.trim() : null;
      final cf =
          couponFor != null && couponFor.trim().isNotEmpty ? couponFor.trim() : null;
      final data = <String, dynamic>{
        'user_id': uid,
        'type': t,
        'valid_until': validUntil?.toIso8601String(),
        'active': active,
        'coupon_for': cf,
      };
      final response =
          await _supabase.from('coupons').insert(data).select().single();
      return CouponModel.fromJson(response);
    } catch (e) {
      print('Error inserting coupon: $e');
      rethrow;
    }
  }

  Future<void> updateCoupon(CouponModel coupon) async {
    try {
      final uid = coupon.userId != null && coupon.userId!.trim().isNotEmpty
          ? coupon.userId!.trim()
          : null;
      final t = coupon.type != null && coupon.type!.trim().isNotEmpty
          ? coupon.type!.trim()
          : null;
      final cf = coupon.couponFor != null && coupon.couponFor!.trim().isNotEmpty
          ? coupon.couponFor!.trim()
          : null;
      await _supabase
          .from('coupons')
          .update({
            'user_id': uid,
            'type': t,
            'valid_until': coupon.validUntil?.toIso8601String(),
            'active': coupon.active,
            'coupon_for': cf,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', coupon.id);
    } catch (e) {
      print('Error updating coupon: $e');
      rethrow;
    }
  }

  Future<void> deleteCoupon(String id) async {
    try {
      await _supabase.from('coupons').delete().eq('id', id);
    } catch (e) {
      print('Error deleting coupon: $e');
      rethrow;
    }
  }

  Future<FoodCheckoutModel?> getFoodCheckoutById(int id) async {
    try {
      final response = await _supabase
          .from('food_checkout')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (response == null) return null;
      return FoodCheckoutModel.fromJson(response);
    } catch (e) {
      print('Error fetching food checkout by id: $e');
      rethrow;
    }
  }

  /// Real money split of one order from the wallets the driver app writes.
  Future<FoodOrderSettlementModel> getFoodOrderSettlement(int orderId) async {
    Future<double?> sumOf(
      String table,
      String column,
      Object orderIdValue,
    ) async {
      try {
        final rows = await _supabase
            .from(table)
            .select(column)
            .eq('order_id', orderIdValue);
        final list = rows as List;
        if (list.isEmpty) return null;
        return list.fold<double>(
          0,
          (s, r) => s + (num.tryParse(r[column]?.toString() ?? '') ?? 0),
        );
      } catch (e) {
        print('Error loading $table for order $orderId: $e');
        return null;
      }
    }

    final results = await Future.wait([
      sumOf('food_app_commission_trans', 'amount', orderId.toString()),
      sumOf('resturant_wallet', 'amount', orderId),
      sumOf('food_driver_wallet', 'value', orderId),
    ]);
    return FoodOrderSettlementModel(
      commission: results[0],
      restaurant: results[1],
      driverWalletEntry: results[2],
    );
  }

  Future<List<FoodCheckoutModel>> getFoodCheckouts() async {
    try {
      final response = await _supabase
          .from('food_checkout')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => FoodCheckoutModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching food checkouts: $e');
      rethrow;
    }
  }

  Future<List<FoodCheckoutModel>> getFoodCheckoutsByUserEmail(String email) async {
    try {
      if (email.isEmpty) return [];
      final response = await _supabase
          .from('food_checkout')
          .select()
          .eq('user_email', email)
          .order('created_at', ascending: false);
      return (response as List)
          .map((json) => FoodCheckoutModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching food checkouts by user: $e');
      rethrow;
    }
  }

  Future<List<UserFoodLocationModel>> getUserFoodLocationsByIds(
    List<int> locationIds,
  ) async {
    try {
      if (locationIds.isEmpty) return [];
      final response = await _supabase
          .from('user_food_locations')
          .select()
          .inFilter('id', locationIds);
      return (response as List)
          .map((json) => UserFoodLocationModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching user food locations by ids: $e');
      rethrow;
    }
  }

  Future<List<FoodCheckoutModel>> getFoodCheckoutsByDriverId(String driverId) async {
    try {
      final response = await _supabase
          .from('food_checkout')
          .select()
          .eq('driver_id', driverId)
          .order('created_at', ascending: false);
      return (response as List)
          .map((json) => FoodCheckoutModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching food checkouts by driver: $e');
      rethrow;
    }
  }

  /// Links a food order to its delivery ride / assigned driver (`food_ride`).
  Future<FoodRideModel?> getFoodRideByOrderId(Object orderId) async {
    try {
      final orderKey = orderId.toString().trim();
      if (orderKey.isEmpty) return null;

      final response = await _supabase
          .from('food_ride')
          .select()
          .eq('order_id', orderKey)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return FoodRideModel.fromJson(response);
    } catch (e) {
      print('Error fetching food_ride by order_id: $e');
      rethrow;
    }
  }

  Future<List<FoodRideModel>> getFoodRidesByOrderIds(List<String> orderIds) async {
    try {
      final keys = orderIds
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      if (keys.isEmpty) return [];

      final response = await _supabase
          .from('food_ride')
          .select()
          .inFilter('order_id', keys)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => FoodRideModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching food_rides by order ids: $e');
      rethrow;
    }
  }

  Future<List<CartItemModel>> getCartItemsByCartIds(List<int> cartIds) async {
    try {
      if (cartIds.isEmpty) return [];
      final response = await _supabase
          .from('cart_items')
          .select()
          .inFilter('cart_id', cartIds)
          .order('created_at', ascending: false);
      return (response as List)
          .map((json) => CartItemModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching cart items by cart ids: $e');
      rethrow;
    }
  }

  Future<List<RestaurantModel>> getRestaurants() async {
    try {
      final response = await _supabase
          .from('restaurants')
          .select()
          .order('name');

      return _withLiveRatings(
        (response as List).map((json) => RestaurantModel.fromJson(json)).toList(),
      );
    } catch (e) {
      print('Error fetching restaurants: $e');
      rethrow;
    }
  }

  /// Replaces the stored `restaurants.rate` with the live average of
  /// `restaurant_reviews` — exactly what the client app shows.
  Future<List<RestaurantModel>> _withLiveRatings(
    List<RestaurantModel> restaurants,
  ) async {
    if (restaurants.isEmpty) return restaurants;
    try {
      final rows = await _supabase
          .from('restaurant_reviews')
          .select('res_id, rate')
          .inFilter('res_id', restaurants.map((r) => r.id.toString()).toList());
      final sums = <int, num>{};
      final counts = <int, int>{};
      for (final row in rows as List) {
        final resId = int.tryParse(row['res_id']?.toString() ?? '');
        final rate = num.tryParse(row['rate']?.toString() ?? '');
        if (resId == null || rate == null) continue;
        sums[resId] = (sums[resId] ?? 0) + rate;
        counts[resId] = (counts[resId] ?? 0) + 1;
      }
      return restaurants.map((r) {
        final count = counts[r.id] ?? 0;
        if (count == 0) return r.copyWith(rateCount: 0);
        return r.copyWith(rate: sums[r.id]! / count, rateCount: count);
      }).toList();
    } catch (e) {
      print('Error loading restaurant ratings: $e');
      return restaurants;
    }
  }

  Future<RestaurantModel?> getRestaurantById(int id) async {
    try {
      final response =
          await _supabase
              .from('restaurants')
              .select()
              .eq('id', id)
              .maybeSingle();

      if (response == null) return null;
      return (await _withLiveRatings([RestaurantModel.fromJson(response)]))
          .first;
    } catch (e) {
      print('Error fetching restaurant by id: $e');
      rethrow;
    }
  }

  Future<void> addRestaurant(RestaurantModel restaurant) async {
    try {
      final data = restaurant.toJson();
      data.remove('id'); // ID is auto-generated
      data['rate'] = 0;
      await _supabase.from('restaurants').insert(data);
    } catch (e) {
      print('Error adding restaurant: $e');
      rethrow;
    }
  }

  Future<void> updateRestaurant(RestaurantModel restaurant) async {
    try {
      await _supabase
          .from('restaurants')
          .update(restaurant.toJson())
          .eq('id', restaurant.id);
    } catch (e) {
      print('Error updating restaurant: $e');
      rethrow;
    }
  }

  /// Menu sections order customers see (`restaurants.menu_category_order`).
  Future<void> updateRestaurantMenuCategoryOrder(
    int id,
    List<String> order,
  ) async {
    await _supabase
        .from('restaurants')
        .update({'menu_category_order': order})
        .eq('id', id);
  }

  Future<void> updateRestaurantAccepted(int id, bool isAccepted) async {
    try {
      await _supabase
          .from('restaurants')
          .update({'is_accepted': isAccepted})
          .eq('id', id);
    } catch (e) {
      print('Error updating restaurant is_accepted: $e');
      rethrow;
    }
  }

  Future<RestaurantModel?> loginRestaurant(
    String email,
    String password,
  ) async {
    try {
      final response =
          await _supabase
              .from('restaurants')
              .select()
              .eq('email', email)
              .eq('password', password)
              .maybeSingle();

      if (response == null) return null;
      return (await _withLiveRatings([RestaurantModel.fromJson(response)]))
          .first;
    } catch (e) {
      print('Error logging in restaurant: $e');
      rethrow;
    }
  }

  Future<AdminModel?> loginAdmin(String email, String password) async {
    try {
      final trimmed = email.trim();
      if (trimmed.isEmpty) return null;
      final response = await _supabase
          .from('admins')
          .select()
          .eq('email', trimmed)
          .eq('password', password)
          .maybeSingle();
      if (response == null) return null;
      return AdminModel.fromJson(response);
    } catch (e) {
      print('Error admin login: $e');
      rethrow;
    }
  }

  Future<List<AdminModel>> getAdmins() async {
    try {
      final response = await _supabase
          .from('admins')
          .select()
          .order('id', ascending: true);
      return (response as List)
          .map((json) => AdminModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching admins: $e');
      rethrow;
    }
  }

  Future<void> insertAdmin(AdminModel admin) async {
    try {
      await _supabase.from('admins').insert(admin.toInsertJson());
    } catch (e) {
      print('Error inserting admin: $e');
      rethrow;
    }
  }

  Future<void> updateAdmin(AdminModel admin) async {
    try {
      await _supabase
          .from('admins')
          .update(admin.toUpdateJson())
          .eq('id', admin.id);
    } catch (e) {
      print('Error updating admin: $e');
      rethrow;
    }
  }

  Future<void> deleteAdmin(int id) async {
    if (id == 1) {
      throw Exception('Cannot delete the super admin account.');
    }
    try {
      await _supabase.from('admins').delete().eq('id', id);
    } catch (e) {
      print('Error deleting admin: $e');
      rethrow;
    }
  }

  Future<List<CustomerSupportModel>> getCustomerSupportUsers() async {
    try {
      final response = await _supabase
          .from('customer_support')
          .select()
          .order('id', ascending: true);
      return (response as List)
          .map(
            (json) =>
                CustomerSupportModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      print('Error fetching customer support users: $e');
      rethrow;
    }
  }

  Future<void> insertCustomerSupport(CustomerSupportModel support) async {
    try {
      await _supabase.from('customer_support').insert(support.toInsertJson());
    } catch (e) {
      print('Error inserting customer support user: $e');
      rethrow;
    }
  }

  Future<void> updateCustomerSupport(CustomerSupportModel support) async {
    try {
      await _supabase
          .from('customer_support')
          .update(support.toUpdateJson())
          .eq('id', support.id);
    } catch (e) {
      print('Error updating customer support user: $e');
      rethrow;
    }
  }

  Future<void> deleteCustomerSupport(int id) async {
    try {
      await _supabase.from('customer_support').delete().eq('id', id);
    } catch (e) {
      print('Error deleting customer support user: $e');
      rethrow;
    }
  }

  Future<void> deleteRestaurant(int id) async {
    try {
      await _supabase.from('restaurants').delete().eq('id', id);
    } catch (e) {
      print('Error deleting restaurant: $e');
      rethrow;
    }
  }

  Future<List<FoodTableCouponModel>> getFoodTableCoupons() async {
    try {
      final response = await _supabase
          .from('food_table_coupons')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => FoodTableCouponModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching food table coupons: $e');
      rethrow;
    }
  }

  Future<FoodTableCouponModel> insertFoodTableCoupon({
    String? userId,
    String? userEmail,
    String? type,
    DateTime? validUntil,
    bool active = true,
    String? couponFor,
  }) async {
    try {
      final uid = userId != null && userId.trim().isNotEmpty ? userId.trim() : null;
      final email =
          userEmail != null && userEmail.trim().isNotEmpty ? userEmail.trim() : null;
      final t = type != null && type.trim().isNotEmpty ? type.trim() : null;
      final cf =
          couponFor != null && couponFor.trim().isNotEmpty ? couponFor.trim() : null;
      final data = <String, dynamic>{
        'user_id': uid,
        'user_email': email,
        'type': t,
        'valid_until': validUntil?.toIso8601String(),
        'active': active,
        'coupon_for': cf,
      };
      final response = await _supabase
          .from('food_table_coupons')
          .insert(data)
          .select()
          .single();
      return FoodTableCouponModel.fromJson(response);
    } catch (e) {
      print('Error inserting food table coupon: $e');
      rethrow;
    }
  }

  Future<void> updateFoodTableCoupon(FoodTableCouponModel coupon) async {
    try {
      final uid = coupon.userId != null && coupon.userId!.trim().isNotEmpty
          ? coupon.userId!.trim()
          : null;
      final email = coupon.userEmail != null && coupon.userEmail!.trim().isNotEmpty
          ? coupon.userEmail!.trim()
          : null;
      final t = coupon.type != null && coupon.type!.trim().isNotEmpty
          ? coupon.type!.trim()
          : null;
      final cf = coupon.couponFor != null && coupon.couponFor!.trim().isNotEmpty
          ? coupon.couponFor!.trim()
          : null;
      await _supabase
          .from('food_table_coupons')
          .update({
            'user_id': uid,
            'user_email': email,
            'type': t,
            'valid_until': coupon.validUntil?.toIso8601String(),
            'active': coupon.active,
            'coupon_for': cf,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', coupon.id);
    } catch (e) {
      print('Error updating food table coupon: $e');
      rethrow;
    }
  }

  Future<void> deleteFoodTableCoupon(String id) async {
    try {
      await _supabase.from('food_table_coupons').delete().eq('id', id);
    } catch (e) {
      print('Error deleting food table coupon: $e');
      rethrow;
    }
  }

  Future<List<PaymentModel>> getPayments() async {
    try {
      final response = await _supabase
          .from('payments')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => PaymentModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching payments: $e');
      rethrow;
    }
  }

  Future<List<RideAppCommissionModel>> getRideAppCommissions() async {
    try {
      final response = await _supabase
          .from('ride_app_commission_trans')
          .select()
          .order('date', ascending: false);

      return (response as List)
          .map(
            (json) =>
                RideAppCommissionModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      print('Error fetching ride_app_commission_trans: $e');
      rethrow;
    }
  }

  Future<List<FoodAppCommissionModel>> getFoodAppCommissions() async {
    try {
      final response = await _supabase
          .from('food_app_commission_trans')
          .select()
          .order('date', ascending: false);

      return (response as List)
          .map(
            (json) =>
                FoodAppCommissionModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      print('Error fetching food_app_commission_trans: $e');
      rethrow;
    }
  }

  /// Table name matches Supabase: `resturant_wallet`.
  Future<List<RestaurantWalletModel>> getRestaurantWalletByResId(
    int resId,
  ) async {
    try {
      final response = await _supabase
          .from('resturant_wallet')
          .select()
          .eq('res_id', resId)
          .order('date', ascending: false);

      return (response as List)
          .map(
            (json) =>
                RestaurantWalletModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      print('Error fetching restaurant wallet: $e');
      rethrow;
    }
  }

  Future<double> getRestaurantWalletBalance(int resId) async {
    try {
      final entries = await getRestaurantWalletByResId(resId);
      // Same as the restaurant app: sent = false and via_stripe = false.
      return entries
          .where((e) => e.countsInBalance)
          .fold<double>(0, (sum, e) => sum + e.amount);
    } catch (e) {
      print('Error calculating restaurant wallet balance: $e');
      rethrow;
    }
  }

  Future<Map<int, double>> getRestaurantWalletBalances(
    List<int> resIds,
  ) async {
    try {
      if (resIds.isEmpty) return {};
      final response = await _supabase
          .from('resturant_wallet')
          .select('res_id, amount, sent, via_stripe')
          .inFilter('res_id', resIds);

      final balances = <int, double>{};
      for (final row in (response as List)) {
        final map = row as Map<String, dynamic>;
        final id = map['res_id'] as int?;
        if (id == null) continue;
        if (map['sent'] == true || map['via_stripe'] == true) continue;
        final amount =
            num.tryParse(map['amount']?.toString() ?? '')?.toDouble() ?? 0;
        balances[id] = (balances[id] ?? 0) + amount;
      }
      return balances;
    } catch (e) {
      print('Error fetching restaurant wallet balances: $e');
      rethrow;
    }
  }

  Future<void> markRestaurantWalletSent(int walletId, {bool isSent = true}) async {
    try {
      await _supabase
          .from('resturant_wallet')
          .update({'sent': isSent, 'is_sent': isSent})
          .eq('id', walletId);
    } catch (e) {
      print('Error updating restaurant wallet sent: $e');
      rethrow;
    }
  }

  Future<void> markRestaurantWalletEntriesSent(List<int> walletIds) async {
    try {
      if (walletIds.isEmpty) return;
      await _supabase
          .from('resturant_wallet')
          .update({'sent': true, 'is_sent': true})
          .inFilter('id', walletIds);
    } catch (e) {
      print('Error bulk updating restaurant wallet sent: $e');
      rethrow;
    }
  }

  /// Payout methods for [partnerType] keyed by `partner_id`.
  Future<Map<String, PartnerPayoutMethodModel>> getPayoutMethods(
    String partnerType,
    List<String> partnerIds,
  ) async {
    try {
      if (partnerIds.isEmpty) return {};
      final response = await _supabase
          .from('partner_payout_methods')
          .select('id, partner_type, partner_id, title, description, updated_at')
          .eq('partner_type', partnerType)
          .inFilter('partner_id', partnerIds);
      final methods = <String, PartnerPayoutMethodModel>{};
      for (final row in (response as List)) {
        final method =
            PartnerPayoutMethodModel.fromJson(row as Map<String, dynamic>);
        methods[method.partnerId] = method;
      }
      return methods;
    } catch (e) {
      print('Error fetching partner payout methods: $e');
      rethrow;
    }
  }

  Future<PartnerPayoutMethodModel?> getPayoutMethod(
    String partnerType,
    String partnerId,
  ) async {
    final methods = await getPayoutMethods(partnerType, [partnerId]);
    return methods[partnerId];
  }

  Future<List<FoodDriverMoneyRequestModel>> getFoodDriverMoneyRequests() async {
    try {
      final response = await _supabase
          .from('food_driver_request_money')
          .select()
          .order('date', ascending: false);
      return (response as List)
          .map(
            (json) => FoodDriverMoneyRequestModel.fromJson(
              json as Map<String, dynamic>,
            ),
          )
          .toList();
    } catch (e) {
      print('Error fetching food driver money requests: $e');
      rethrow;
    }
  }

  Future<void> markFoodDriverMoneyRequestSent(String requestId) async {
    try {
      await _supabase
          .from('food_driver_request_money')
          .update({'sent': true})
          .eq('id', requestId);
    } catch (e) {
      print('Error updating food driver money request: $e');
      rethrow;
    }
  }

  Future<List<MenuModel>> getMenuByRestaurantId(int restaurantId) async {
    try {
      final response = await _supabase
          .from('menu')
          .select()
          .eq('restaurant_id', restaurantId)
          .order('name');

      return (response as List)
          .map((json) => MenuModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching menu items: $e');
      rethrow;
    }
  }

  Future<void> addMenuItem(MenuModel menu) async {
    try {
      final data = menu.toJson();
      data.remove('id'); // ID is auto-generated
      await _supabase.from('menu').insert(data);
    } catch (e) {
      print('Error adding menu item: $e');
      rethrow;
    }
  }

  Future<void> updateMenuItem(MenuModel menu) async {
    try {
      await _supabase.from('menu').update(menu.toJson()).eq('id', menu.id);
    } catch (e) {
      print('Error updating menu item: $e');
      rethrow;
    }
  }

  Future<void> deleteMenuItem(int id) async {
    try {
      await _supabase.from('menu').delete().eq('id', id);
    } catch (e) {
      print('Error deleting menu item: $e');
      rethrow;
    }
  }

  Future<List<CategoryModel>> getCategories() async {
    try {
      final response = await _supabase
          .from('food_categories')
          .select()
          .order('name');

      return (response as List)
          .map((json) => CategoryModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching categories: $e');
      rethrow;
    }
  }

  Future<CategoryModel> addCategory({
    required String name,
    String? image,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': name.trim(),
        'image': image != null && image.trim().isNotEmpty ? image.trim() : null,
      };
      final response = await _supabase
          .from('food_categories')
          .insert(data)
          .select()
          .single();
      return CategoryModel.fromJson(response);
    } catch (e) {
      print('Error adding category: $e');
      rethrow;
    }
  }

  Future<void> updateCategory(CategoryModel category) async {
    try {
      await _supabase.from('food_categories').update({
        'name': category.name,
        'image': category.image,
      }).eq('id', category.id);
    } catch (e) {
      print('Error updating category: $e');
      rethrow;
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      await _supabase.from('food_categories').delete().eq('id', id);
    } catch (e) {
      print('Error deleting category: $e');
      rethrow;
    }
  }

  Future<List<FoodComplainModel>> getFoodComplains() async {
    try {
      final response = await _supabase
          .from('food_complains')
          .select()
          .order('created_at', ascending: false);
      return (response as List)
          .map((json) => FoodComplainModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching food complains: $e');
      rethrow;
    }
  }

  Future<void> updateFoodComplainSolved(int id, {required bool isSolve}) async {
    try {
      await _supabase
          .from('food_complains')
          .update({'is_solve': isSolve})
          .eq('id', id);
    } catch (e) {
      print('Error updating food complain is_solve: $e');
      rethrow;
    }
  }

  Future<double?> getUserWalletTotal(String userId) async {
    try {
      final trimmed = userId.trim();
      if (trimmed.isEmpty) return null;
      final response = await _supabase
          .from('wallet')
          .select()
          .eq('user_id', trimmed)
          .maybeSingle();
      if (response == null) return null;
      return (response['total'] as num?)?.toDouble() ?? 0;
    } catch (e) {
      print('Error fetching user wallet: $e');
      rethrow;
    }
  }

  /// Adds [amount] to the user's wallet row (creates one if missing).
  Future<double> addAmountToUserWallet(String userId, double amount) async {
    try {
      final trimmed = userId.trim();
      if (trimmed.isEmpty) {
        throw Exception('User id is required');
      }
      if (amount <= 0) {
        throw Exception('Amount must be greater than 0');
      }

      final existing = await _supabase
          .from('wallet')
          .select()
          .eq('user_id', trimmed)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('wallet').insert({
          'user_id': trimmed,
          'total': amount,
        });
        return amount;
      }

      final current = (existing['total'] as num?)?.toDouble() ?? 0;
      final newTotal = current + amount;
      await _supabase
          .from('wallet')
          .update({'total': newTotal})
          .eq('id', existing['id']);
      return newTotal;
    } catch (e) {
      print('Error adding amount to user wallet: $e');
      rethrow;
    }
  }

  Future<StripeKeysModel?> getStripeKeys() async {
    try {
      final response = await _supabase.from('stripe').select().limit(1).maybeSingle();
      if (response == null) return null;
      return StripeKeysModel.fromJson(response);
    } catch (e) {
      print('Error fetching Stripe keys');
      rethrow;
    }
  }

  Future<StripeKeysModel> saveStripeKeys(StripeKeysModel keys) async {
    try {
      final payload = keys.toTableJson();
      Map<String, dynamic>? row;
      if (keys.id != null) {
        row = await _supabase
            .from('stripe')
            .update(payload)
            .eq('id', keys.id!)
            .select()
            .maybeSingle();
      } else {
        final existing = await _supabase.from('stripe').select('id').limit(1).maybeSingle();
        if (existing != null && existing['id'] != null) {
          row = await _supabase
              .from('stripe')
              .update(payload)
              .eq('id', existing['id'])
              .select()
              .maybeSingle();
        } else {
          row = await _supabase.from('stripe').insert(payload).select().maybeSingle();
        }
      }
      if (row == null) {
        return StripeKeysModel(
          id: keys.id,
          publishableKey: keys.publishableKey,
          secretKey: keys.secretKey,
        );
      }
      return StripeKeysModel.fromJson(row);
    } catch (e) {
      print('Error saving Stripe keys');
      rethrow;
    }
  }

  Future<DeliveryFeeModel?> getDeliveryFee() async {
    try {
      final response =
          await _supabase.from('delivery_fee').select().limit(1).maybeSingle();
      if (response == null) return null;
      return DeliveryFeeModel.fromJson(response);
    } catch (e) {
      print('Error fetching delivery fee');
      rethrow;
    }
  }

  Future<DeliveryFeeModel> saveDeliveryFee(DeliveryFeeModel fee) async {
    try {
      final payload = fee.toTableJson();
      Map<String, dynamic>? row;
      if (fee.id != null) {
        row = await _supabase
            .from('delivery_fee')
            .update(payload)
            .eq('id', fee.id!)
            .select()
            .maybeSingle();
      } else {
        final existing =
            await _supabase.from('delivery_fee').select('id').limit(1).maybeSingle();
        if (existing != null && existing['id'] != null) {
          row = await _supabase
              .from('delivery_fee')
              .update(payload)
              .eq('id', existing['id'])
              .select()
              .maybeSingle();
        } else {
          row = await _supabase
              .from('delivery_fee')
              .insert(payload)
              .select()
              .maybeSingle();
        }
      }
      if (row == null) return fee;
      return DeliveryFeeModel.fromJson(row);
    } catch (e) {
      print('Error saving delivery fee');
      rethrow;
    }
  }

  /// Saves an admin notification into each recipient's in-app inbox
  /// (`app_notifications`). [recipientType]: user | driver | restaurant.
  Future<void> saveInboxNotifications({
    required String recipientType,
    required List<String> recipientIds,
    required String title,
    required String body,
    String? batchId,
    String? sentBy,
    Map<String, dynamic>? data,
  }) async {
    final ids = recipientIds.where((id) => id.trim().isNotEmpty).toList();
    if (ids.isEmpty) return;
    final rows = [
      for (final id in ids)
        {
          'recipient_type': recipientType,
          'recipient_id': id,
          'title': title,
          'body': body,
          'data': {...?data, 'type': 'admin_message'},
          if (batchId != null) 'batch_id': batchId,
          if (sentBy != null) 'sent_by': sentBy,
        },
    ];
    const chunkSize = 500;
    for (var i = 0; i < rows.length; i += chunkSize) {
      final end = i + chunkSize > rows.length ? rows.length : i + chunkSize;
      await _supabase.from('app_notifications').insert(rows.sublist(i, end));
    }
  }
}
