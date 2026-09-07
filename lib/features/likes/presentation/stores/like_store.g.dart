// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'like_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$LikeStore on _LikeStore, Store {
  late final _$isLikedAtom = Atom(name: '_LikeStore.isLiked', context: context);

  @override
  bool get isLiked {
    _$isLikedAtom.reportRead();
    return super.isLiked;
  }

  @override
  set isLiked(bool value) {
    _$isLikedAtom.reportWrite(value, super.isLiked, () {
      super.isLiked = value;
    });
  }

  late final _$likesCountAtom = Atom(
    name: '_LikeStore.likesCount',
    context: context,
  );

  @override
  int get likesCount {
    _$likesCountAtom.reportRead();
    return super.likesCount;
  }

  @override
  set likesCount(int value) {
    _$likesCountAtom.reportWrite(value, super.likesCount, () {
      super.likesCount = value;
    });
  }

  late final _$isTogglingAtom = Atom(
    name: '_LikeStore.isToggling',
    context: context,
  );

  @override
  bool get isToggling {
    _$isTogglingAtom.reportRead();
    return super.isToggling;
  }

  @override
  set isToggling(bool value) {
    _$isTogglingAtom.reportWrite(value, super.isToggling, () {
      super.isToggling = value;
    });
  }

  late final _$errorAtom = Atom(name: '_LikeStore.error', context: context);

  @override
  Failure? get error {
    _$errorAtom.reportRead();
    return super.error;
  }

  @override
  set error(Failure? value) {
    _$errorAtom.reportWrite(value, super.error, () {
      super.error = value;
    });
  }

  late final _$toggleAsyncAction = AsyncAction(
    '_LikeStore.toggle',
    context: context,
  );

  @override
  Future<void> toggle(String postId) {
    return _$toggleAsyncAction.run(() => super.toggle(postId));
  }

  late final _$_LikeStoreActionController = ActionController(
    name: '_LikeStore',
    context: context,
  );

  @override
  void clearError() {
    final _$actionInfo = _$_LikeStoreActionController.startAction(
      name: '_LikeStore.clearError',
    );
    try {
      return super.clearError();
    } finally {
      _$_LikeStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
isLiked: ${isLiked},
likesCount: ${likesCount},
isToggling: ${isToggling},
error: ${error}
    ''';
  }
}
