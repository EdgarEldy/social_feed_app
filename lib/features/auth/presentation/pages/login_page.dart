import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_dimens.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/widgets/app_button.dart';
import '../stores/auth_store.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth_error_listener.dart';

/// Email/password sign in, with a link to [RegisterPage].
///
/// Submitting only calls `AuthStore.signIn`; it deliberately never navigates
/// itself. `go_router`'s redirect guard (`_authGuard` in `app_router.dart`)
/// already sends an authenticated user away from `/login`, and
/// `AuthRefreshListenable` makes that guard re-run the instant
/// `AuthStore.isAuthenticated` flips to `true`, so a manual
/// `context.go('/feed')` here would be redundant at best and racing the
/// guard at worst.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthStore _authStore = getIt<AuthStore>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _authStore.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthErrorListener(
      authStore: _authStore,
      child: Scaffold(
        appBar: AppBar(title: const Text('Log in')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimens.spacingLg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: AuthValidators.validateEmail,
                  ),
                  const SizedBox(height: AppDimens.spacingMd),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: AuthValidators.validatePassword,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: AppDimens.spacingLg),
                  Observer(
                    builder: (_) => AppButton(
                      label: _authStore.isSubmitting ? 'Signing in...' : 'Sign in',
                      onPressed: _authStore.isSubmitting ? null : _submit,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spacingMd),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: const Text("Don't have an account? Sign up"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
