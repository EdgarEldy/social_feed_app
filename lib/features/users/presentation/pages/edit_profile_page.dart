import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_dimens.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/stores/auth_store.dart';
import '../../../auth/presentation/utils/auth_validators.dart';
import '../../domain/usecases/update_user_usecase.dart';
import '../../domain/usecases/upload_avatar_usecase.dart';
import '../widgets/avatar_picker.dart';

/// Lets the signed-in user edit their own display name and avatar.
///
/// Per the Screens table this page is "Owner only", and per this feature's
/// only self-profile source of truth, [AuthStore.currentUser], it always
/// operates on that rather than taking a `userId` parameter; there is no
/// `GET /users/me` in the API Contract, and no route-guard granularity finer
/// than "authenticated" to check ownership of an arbitrary id against
/// anyway. If [AuthStore.currentUser] is `null` (the same restored-session
/// gap [OwnProfilePage] documents), this shows the same kind of
/// explanatory state instead of crashing on a null field prefill.
///
/// Avatar changes take effect immediately on a successful upload (`POST
/// /users/me/avatar` already commits server-side the moment [AvatarPicker]
/// resolves), reflected straight into [AuthStore.currentUser] so the header
/// preview updates without waiting for "Save". Display name changes only
/// commit on "Save", via `PATCH /users/me`.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final AuthStore _authStore = getIt<AuthStore>();
  final UpdateUserUseCase _updateUserUseCase = getIt<UpdateUserUseCase>();
  final UploadAvatarUseCase _uploadAvatarUseCase = getIt<UploadAvatarUseCase>();
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();

  bool _prefilled = false;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  /// Sets the initial field values from [user] exactly once, so the
  /// controller is not stomped back to the server value on every rebuild
  /// while the user is mid-edit.
  void _prefillOnce(User user) {
    if (_prefilled) return;
    _displayNameController.text = user.displayName;
    _prefilled = true;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final result = await _updateUserUseCase(
      displayName: _displayNameController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    result.match((failure) => setState(() => _error = failure.message), (
      updatedUser,
    ) {
      _authStore.updateCurrentUser(updatedUser);
      if (mounted) context.pop();
    });
  }

  void _onAvatarUploaded(User currentUser, String photoUrl) {
    _authStore.updateCurrentUser(currentUser.copyWith(photoUrl: photoUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        final currentUser = _authStore.currentUser;
        if (currentUser == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Edit profile')),
            body: const ErrorView(
              message:
                  'Your profile has not loaded yet. Sign out and back in '
                  'to refresh it.',
            ),
          );
        }
        _prefillOnce(currentUser);
        return _EditProfileForm(
          formKey: _formKey,
          displayNameController: _displayNameController,
          currentUser: currentUser,
          isSubmitting: _isSubmitting,
          error: _error,
          uploadAvatarUseCase: _uploadAvatarUseCase,
          onAvatarUploaded: (photoUrl) =>
              _onAvatarUploaded(currentUser, photoUrl),
          onSubmit: _submit,
        );
      },
    );
  }
}

/// The scaffold and form body for [EditProfilePage], split out so the page
/// itself only orchestrates the null-handling/prefill logic above, keeping
/// both widgets well under the ~150 line guideline.
class _EditProfileForm extends StatelessWidget {
  const _EditProfileForm({
    required this.formKey,
    required this.displayNameController,
    required this.currentUser,
    required this.isSubmitting,
    required this.error,
    required this.uploadAvatarUseCase,
    required this.onAvatarUploaded,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController displayNameController;
  final User currentUser;
  final bool isSubmitting;
  final String? error;
  final UploadAvatarUseCase uploadAvatarUseCase;
  final ValueChanged<String> onAvatarUploaded;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.spacingLg),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: AvatarPicker(
                    uploadAvatarUseCase: uploadAvatarUseCase,
                    currentPhotoUrl: currentUser.photoUrl,
                    onUploaded: onAvatarUploaded,
                  ),
                ),
                const SizedBox(height: AppDimens.spacingLg),
                TextFormField(
                  controller: displayNameController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'Display name'),
                  validator: AuthValidators.validateDisplayName,
                  onFieldSubmitted: (_) => onSubmit(),
                ),
                if (error != null) ...[
                  const SizedBox(height: AppDimens.spacingSm),
                  Text(
                    error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: AppDimens.spacingLg),
                AppButton(
                  label: isSubmitting ? 'Saving...' : 'Save',
                  onPressed: isSubmitting ? null : onSubmit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
