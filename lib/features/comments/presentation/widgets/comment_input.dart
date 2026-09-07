import 'package:flutter/material.dart';

import '../../../../app/theme/app_dimens.dart';

/// A text field plus a send button, used inside the `showModalBottomSheet`
/// `PostDetailPage` opens to add a comment.
///
/// Deliberately does not talk to `CommentsStore` (or any other store)
/// itself, taking [onSubmit] as a plain callback instead, the same
/// callback-based shape `AvatarPicker` uses for reporting its own upload
/// result back to its caller. That keeps this widget reusable and testable
/// without a `CommentsStore` instance in a widget test.
///
/// ## Success/failure signaling: `Future<bool>`, not an optimistic clear
///
/// [onSubmit] returns a `Future<bool>`: `true` once the caller's own submit
/// call (typically `CommentsStore.addComment`) actually succeeded, `false`
/// otherwise. This widget clears its text field only after a `true` result
/// rather than clearing the moment the user taps send. A failed submit
/// leaves the typed content in place so the user does not have to retype
/// it; error display itself stays the caller's responsibility
/// (`CommentsStore.submitError`, surfaced by whichever page opened this
/// widget), matching this widget's own single responsibility of rendering
/// the field and reporting what was typed, nothing about what happened to
/// it afterward.
class CommentInput extends StatefulWidget {
  const CommentInput({super.key, required this.onSubmit});

  /// Called with the trimmed, non-empty text the user typed. Returns
  /// whether the submission succeeded; the text field only clears on
  /// `true`.
  final Future<bool> Function(String content) onSubmit;

  @override
  State<CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<CommentInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // autofocus: true on the TextField below is not reliable inside a
    // showModalBottomSheet: the sheet's own entrance route transition can
    // still be running on the first frame, and a focus request issued
    // before that transition settles is sometimes dropped by the
    // framework. Requesting focus explicitly once the first frame has
    // actually rendered is the reliable version of the same intent.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _isSubmitting) {
      return;
    }
    setState(() => _isSubmitting = true);
    final succeeded = await widget.onSubmit(content);
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (succeeded) {
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            enabled: !_isSubmitting,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _handleSubmit(),
            decoration: const InputDecoration(
              hintText: 'Add a comment...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: AppDimens.spacingSm),
        _isSubmitting
            ? const Padding(
                padding: EdgeInsets.all(AppDimens.spacingSm),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                onPressed: _handleSubmit,
                icon: const Icon(Icons.send),
                tooltip: 'Send comment',
              ),
      ],
    );
  }
}
