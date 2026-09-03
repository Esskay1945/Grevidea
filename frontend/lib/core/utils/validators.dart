enum PasswordStrength {
  none,
  easy,
  medium,
  difficult,
}

class Validators {
  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required';
    }
    if (!_emailRegExp.hasMatch(value.trim())) {
      return 'Enter a valid email address (e.g. name@domain.com)';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  static PasswordStrength calculatePasswordStrength(String password) {
    if (password.isEmpty) return PasswordStrength.none;
    if (password.length < 8) return PasswordStrength.easy;

    final hasLetters = password.contains(RegExp(r'[a-zA-Z]'));
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasDigits = password.contains(RegExp(r'[0-9]'));
    final hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    if (hasUppercase && hasLowercase && hasDigits && hasSpecial) {
      return PasswordStrength.difficult;
    }

    if (hasLetters && hasDigits) {
      return PasswordStrength.medium;
    }

    return PasswordStrength.easy;
  }
}
