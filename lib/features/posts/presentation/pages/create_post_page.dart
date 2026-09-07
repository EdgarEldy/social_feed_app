import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_dimens.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/post.dart';
import '../stores/posts_store.dart';
import '../utils/post_validators.dart';

/// Creates a new post, or edits an existing one, per the "reuse
/// `CreatePostPage` in an edit mode" decision documented on
/// `_PostAuthorMenu` in `post_card.dart`.
///
/// ## Create vs edit mode
///
/// [existingPost] is `null` for a brand new post (reached via `/posts/new`)
/// and non-null for an edit (`/posts/:id/edit`, see `app_router.dart`'s
/// `_EditPostRoute` for how that `Post` gets here). The two modes differ in
/// three ways, all driven off [_CreatePostPageState._isEditMode]:
/// - the title/content fields start empty vs pre-filled;
/// - only create mode shows the image picker; `PATCH /posts/:id` has no
///   `image` field in the API Contract, so there is nothing for an edit to
///   upload;
/// - both submit through `PostsStore` (`createPost` for a new post,
///   `updatePost` for an edit) rather than this page resolving
///   `CreatePostUseCase`/`UpdatePostUseCase` itself, so the feed list and
///   any already-open `PostDetailPage` reconcile with the result either way
///   (see those store methods' own docs for why they own the usecase call).
///
/// ## Where a successful create sends the user
///
/// `PostsStore.createPost` prepends the new post to the front of `posts`
/// (the feed is newest-first), so by the time this page navigates away the
/// feed has already caught up. Navigating to the new post's own detail page
/// (`context.pushReplacement('/posts/${post.id}')`) still shows the right
/// thing immediately, without waiting on a round trip back to the feed;
/// `pushReplacement` rather than `push` because there is no reason to leave
/// the now-submitted form on the stack behind the result. An edit, on the
/// other hand, edits a post the user is already looking at from the
/// feed/detail page, so `context.pop()` back to wherever they came from is
/// enough.
class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key, this.existingPost});

  /// The post being edited, or `null` when creating a new one.
  final Post? existingPost;

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final PostsStore _postsStore = getIt<PostsStore>();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  File? _pickedImage;
  bool _isSubmitting = false;
  double _uploadProgress = 0;
  String? _error;

  bool get _isEditMode => widget.existingPost != null;

  @override
  void initState() {
    super.initState();
    final existingPost = widget.existingPost;
    if (existingPost != null) {
      _titleController.text = existingPost.title;
      _contentController.text = existingPost.content;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await _showImageSourceSheet(context);
    if (source == null || !mounted) return;

    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _pickedImage = File(picked.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _uploadProgress = 0;
      _error = null;
    });

    if (_isEditMode) {
      await _submitEdit();
    } else {
      await _submitCreate();
    }
  }

  Future<void> _submitEdit() async {
    await _postsStore.updatePost(
      widget.existingPost!.id,
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    final failure = _postsStore.updateError;
    if (failure != null) {
      setState(() => _error = failure.message);
      return;
    }
    context.pop();
  }

  Future<void> _submitCreate() async {
    final result = await _postsStore.createPost(
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      image: _pickedImage,
      onSendProgress: (sent, total) {
        if (total <= 0 || !mounted) return;
        setState(() => _uploadProgress = sent / total);
      },
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    result.match(
      (failure) => setState(() => _error = failure.message),
      (post) => context.pushReplacement('/posts/${post.id}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _CreatePostForm(
      formKey: _formKey,
      titleController: _titleController,
      contentController: _contentController,
      isEditMode: _isEditMode,
      pickedImage: _pickedImage,
      onPickImage: _pickImage,
      isSubmitting: _isSubmitting,
      uploadProgress: _uploadProgress,
      error: _error,
      onSubmit: _submit,
    );
  }
}

/// The scaffold and form body for [CreatePostPage], split out so the state
/// class above stays focused on submission logic, keeping both widgets well
/// under the ~150 line guideline.
class _CreatePostForm extends StatelessWidget {
  const _CreatePostForm({
    required this.formKey,
    required this.titleController,
    required this.contentController,
    required this.isEditMode,
    required this.pickedImage,
    required this.onPickImage,
    required this.isSubmitting,
    required this.uploadProgress,
    required this.error,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final bool isEditMode;
  final File? pickedImage;
  final VoidCallback onPickImage;
  final bool isSubmitting;
  final double uploadProgress;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEditMode ? 'Edit post' : 'Create post')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.spacingLg),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: titleController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: PostValidators.validateTitle,
                ),
                const SizedBox(height: AppDimens.spacingMd),
                TextFormField(
                  controller: contentController,
                  minLines: 4,
                  maxLines: 8,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(labelText: 'Content'),
                  validator: PostValidators.validateContent,
                ),
                if (!isEditMode) ...[
                  const SizedBox(height: AppDimens.spacingLg),
                  _PostImagePickerField(
                    image: pickedImage,
                    onTap: onPickImage,
                  ),
                ],
                if (isSubmitting && !isEditMode) ...[
                  const SizedBox(height: AppDimens.spacingMd),
                  LinearProgressIndicator(
                    value: uploadProgress == 0 ? null : uploadProgress,
                    semanticsLabel: 'Post upload progress',
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: AppDimens.spacingSm),
                  Text(
                    error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: AppDimens.spacingLg),
                AppButton(
                  label: isSubmitting
                      ? (isEditMode ? 'Saving...' : 'Publishing...')
                      : (isEditMode ? 'Save' : 'Publish'),
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

/// The optional post image picker, shown only in create mode.
///
/// Tapping it opens [_showImageSourceSheet]'s camera/gallery choice, the
/// same bottom-sheet pattern `AvatarPicker` uses; duplicated in miniature
/// here rather than factored into a shared widget, since the preview shape
/// (a wide rectangle) and semantics differ enough from `AvatarPicker`'s
/// circular avatar that sharing would mean threading through more
/// configuration than it would save.
class _PostImagePickerField extends StatelessWidget {
  const _PostImagePickerField({required this.image, required this.onTap});

  final File? image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: image == null
          ? 'Add a photo to this post'
          : 'Change the post photo',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            image: image == null
                ? null
                : DecorationImage(image: FileImage(image!), fit: BoxFit.cover),
          ),
          child: image == null
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined),
                      SizedBox(height: AppDimens.spacingXs),
                      Text('Add a photo (optional)'),
                    ],
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// Shows a bottom sheet letting the user pick a camera photo or a gallery
/// image, resolving to the chosen [ImageSource], or `null` if dismissed.
///
/// Same pattern as `AvatarPicker`'s own `_showSourceSheet`; see
/// [_PostImagePickerField]'s doc for why it is duplicated rather than
/// shared.
Future<ImageSource?> _showImageSourceSheet(BuildContext context) {
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
