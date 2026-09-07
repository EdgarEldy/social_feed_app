import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import '../../../../app/theme/app_dimens.dart';
import '../stores/like_store.dart';

/// How long the heart takes to scale up and back down when [LikeStore.isLiked]
/// flips, in either direction.
const Duration _heartScaleDuration = Duration(milliseconds: 180);

/// How long a rejected [LikeStore.toggle] call's discreet error message
/// stays visible before [LikeStore.clearError] removes it.
const Duration _errorMessageDuration = Duration(seconds: 2);

/// A tappable heart icon and like count, backed by one [LikeStore] instance.
///
/// The heart swap (outline <-> filled) is driven by an explicit
/// [AnimationController] feeding a [ScaleTransition], itself wrapped in an
/// [AnimatedSwitcher] so the outgoing and incoming icons cross-fade while
/// each also plays its own scale, rather than the outline snapping straight
/// to filled. [LikeStore.toggle] already applies the optimistic
/// isLiked/likesCount flip before this widget rebuilds, so all this widget
/// itself does on tap is call [LikeStore.toggle] and let the [Observer]
/// below react to whatever the store ends up holding.
///
/// [store] is constructed by the caller (one per [Post] on screen, see
/// [LikeStore]'s own class doc for why), not resolved from `get_it`.
class LikeButton extends StatefulWidget {
  const LikeButton({super.key, required this.store, required this.postId});

  /// The like state this button reads and mutates.
  final LikeStore store;

  /// The post this button's [store] belongs to, passed straight through to
  /// [LikeStore.toggle] on every tap.
  final String postId;

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController = AnimationController(
    vsync: this,
    duration: _heartScaleDuration,
    lowerBound: 0.6,
    upperBound: 1.0,
  )..value = 1.0;

  late final Animation<double> _scaleAnimation = CurvedAnimation(
    parent: _scaleController,
    curve: Curves.easeOutBack,
  );

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    _scaleController.forward(from: 0.6);
    await widget.store.toggle(widget.postId);
    if (!mounted) return;
    final error = widget.store.error;
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(error.message),
            duration: _errorMessageDuration,
          ),
        );
      widget.store.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Observer(
      builder: (_) {
        final isLiked = widget.store.isLiked;
        final likesCount = widget.store.likesCount;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label: isLiked
                  ? '$likesCount likes. Unlike post'
                  : '$likesCount likes. Like post',
              child: IconButton(
                onPressed: widget.store.isToggling ? null : _handleTap,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: AppDimens.spacingXxl,
                  minHeight: AppDimens.spacingXxl,
                ),
                icon: AnimatedSwitcher(
                  duration: _heartScaleDuration,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: _scaleAnimation,
                    child: child,
                  ),
                  child: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    key: ValueKey(isLiked),
                    color: isLiked ? theme.colorScheme.error : null,
                    size: AppDimens.spacingMd,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppDimens.spacingXs),
            ExcludeSemantics(
              child: Text('$likesCount', style: theme.textTheme.bodySmall),
            ),
          ],
        );
      },
    );
  }
}
