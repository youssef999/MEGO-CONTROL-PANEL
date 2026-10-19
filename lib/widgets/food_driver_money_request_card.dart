import 'package:flutter/material.dart';
import '../models/driver_model.dart';
import '../models/food_driver_money_request_model.dart';
import '../models/partner_payout_method_model.dart';
import 'payout_method_box.dart';

/// One food driver "Request money" row with the driver's payout method.
class FoodDriverMoneyRequestCard extends StatelessWidget {
  final FoodDriverMoneyRequestModel request;
  final DriverModel? driver;
  final PartnerPayoutMethodModel? payoutMethod;
  final bool busy;
  final VoidCallback onMarkPaid;

  const FoodDriverMoneyRequestCard({
    super.key,
    required this.request,
    required this.driver,
    required this.payoutMethod,
    required this.busy,
    required this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) {
    final paid = request.sent;
    final accent = paid ? Colors.grey : const Color(0xFF3DDC97);
    final contact = [driver?.phone, driver?.email]
        .where((v) => v != null && v.trim().isNotEmpty)
        .join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: paid
              ? Colors.white.withOpacity(0.04)
              : accent.withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver?.name?.trim().isNotEmpty == true
                          ? driver!.name!
                          : 'Driver ${request.driverId}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (contact.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      SelectableText(
                        contact,
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Requested: ${request.formattedDate}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    request.formattedValue,
                    style: TextStyle(
                      color: paid ? Colors.grey[400] : accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    paid ? 'Paid' : 'Pending payout',
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          PayoutMethodBox(method: payoutMethod),
          if (!paid) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: busy ? null : onMarkPaid,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.verified_outlined, size: 18),
                label: const Text(
                  'Mark as paid',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
