import 'package:flutter/material.dart';

/// Asks the admin for a rejection / block reason. Returns the trimmed reason,
/// or null when cancelled.
Future<String?> showRejectReasonDialog(
  BuildContext context, {
  required String title,
  required String subjectName,
  required String confirmLabel,
  required String recipientLabel,
  List<String> presetReasons = const [],
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _RejectReasonDialog(
      title: title,
      subjectName: subjectName,
      confirmLabel: confirmLabel,
      recipientLabel: recipientLabel,
      presetReasons: presetReasons,
    ),
  );
}

class _RejectReasonDialog extends StatefulWidget {
  final String title;
  final String subjectName;
  final String confirmLabel;
  final String recipientLabel;
  final List<String> presetReasons;

  const _RejectReasonDialog({
    required this.title,
    required this.subjectName,
    required this.confirmLabel,
    required this.recipientLabel,
    required this.presetReasons,
  });

  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  static const _minLength = 5;

  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _usePreset(String reason) {
    final current = _controller.text.trim();
    final next = current.isEmpty ? reason : '$current\n$reason';
    _controller.text = next;
    _controller.selection = TextSelection.collapsed(offset: next.length);
    setState(() => _error = null);
  }

  void _submit() {
    final reason = _controller.text.trim();
    if (reason.length < _minLength) {
      setState(() => _error = 'Please write a clear reason (min $_minLength characters).');
      return;
    }
    Navigator.pop(context, reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1D2D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.gpp_bad_outlined,
              color: Colors.redAccent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subjectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.presetReasons.isNotEmpty) ...[
                Text(
                  'Quick reasons',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in widget.presetReasons)
                      ActionChip(
                        label: Text(r, style: const TextStyle(fontSize: 12)),
                        backgroundColor: const Color(0xFF252A3D),
                        side: BorderSide(color: Colors.white.withOpacity(0.08)),
                        labelStyle: TextStyle(color: Colors.grey[200]),
                        onPressed: () => _usePreset(r),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _controller,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                maxLength: 500,
                style: const TextStyle(color: Colors.white),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: InputDecoration(
                  labelText: 'Reason *',
                  alignLabelWithHint: true,
                  hintText: 'Explain why, and what they need to fix…',
                  errorText: _error,
                  filled: true,
                  fillColor: const Color(0xFF13151F),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.notifications_active_outlined,
                      color: Colors.blueAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'The reason will be sent to the ${widget.recipientLabel}\'s '
                        'notifications inbox in the app, plus a push notification.',
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          onPressed: _submit,
          icon: const Icon(Icons.send_rounded, size: 18),
          label: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
