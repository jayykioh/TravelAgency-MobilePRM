/// USD ↔ VND rate shared with the web app
/// (`Project/lib/utils/currency.ts` → `EXCHANGE_RATE_USD_VND`).
const double usdToVndRate = 25450;

/// Converts a USD amount into minor units ("cents", amount × 100, the unit
/// every `*_cents` column and [formatMoney] use) of [currency].
/// Returns null for a currency the app cannot convert.
int? usdToMinorUnits(double usd, String currency) {
  switch (currency.toUpperCase()) {
    case 'USD':
      return (usd * 100).round();
    case 'VND':
      return (usd * usdToVndRate * 100).round();
    default:
      return null;
  }
}

/// Converts minor units of [currency] into USD.
/// Returns null for a currency the app cannot convert.
double? minorUnitsToUsd(int cents, String currency) {
  switch (currency.toUpperCase()) {
    case 'USD':
      return cents / 100;
    case 'VND':
      return double.parse((cents / 100 / usdToVndRate).toStringAsFixed(2));
    default:
      return null;
  }
}
