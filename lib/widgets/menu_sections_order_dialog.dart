import 'package:flutter/material.dart';

/// Drag & drop the restaurant's menu sections. Returns the new order, or null
/// when cancelled. [itemCounts] maps a section to its number of items.
Future<List<String>?> showMenuSectionsOrderDialog(
  BuildContext context, {
  required List<String> sections,
  required Map<String, int> itemCounts,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (_) =>
        _MenuSectionsOrderDialog(sections: sections, itemCounts: itemCounts),
  );
}

class _MenuSectionsOrderDialog extends StatefulWidget {
  final List<String> sections;
  final Map<String, int> itemCounts;

  const _MenuSectionsOrderDialog({
    required this.sections,
    required this.itemCounts,
  });

  @override
  State<_MenuSectionsOrderDialog> createState() =>
      _MenuSectionsOrderDialogState();
}

class _MenuSectionsOrderDialogState extends State<_MenuSectionsOrderDialog> {
  late final List<String> _order = List.of(widget.sections);

  void _move(int from, int to) {
    setState(() {
      final item = _order.removeAt(from);
      _order.insert(to, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1D2D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Row(
        children: [
          Icon(Icons.swap_vert_rounded, color: Colors.deepPurpleAccent),
          SizedBox(width: 10),
          Text(
            'Arrange menu sections',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Drag sections to choose which one customers see first in the app.',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: _order.length,
                onReorder: (oldIndex, newIndex) => _move(
                  oldIndex,
                  newIndex > oldIndex ? newIndex - 1 : newIndex,
                ),
                itemBuilder: (context, i) {
                  final section = _order[i];
                  final count = widget.itemCounts[section] ?? 0;
                  return Container(
                    key: ValueKey(section),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252A41),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: i == 0
                            ? Colors.deepPurpleAccent.withOpacity(0.6)
                            : Colors.white.withOpacity(0.06),
                      ),
                    ),
                    child: ListTile(
                      leading: ReorderableDragStartListener(
                        index: i,
                        child: const Icon(
                          Icons.drag_indicator_rounded,
                          color: Colors.grey,
                        ),
                      ),
                      title: Text(
                        '${i + 1}. $section',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        i == 0 ? '$count items · shown first' : '$count items',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Move up',
                            onPressed: i == 0 ? null : () => _move(i, i - 1),
                            icon: const Icon(Icons.keyboard_arrow_up_rounded),
                            color: Colors.white,
                          ),
                          IconButton(
                            tooltip: 'Move down',
                            onPressed: i == _order.length - 1
                                ? null
                                : () => _move(i, i + 1),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurpleAccent,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, _order),
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Save order'),
        ),
      ],
    );
  }
}
