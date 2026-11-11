import 'package:flutter/material.dart';

import '../../core/menu_category_order.dart';
import '../../core/money.dart';
import '../../models/menu_model.dart';
import '../firebase_storage_image.dart';

/// Menu grouped by section (restaurant's saved order) with units sold per item.
class RestaurantMenuTab extends StatelessWidget {
  final List<MenuModel> items;
  final List<String> sectionOrder;

  /// Units ordered per item name (lower-case), from non-cancelled orders.
  final Map<String, int> soldByName;

  const RestaurantMenuTab({
    super.key,
    required this.items,
    required this.sectionOrder,
    required this.soldByName,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No menu items yet',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }
    final sections = orderMenuCategories(
      items.map((m) => m.itemCategory ?? ''),
      sectionOrder,
    );
    if (items.any((m) => (m.itemCategory ?? '').trim().isEmpty)) {
      sections.add('');
    }

    return CustomScrollView(
      slivers: [
        for (final section in sections) ...[
          SliverToBoxAdapter(child: _header(section)),
          SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              mainAxisExtent: 230,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _itemsIn(section).length,
            itemBuilder: (_, i) => _MenuItemCard(
              item: _itemsIn(section)[i],
              sold:
                  soldByName[(_itemsIn(section)[i].name ?? '')
                      .trim()
                      .toLowerCase()] ??
                  0,
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  List<MenuModel> _itemsIn(String section) => items
      .where(
        (m) =>
            menuCategoryKey(m.itemCategory ?? '') == menuCategoryKey(section),
      )
      .toList();

  Widget _header(String section) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
      child: Row(
        children: [
          Text(
            section.isEmpty ? 'Other' : section,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_itemsIn(section).length} items',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final MenuModel item;
  final int sold;

  const _MenuItemCard({required this.item, required this.sold});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                FirebaseStorageImage(
                  imageUrl: item.image,
                  fallbackIcon: Icons.fastfood_outlined,
                  fallbackBackground: const Color(0xFF242838),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      sold > 0 ? 'Sold ×$sold' : 'Not ordered yet',
                      style: TextStyle(
                        color: sold > 0 ? Colors.greenAccent : Colors.grey[300],
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name ?? 'Unnamed',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatMoney(item.price),
                  style: const TextStyle(
                    color: Colors.tealAccent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
