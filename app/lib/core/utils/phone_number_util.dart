import 'package:flutter/services.dart';

/// Centralized Indian mobile phone normalization, formatting and validation utility.
class PhoneNumberUtil {
  /// Strips any non-digit characters and removes country code (+91, 91) or leading zero (0)
  /// returning a clean 10-digit mobile number if valid, or the sanitized digits.
  static String cleanIndianPhone(String? val) {
    if (val == null) return '';
    String digits = val.replaceAll(RegExp(r'\D'), '').trim();
    if (digits.length == 12 && digits.startsWith('91')) {
      return digits.substring(2);
    }
    if (digits.length == 11 && digits.startsWith('0')) {
      return digits.substring(1);
    }
    return digits;
  }

  /// Format as standard E.164 phone number (+91XXXXXXXXXX)
  static String formatE164(String? val) {
    final clean = cleanIndianPhone(val);
    if (clean.length == 10) return '+91$clean';
    if (val != null && val.startsWith('+')) return val;
    return '+91$clean';
  }

  /// Validates whether the given string is a valid Indian 10-digit mobile number.
  /// Indian mobile numbers start with 6, 7, 8, or 9 and are 10 digits long.
  static String? validateIndianMobile(String? val, {bool isRequired = true}) {
    if (val == null || val.trim().isEmpty) {
      if (isRequired) return 'Mobile number is required';
      return null;
    }
    final clean = cleanIndianPhone(val);
    if (clean.length != 10) {
      return 'Please enter a valid 10-digit mobile number';
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(clean)) {
      return 'Please enter a valid 10-digit Indian mobile number';
    }
    return null;
  }

  /// Returns true if the string is a valid 10-digit Indian mobile number.
  static bool isValidIndianMobile(String? val) {
    if (val == null) return false;
    final clean = cleanIndianPhone(val);
    return clean.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(clean);
  }
}

/// TextInputFormatter that ensures phone input fields only contain digits,
/// strips pasted leading +91 / 91 / 0, and limits input to 10 digits.
class IndianPhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    String digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}
