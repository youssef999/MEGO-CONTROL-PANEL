/// Same currency format as the client and driver apps (`$12.50`).
const String appCurrency = '\$';

String formatMoney(num? value) =>
    '$appCurrency${(value ?? 0).toStringAsFixed(2)}';
