import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_dimens.dart';
import '../../domain/usecases/upload_avatar_usecase.dart';

/// A tappable avatar that opens the camera/gallery picker, uploads the
/// chosen image via [uploadAvatarUseCase], and reports the resulting
/// `photoUrl` back through [onUploaded].
///
/// ## Why `StatefulWidget`/`setState` instead of a `Store`
///
/// Every other piece of async state in this app (`AuthStore`, `UserStore`,
/// and so on) lives in a MobX `Store`, per the project's "state management
/// is MobX only" rule. That rule is about state other widgets need to read
/// or react to; the upload progress/error tracked here is neither: it is
/// purely local, ephemeral display state that lives and dies with this one
/// widget, nobody outside it ever needs to read "is this avatar mid-upload"
/// or "what percent done is it". The one piece of state anything outside
/// this widget does care about, the resulting `photoUrl`, is handed off
/// immediately via [onUploaded] rather than stored here at all, which is
/// exactly why this widget takes a plain callback instead of depending on
/// `UserStore`/`AuthStore` directly, keeping it reusable anywhere a caller
/// wants an avatar-editing control.
///
/// [uploadAvatarUseCase] is taken as a constructor parameter, resolved by
/// the caller (typically `EditProfilePage`, acting as the composition root
/// for this widget) via `getIt<UploadAvatarUseCase>()`, rather than this
/// widget resolving it itself, so this widget stays testable without
/// `get_it`.
class AvatarPicker extends StatefulWidget {
  const AvatarPicker({
    super.key,
    required this.uploadAvatarUseCase,
    required this.onUploaded,
    this.currentPhotoUrl,
  });

  /// Performs the actual `POST /users/me/avatar` multipart upload.
  final UploadAvatarUseCase uploadAvatarUseCase;

  /// Called with the new `photoUrl` once the upload succeeds.
  final ValueChanged<String> onUploaded;

  /// The avatar currently shown before a new one is picked, if any.
  final String? currentPhotoUrl;

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploading = false;
  double _progress = 0;
  String? _error;

  Future<void> _pickAndUpload() async {
    final source = await _showSourceSheet(context);
    if (source == null || !mounted) return;

    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _isUploading = true;
      _progress = 0;
      _error = null;
    });

    final result = await widget.uploadAvatarUseCase(
      File(picked.path),
      onSendProgress: (sent, total) {
        if (total <= 0 || !mounted) return;
        setState(() => _progress = sent / total);
      },
    );

    if (!mounted) return;
    setState(() => _isUploading = false);
    result.match(
      (failure) => setState(() => _error = failure.message),
      (photoUrl) => widget.onUploaded(photoUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: 'Change avatar',
          child: GestureDetector(
            onTap: _isUploading ? null : _pickAndUpload,
            child: _AvatarPreview(
              photoUrl: widget.currentPhotoUrl,
              isUploading: _isUploading,
            ),
          ),
        ),
        if (_isUploading) ...[
          const SizedBox(height: AppDimens.spacingSm),
          SizedBox(
            width: AppDimens.spacingXxl * 2,
            child: LinearProgressIndicator(
              value: _progress,
              semanticsLabel: 'Avatar upload progress',
              semanticsValue: '${(_progress * 100).round()}%',
            ),
          ),
          Text('${(_progress * 100).round()}%'),
        ],
        if (_error != null) ...[
          const SizedBox(height: AppDimens.spacingSm),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// Shows a bottom sheet letting the user pick a camera photo or a gallery
/// image, resolving to the chosen [ImageSource], or `null` if dismissed.
Future<ImageSource?> _showSourceSheet(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      );
    },
  );
}

/// The circular avatar preview plus its edit-pencil badge and, while
/// [isUploading] is true, a spinner overlay.
class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({required this.photoUrl, required this.isUploading});

  final String? photoUrl;
  final bool isUploading;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        CircleAvatar(
          radius: AppDimens.spacingXxl,
          backgroundImage: photoUrl == null
              ? null
              : CachedNetworkImageProvider(photoUrl!),
          child: photoUrl == null
              ? Icon(Icons.person, size: AppDimens.spacingXxl)
              : null,
        ),
        if (isUploading)
          const CircularProgressIndicator(
            semanticsLabel: 'Uploading avatar',
          ),
        Positioned(
          bottom: 0,
          right: 0,
          child: CircleAvatar(
            radius: AppDimens.spacingMd,
            child: Icon(Icons.edit, size: AppDimens.spacingMd),
          ),
        ),
      ],
    );
  }
}
