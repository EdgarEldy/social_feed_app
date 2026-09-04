import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_dimens.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/widgets/app_button.dart';
import '../stores/auth_store.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth_error_listener.dart';

/// Email/password sign up, with a link back to [LoginPage].
///
/// Same navigation contract as `LoginPage`: submitting only calls
/// `AuthStore.signUp`, and the `go_router` redirect guard moves an
/// authenticated user off `/register` on its own once
/// `AuthStore.isAuthenticated` flips to `true`.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthStore _authStore = getIt<AuthStore>();

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _authStore.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      displayName: _displayNameController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthErrorListener(
      authStore: _authStore,
      child: Scaffold(
        appBar: AppBar(title: const Text('Sign up')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimens.spacingLg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _displayNameController,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(labelText: 'Display name'),
                    validator: AuthValidators.validateDisplayName,
                  ),
                  const SizedBox(height: AppDimens.spacingMd),
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
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: AuthValidators.validatePassword,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: AppDimens.spacingLg),
                  Observer(
                    builder: (_) => AppButton(
                      label:
                          _authStore.isSubmitting ? 'Creating account...' : 'Sign up',
                      onPressed: _authStore.isSubmitting ? null : _submit,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spacingMd),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Already have an account? Log in'),
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
