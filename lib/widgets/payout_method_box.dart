import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/partner_payout_method_model.dart';

/// How the partner wants to be paid (from `partner_payout_methods`).
/// Shows a warning when the partner has not filled it in yet.
class PayoutMethodBox extends StatelessWidget {
  final PartnerPayoutMethodModel? method;

  const PayoutMethodBox({super.key, required this.method});

  @override
  Widget build(BuildContext context) {
    final m = method;
    final accent = m == null ? Colors.orangeAccent : Colors.lightBlueAccent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: m == null
          ? Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No payout method set by this partner yet.',
                    style: TextStyle(color: accent, fontSize: 13),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance_outlined,
                        color: accent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Payout method',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Copy details',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.copy_rounded, size: 18, color: accent),
                      onPressed: () => _copy(context, m),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SelectableText(
                  m.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  m.description,
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Last updated: ${m.formattedUpdatedAt}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
    );
  }

  Future<void> _copy(BuildContext context, PartnerPayoutMethodModel m) async {
    await Clipboard.setData(
      ClipboardData(text: '${m.title}\n${m.description}'),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payout details copied'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
