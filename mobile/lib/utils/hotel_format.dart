import 'package:intl/intl.dart';

/// Formats integer cents in [currency]. VND has no minor unit display.
String formatMoney(int cents, String currency) {
  final code = currency.toUpperCase();
  final amount = cents / 100;
  if (code == 'VND') {
    return '${NumberFormat.decimalPattern('vi').format(amount.round())} ₫';
  }
  return NumberFormat.simpleCurrency(
    name: code,
    decimalDigits: 2,
  ).format(amount);
}

String formatDay(DateTime value) => DateFormat('dd/MM/yyyy').format(value);

String hotelAddressText(dynamic value) {
  if (value is Map) {
    final text = [
      value['line1'],
      value['line2'],
      value['city'],
      value['country'],
    ].where((part) => part != null && '$part'.trim().isNotEmpty).join(', ');
    return text.isEmpty ? 'Việt Nam' : text;
  }
  final text = value == null ? '' : '$value'.trim();
  return text.isEmpty ? 'Việt Nam' : text;
}

/// Turns the `hotels.policies` jsonb into readable label/value pairs.
List<MapEntry<String, String>> policyEntries(dynamic value) {
  if (value is Map) {
    return value.entries
        .where((e) => e.value != null && '${e.value}'.trim().isNotEmpty)
        .map((e) {
          final raw = e.value;
          final text = raw is List
              ? raw.join(', ')
              : raw is Map
              ? raw.entries
                    .map((x) => '${_label(x.key)}: ${x.value}')
                    .join(' · ')
              : raw is bool
              ? (raw ? 'Có' : 'Không')
              : '$raw';
          return MapEntry(_label(e.key), text);
        })
        .toList();
  }
  if (value is String && value.trim().isNotEmpty) {
    return [MapEntry('Chính sách', value.trim())];
  }
  return const [];
}

String _label(dynamic key) {
  const known = {
    'check_in': 'Nhận phòng',
    'checkin': 'Nhận phòng',
    'check_in_time': 'Nhận phòng',
    'check_out': 'Trả phòng',
    'checkout': 'Trả phòng',
    'check_out_time': 'Trả phòng',
    'cancellation': 'Hủy phòng',
    'cancellation_policy': 'Hủy phòng',
    'pets': 'Thú cưng',
    'pets_allowed': 'Thú cưng',
    'smoking': 'Hút thuốc',
    'children': 'Trẻ em',
    'payment': 'Thanh toán',
  };
  final text = '$key';
  final hit = known[text.toLowerCase()];
  if (hit != null) return hit;
  final words = text.replaceAll('_', ' ').trim();
  return words.isEmpty ? text : words[0].toUpperCase() + words.substring(1);
}
