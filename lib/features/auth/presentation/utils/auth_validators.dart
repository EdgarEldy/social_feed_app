/// Field-level validation rules shared by `LoginPage` and `RegisterPage`.
///
/// Kept as a set of static functions, rather than duplicated inline
/// `validator:` closures on each `TextFormField`, so both forms apply
/// exactly the same rule to the same field and a future change (a stricter
/// email regex, a longer minimum password) only needs to happen once.
abstract final class AuthValidators {
  const AuthValidators._();

  /// A deliberately simple `local-part@domain` check.
  ///
  /// This is not meant to be a fully RFC 5322-compliant email parser (very
  /// few practical email validators are); its only job is to catch obvious
  /// typos client-side before a request round-trips to the server, which
  /// still does its own validation regardless.
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// The API Contract does not specify a minimum password length, so this
  /// picks a common, reasonable default (8 characters) rather than accepting
  /// any non-empty password.
  static const int minPasswordLength = 8;

  /// Validates an email field, returning an error string or `null` when
  /// [value] looks like a valid email address.
  static String? validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Email is required.';
    }
    if (!_emailPattern.hasMatch(trimmed)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  /// Validates a password field against [minPasswordLength].
  static String? validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Password is required.';
    }
    if (password.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters.';
    }
    return null;
  }

  /// Validates the display name field used only by `RegisterPage`.
  static String? validateDisplayName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Display name is required.';
    }
    return null;
  }
}
