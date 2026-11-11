import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../models/restaurant_model.dart';
import '../../models/restaurant_order_stats_model.dart';
import '../firebase_storage_image.dart';
import '../restaurants/restaurant_status_badge.dart';

/// Restaurant identity + quick actions + order counters.
class RestaurantDetailHeader extends StatelessWidget {
  final RestaurantModel restaurant;
  final RestaurantOrderStatsModel stats;
  final int menuItemsCount;
  final VoidCallback onManageMenu;
  final VoidCallback onWallet;

  const RestaurantDetailHeader({
    super.key,
    required this.restaurant,
    required this.stats,
    required this.menuItemsCount,
    required this.onManageMenu,
    required this.onWallet,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D2D),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Wrap(
            spacing: 20,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [_identity(), _actions()],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, c) {
            final perRow = c.maxWidth >= 900 ? 5 : (c.maxWidth >= 560 ? 3 : 2);
            final width = (c.maxWidth - (perRow - 1) * 12) / perRow;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final s in _stats()) SizedBox(width: width, child: s),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _identity() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: FirebaseStorageImage(
            imageUrl: restaurant.image,
            width: 84,
            height: 84,
            fallbackIcon: Icons.restaurant,
            fallbackBackground: const Color(0xFF242838),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                restaurant.name ?? 'Unknown',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${restaurant.category ?? 'No category'} · ID ${restaurant.id}',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  RestaurantStatusBadge(accepted: restaurant.isAccepted),
                  _chip(
                    restaurant.active ? 'Open for orders' : 'Busy',
                    restaurant.active ? Colors.lightBlueAccent : Colors.amber,
                    restaurant.active ? Icons.storefront : Icons.timer_outlined,
                  ),
                  _chip(restaurant.rateLabel, Colors.amber, Icons.star_rounded),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: onManageMenu,
          icon: const Icon(Icons.restaurant_menu, size: 18),
          label: const Text('Manage menu'),
        ),
        OutlinedButton.icon(
          onPressed: onWallet,
          icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
          label: const Text('Wallet'),
        ),
      ],
    );
  }

  List<Widget> _stats() => [
    _StatTile(
      'Total orders',
      '${stats.total}',
      Icons.receipt_long,
      Colors.blueAccent,
    ),
    _StatTile(
      'In progress',
      '${stats.inProgress}',
      Icons.timelapse,
      Colors.orangeAccent,
    ),
    _StatTile(
      'Delivered',
      '${stats.delivered}',
      Icons.check_circle_outline,
      Colors.greenAccent,
    ),
    _StatTile(
      'Cancelled',
      '${stats.cancelled}',
      Icons.cancel_outlined,
      Colors.redAccent,
    ),
    _StatTile(
      'Food sales',
      formatMoney(stats.sales),
      Icons.payments_outlined,
      Colors.tealAccent,
      caption: '$menuItemsCount menu items',
    ),
  ];
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;

  const _StatTile(
    this.label,
    this.value,
    this.icon,
    this.color, {
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (caption != null)
                  Text(
                    caption!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 10.5),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
