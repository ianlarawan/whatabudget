import 'package:intl/intl.dart';

extension NumberFormatting on num {
  /// Formats a number with commas and 2 decimal places (e.g., 1,234.56)
  String toCurrency() {
    // The pattern '#,##0.00' ensures commas for thousands and strictly two decimal places.
    final formatter = NumberFormat('#,##0.00', 'en_US'); 
    return formatter.format(this);
  }

  /// Formats a number with commas but NO decimal places (e.g., 1,234)
  String toWholeNumber() {
    final formatter = NumberFormat('#,##0', 'en_US');
    return formatter.format(this);
  }
}