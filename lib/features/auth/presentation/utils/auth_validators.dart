import 'package:flutter/widgets.dart';

import '../../../../core/l10n/app_localizations.dart';

/// Field-level validation rules shared by `LoginPage` and `RegisterPage`.
///
/// Kept as a set of static functions, rather than duplicated inline
/// `validator:` closures on each `TextFormField`, so both forms apply
/// exactly the same rule to the same field and a future change (a stricter
/// email regex, a longer minimum password) only needs to happen once.
///
/// Each function takes [BuildContext] as its first parameter purely to
/// resolve [AppLocalizations] for the returned error string; none of them
/// read anything else off it, so a caller wires them up as
/// `validator: (value) => AuthValidators.validateEmail(context, value)`
/// rather than a bare tear-off.
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
  static String? validateEmail(BuildContext context, String? value) {
    final trimmed = value?.trim() ?? '';
    final l10n = AppLocalizations.of(context)!;
    if (trimmed.isEmpty) {
      return l10n.emailRequiredError;
    }
    if (!_emailPattern.hasMatch(trimmed)) {
      return l10n.emailInvalidError;
    }
    return null;
  }

  /// Validates a password field against [minPasswordLength].
  static String? validatePassword(BuildContext context, String? value) {
    final password = value ?? '';
    final l10n = AppLocalizations.of(context)!;
    if (password.isEmpty) {
      return l10n.passwordRequiredError;
    }
    if (password.length < minPasswordLength) {
      return l10n.passwordTooShortError(minPasswordLength);
    }
    return null;
  }

  /// Validates the display name field used only by `RegisterPage`.
  static String? validateDisplayName(BuildContext context, String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return AppLocalizations.of(context)!.displayNameRequiredError;
    }
    return null;
  }
}
