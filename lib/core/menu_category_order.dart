/// Menu sections in the restaurant's saved order
/// (`restaurants.menu_category_order`); the rest alphabetically.
/// Matching is case-insensitive; empty names are skipped.
List<String> orderMenuCategories(
  Iterable<String> present,
  List<String> savedOrder,
) {
  final byKey = <String, String>{};
  for (final c in present) {
    final t = c.trim();
    if (t.isEmpty) continue;
    byKey.putIfAbsent(t.toLowerCase(), () => t);
  }
  final ordered = <String>[];
  for (final s in savedOrder) {
    final match = byKey.remove(s.trim().toLowerCase());
    if (match != null) ordered.add(match);
  }
  final rest = byKey.values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return [...ordered, ...rest];
}

List<String> parseMenuCategoryOrder(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .map((e) => e?.toString().trim() ?? '')
      .where((e) => e.isNotEmpty)
      .toList();
}

String menuCategoryKey(String category) => category.trim().toLowerCase();
