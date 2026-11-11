import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../models/restaurant_model.dart';
import '../../models/restaurant_order_stats_model.dart';
import '../firebase_storage_image.dart';
import 'restaurant_status_badge.dart';

enum RestaurantCardAction {
  details,
  menu,
  wallet,
  edit,
  toggle,
  reject,
  delete,
}

/// One restaurant in the Restaurants Management grid.
class RestaurantGridCard extends StatelessWidget {
  final RestaurantModel restaurant;
  final RestaurantOrderStatsModel stats;
  final ValueChanged<RestaurantCardAction> onAction;

  const RestaurantGridCard({
    super.key,
    required this.restaurant,
    required this.stats,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1D2D),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onAction(RestaurantCardAction.details),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 140, child: _cover()),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _cover() {
    return Stack(
      fit: StackFit.expand,
      children: [
        FirebaseStorageImage(
          imageUrl: restaurant.image,
          fit: BoxFit.cover,
          fallbackIcon: Icons.restaurant,
          fallbackBackground: const Color(0xFF242838),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0xCC0F111A)],
            ),
          ),
        ),
        Positioned(
          top: 10,
          left: 10,
          child: RestaurantStatusBadge(accepted: restaurant.isAccepted),
        ),
        Positioned(top: 2, right: 2, child: _menu()),
        Positioned(left: 12, bottom: 10, child: _rating()),
      ],
    );
  }

  Widget _rating() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
          const SizedBox(width: 3),
          Text(
            restaurant.rateLabel,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _menu() {
    final accepted = restaurant.isAccepted;
    PopupMenuItem<RestaurantCardAction> item(
      RestaurantCardAction value,
      IconData icon,
      String label,
      Color color,
    ) {
      return PopupMenuItem(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Text(label),
          ],
        ),
      );
    }

    return PopupMenuButton<RestaurantCardAction>(
      tooltip: 'Actions',
      color: const Color(0xFF242838),
      icon: const CircleAvatar(
        radius: 15,
        backgroundColor: Colors.black54,
        child: Icon(Icons.more_vert, color: Colors.white, size: 18),
      ),
      onSelected: onAction,
      itemBuilder: (_) => [
        item(
          RestaurantCardAction.details,
          Icons.open_in_new,
          'Details & orders',
          Colors.white,
        ),
        item(
          RestaurantCardAction.menu,
          Icons.restaurant_menu,
          'Manage menu',
          Colors.purpleAccent,
        ),
        item(
          RestaurantCardAction.wallet,
          Icons.account_balance_wallet_outlined,
          'Wallet',
          Colors.tealAccent,
        ),
        item(
          RestaurantCardAction.edit,
          Icons.edit_outlined,
          'Edit',
          Colors.blueAccent,
        ),
        item(
          RestaurantCardAction.toggle,
          accepted ? Icons.block : Icons.check_circle_outline,
          accepted ? 'Block (with reason)' : 'Activate',
          accepted ? Colors.redAccent : Colors.greenAccent,
        ),
        if (!accepted)
          item(
            RestaurantCardAction.reject,
            Icons.gpp_bad_outlined,
            'Reject with reason',
            Colors.orangeAccent,
          ),
        item(
          RestaurantCardAction.delete,
          Icons.delete_outline,
          'Delete',
          Colors.redAccent,
        ),
      ],
    );
  }

  Widget _body() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            restaurant.name ?? 'Unknown',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            [
              restaurant.category ?? 'No category',
              if (restaurant.locationName?.isNotEmpty == true)
                restaurant.locationName!,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const Spacer(),
          Row(
            children: [
              _stat('Orders', '${stats.total}', Colors.white),
              _stat('Active', '${stats.inProgress}', Colors.orangeAccent),
              _stat('Delivered', '${stats.delivered}', Colors.greenAccent),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.payments_outlined, size: 15, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text(
                'Sales ${formatMoney(stats.sales)}',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ],
      ),
    );
  }
}
