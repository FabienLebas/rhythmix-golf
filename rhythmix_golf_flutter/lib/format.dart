import 'package:intl/intl.dart';

/// Nombre avec [digits] décimales et le séparateur de la langue
/// (« 0,81 » en français et en espagnol, « 0.81 » en anglais).
/// L'arrondi reste celui de [double.toStringAsFixed].
String fmtDecimal(double x, int digits, String locale) {
  final sep = NumberFormat.decimalPattern(locale).symbols.DECIMAL_SEP;
  return x.toStringAsFixed(digits).replaceAll('.', sep);
}

String fmt1(double x, String locale) => fmtDecimal(x, 1, locale);
String fmt2(double x, String locale) => fmtDecimal(x, 2, locale);
String fmt3(double x, String locale) => fmtDecimal(x, 3, locale);

/// Au centième près, sans zéros inutiles (« 60 », « 29,97 »).
String fmtTrim(double x, String locale) {
  final r = (x * 100).round() / 100;
  final sep = NumberFormat.decimalPattern(locale).symbols.DECIMAL_SEP;
  return (r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toString()).replaceAll('.', sep);
}

/// Jour et mois courts : « 14 mars » (fr), « Mar 14 » (en), « 14 mar » (es).
String fmtDay(DateTime d, String locale) => DateFormat.MMMd(locale).format(d);

/// Prix formaté dans la devise [currency] (code ISO) selon la langue.
String fmtMoney(double amount, String currency, String locale) =>
    NumberFormat.simpleCurrency(locale: locale, name: currency).format(amount);
