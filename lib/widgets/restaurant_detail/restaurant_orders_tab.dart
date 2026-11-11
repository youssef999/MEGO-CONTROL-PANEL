import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/order_status.dart';
import '../../models/food_checkout_model.dart';

enum _OrderFilter { all, inProgress, delivered, cancelled }

/// This restaurant's orders; tap one to open the full order details.
class RestaurantOrdersTab extends StatefulWidget {
  final List<FoodCheckoutModel> orders;
  final ValueChanged<FoodCheckoutModel> onOpenOrder;

  const RestaurantOrdersTab({
    super.key,
    required this.orders,
    required this.onOpenOrder,
  });

  @override
  State<RestaurantOrdersTab> createState() => _RestaurantOrdersTabState();
}

class _RestaurantOrdersTabState extends State<RestaurantOrdersTab> {
  _OrderFilter _filter = _OrderFilter.all;

  static bool _matches(_OrderFilter filter, FoodCheckoutModel o) {
    switch (filter) {
      case _OrderFilter.all:
        return true;
      case _OrderFilter.inProgress:
        return !o.isCompleted && !o.isCancelled;
      case _OrderFilter.delivered:
        return o.isCompleted;
      case _OrderFilter.cancelled:
        return o.isCancelled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.orders.where((o) => _matches(_filter, o)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Wrap(
            spacing: 8,
            children: [
              _chip(_OrderFilter.all, 'All'),
              _chip(_OrderFilter.inProgress, 'In progress'),
              _chip(_OrderFilter.delivered, 'Delivered'),
              _chip(_OrderFilter.cancelled, 'Cancelled'),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Text(
                    'No orders',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              : ListView.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _OrderTile(
                    order: visible[i],
                    onTap: () => widget.onOpenOrder(visible[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _chip(_OrderFilter value, String label) {
    final count = widget.orders.where((o) => _matches(value, o)).length;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: Colors.deepPurpleAccent.withOpacity(0.35),
      backgroundColor: const Color(0xFF1A1D2D),
      labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final FoodCheckoutModel order;
  final VoidCallback onTap;

  const _OrderTile({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = orderStatusColor(order.status);
    return Material(
      color: const Color(0xFF1A1D2D),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  '#${order.id}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.userEmail ?? 'Unknown customer',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${order.formattedCreatedAt} · '
                      '${(order.paymentType ?? 'cash').toUpperCase()}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Text(
                  orderStatusLabel(order.status),
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 110,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatMoney(order.grandTotal),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Food ${formatMoney(order.foodAmount)}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey[600]),
            ],
          ),
        ),
      ),
    );
  }
}
