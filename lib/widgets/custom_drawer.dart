import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/auth_storage.dart';
import '../screens/users_list_screen.dart';
import '../screens/drivers_list_screen.dart';
import '../screens/rides_list_screen.dart';
import '../screens/coupons_list_screen.dart';
import '../screens/ride_profits_list_screen.dart';
import '../screens/food_profits_list_screen.dart';
import '../screens/food_checkout_list_screen.dart';
import '../screens/restaurants_list_screen.dart';
import '../screens/food_categories_list_screen.dart';
import '../screens/food_table_coupons_screen.dart';
import '../screens/restaurant_admin_login_screen.dart';
import '../screens/notifications_list_screen.dart';
import '../screens/admins_list_screen.dart';
import '../screens/customer_support_list_screen.dart';
import '../screens/food_complains_list_screen.dart';
import '../screens/stripe_settings_screen.dart';
import '../screens/delivery_fee_screen.dart';
import '../screens/food_driver_payout_requests_screen.dart';

class CustomDrawer extends StatelessWidget {
  final String activeItem;

  const CustomDrawer({super.key, this.activeItem = 'Users'});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF1A1D2D),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildNavItem(
                  context,
                  icon: Icons.people_outline,
                  label: 'Users',
                  screen: const UsersListScreen(),
                  isActive: activeItem == 'Users',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.drive_eta_outlined,
                  label: 'Drivers',
                  screen: const DriversListScreen(),
                  isActive: activeItem == 'Drivers',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.local_taxi_outlined,
                  label: 'Rides',
                  screen: const RidesListScreen(),
                  isActive: activeItem == 'Rides',
                ),

                _buildNavItem(
                  context,
                  icon: Icons.confirmation_number_outlined,
                  label: 'Coupons',
                  screen: const CouponsListScreen(),
                  isActive: activeItem == 'Coupons',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.trending_up,
                  label: 'Mego Ride Profits',
                  screen: const RideProfitsListScreen(),
                  isActive: activeItem == 'Mego Ride Profits',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.restaurant_menu_outlined,
                  label: 'Mego Food Profits',
                  screen: const FoodProfitsListScreen(),
                  isActive: activeItem == 'Mego Food Profits',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.restaurant_outlined,
                  label: 'Restaurants',
                  screen: const RestaurantsListScreen(),
                  isActive: activeItem == 'Restaurants',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.category_outlined,
                  label: 'Food Categories',
                  screen: const FoodCategoriesListScreen(),
                  isActive: activeItem == 'Food Categories',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.table_chart_outlined,
                  label: 'Food Table Coupons',
                  screen: const FoodTableCouponsScreen(),
                  isActive: activeItem == 'Food Table Coupons',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.shopping_cart_checkout_outlined,
                  label: 'Food Checkout',
                  screen: const FoodCheckoutListScreen(),
                  isActive: activeItem == 'Food Checkout',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.request_quote_outlined,
                  label: 'Food Driver Payouts',
                  screen: const FoodDriverPayoutRequestsScreen(),
                  isActive: activeItem == 'Food Driver Payouts',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.report_problem_outlined,
                  label: 'Food Complaints',
                  screen: const FoodComplainsListScreen(),
                  isActive: activeItem == 'Food Complaints',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.notifications_none_outlined,
                  label: 'Notifications',
                  screen: const NotificationsListScreen(),
                  isActive: activeItem == 'Notifications',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.support_agent_outlined,
                  label: 'Customer Support',
                  screen: const CustomerSupportListScreen(),
                  isActive: activeItem == 'Customer Support',
                ),
                if (AuthStorage.isSuperAdmin)
                  _buildNavItem(
                    context,
                    icon: Icons.lock_outline,
                    label: 'Stripe',
                    screen: const StripeSettingsScreen(),
                    isActive: activeItem == 'Stripe',
                  ),
                _buildNavItem(
                  context,
                  icon: Icons.local_shipping_outlined,
                  label: 'Delivery Fee',
                  screen: const DeliveryFeeScreen(),
                  isActive: activeItem == 'Delivery Fee',
                ),
                if (AuthStorage.isSuperAdmin)
                  _buildNavItem(
                    context,
                    icon: Icons.manage_accounts_outlined,
                    label: 'Admins',
                    screen: const AdminsListScreen(),
                    isActive: activeItem == 'Admins',
                  ),
                // _buildNavItem(
                //   context,
                //   icon: Icons.admin_panel_settings_outlined,
                //   label: 'Restaurant Admin',
                //   screen: const RestaurantAdminLoginScreen(),
                //   isActive: activeItem == 'Restaurant Admin',
                // ),
              ],
            ),
          ),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.deepPurple,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SvgPicture.asset(
              'assets/logo.svg',
              height: 24,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
              placeholderBuilder:
                  (context) =>
                      const Icon(Icons.dashboard_outlined, color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'MEGO',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Widget screen,
    bool isActive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: () {
          Navigator.pop(context); // Close drawer
          if (!isActive) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => screen),
            );
          }
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(
          icon,
          color: isActive ? Colors.deepPurpleAccent : Colors.grey[400],
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[400],
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isActive,
        selectedTileColor: Colors.deepPurple.withOpacity(0.1),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey,
            child: Icon(Icons.person, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Admin User',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Text(
                AuthStorage.email ?? 'admin@mego.com',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () async {
              await AuthStorage.clear();
              if (!context.mounted) return;
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => const RestaurantAdminLoginScreen(),
                ),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout, size: 20, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
