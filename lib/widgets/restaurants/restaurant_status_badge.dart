import 'package:flutter/material.dart';

/// Activated / Needs activation badge (`restaurants.is_accepted`).
class RestaurantStatusBadge extends StatelessWidget {
  final bool accepted;
  final bool compact;

  const RestaurantStatusBadge({
    super.key,
    required this.accepted,
    this.compact = true,
  });

  static const activatedColor = Color(0xFF3DDC97);
  static const pendingColor = Color(0xFFFF8A65);

  @override
  Widget build(BuildContext context) {
    final color = accepted ? activatedColor : pendingColor;
    final title = accepted ? 'Activated' : 'Needs activation';
    final icon = accepted
        ? Icons.verified_rounded
        : Icons.hourglass_top_rounded;

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF0F111A).withOpacity(0.85),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              title,
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                accepted
                    ? 'Live & ready for orders'
                    : 'Blocked — activate to go live',
                style: TextStyle(color: Colors.grey[400], fontSize: 10.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
