class Validators {
  static String? requiredText(String? value, {String fieldName = 'Field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }
    return null;
  }

  static String? email(String? value) {
    final required = requiredText(value, fieldName: 'Email');
    if (required != null) {
      return required;
    }
    final normalized = value!.trim();
    final pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!pattern.hasMatch(normalized)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? password(String? value) {
    final required = requiredText(value, fieldName: 'Password');
    if (required != null) {
      return required;
    }
    if (value!.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value) ||
        !RegExp(r'[a-z]').hasMatch(value) ||
        !RegExp(r'[0-9]').hasMatch(value)) {
      return 'Use upper, lower, and numeric characters.';
    }
    return null;
  }

  static String? latitude(String? value) =>
      _coordinate(value, min: -90, max: 90, fieldName: 'Latitude');

  static String? longitude(String? value) =>
      _coordinate(value, min: -180, max: 180, fieldName: 'Longitude');

  static String? positiveNumber(String? value, {required String fieldName}) {
    final required = requiredText(value, fieldName: fieldName);
    if (required != null) {
      return required;
    }
    final parsed = double.tryParse(value!.trim());
    if (parsed == null || parsed <= 0) {
      return '$fieldName must be greater than 0.';
    }
    return null;
  }

  static String? _coordinate(
    String? value, {
    required double min,
    required double max,
    required String fieldName,
  }) {
    final required = requiredText(value, fieldName: fieldName);
    if (required != null) {
      return required;
    }
    final parsed = double.tryParse(value!.trim());
    if (parsed == null) {
      return '$fieldName must be a number.';
    }
    if (parsed < min || parsed > max) {
      return '$fieldName must be between $min and $max.';
    }
    return null;
  }
}
