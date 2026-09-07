// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comments_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$CommentsStore on _CommentsStore, Store {
  late final _$commentsAtom = Atom(
    name: '_CommentsStore.comments',
    context: context,
  );

  @override
  ObservableList<Comment> get comments {
    _$commentsAtom.reportRead();
    return super.comments;
  }

  @override
  set comments(ObservableList<Comment> value) {
    _$commentsAtom.reportWrite(value, super.comments, () {
      super.comments = value;
    });
  }

  late final _$isLoadingAtom = Atom(
    name: '_CommentsStore.isLoading',
    context: context,
  );

  @override
  bool get isLoading {
    _$isLoadingAtom.reportRead();
    return super.isLoading;
  }

  @override
  set isLoading(bool value) {
    _$isLoadingAtom.reportWrite(value, super.isLoading, () {
      super.isLoading = value;
    });
  }

  late final _$isLoadingMoreAtom = Atom(
    name: '_CommentsStore.isLoadingMore',
    context: context,
  );

  @override
  bool get isLoadingMore {
    _$isLoadingMoreAtom.reportRead();
    return super.isLoadingMore;
  }

  @override
  set isLoadingMore(bool value) {
    _$isLoadingMoreAtom.reportWrite(value, super.isLoadingMore, () {
      super.isLoadingMore = value;
    });
  }

  late final _$errorAtom = Atom(name: '_CommentsStore.error', context: context);

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

  late final _$hasLoadedOnceAtom = Atom(
    name: '_CommentsStore.hasLoadedOnce',
    context: context,
  );

  @override
  bool get hasLoadedOnce {
    _$hasLoadedOnceAtom.reportRead();
    return super.hasLoadedOnce;
  }

  @override
  set hasLoadedOnce(bool value) {
    _$hasLoadedOnceAtom.reportWrite(value, super.hasLoadedOnce, () {
      super.hasLoadedOnce = value;
    });
  }

  late final _$isSubmittingAtom = Atom(
    name: '_CommentsStore.isSubmitting',
    context: context,
  );

  @override
  bool get isSubmitting {
    _$isSubmittingAtom.reportRead();
    return super.isSubmitting;
  }

  @override
  set isSubmitting(bool value) {
    _$isSubmittingAtom.reportWrite(value, super.isSubmitting, () {
      super.isSubmitting = value;
    });
  }

  late final _$submitErrorAtom = Atom(
    name: '_CommentsStore.submitError',
    context: context,
  );

  @override
  Failure? get submitError {
    _$submitErrorAtom.reportRead();
    return super.submitError;
  }

  @override
  set submitError(Failure? value) {
    _$submitErrorAtom.reportWrite(value, super.submitError, () {
      super.submitError = value;
    });
  }

  late final _$deletingCommentIdAtom = Atom(
    name: '_CommentsStore.deletingCommentId',
    context: context,
  );

  @override
  String? get deletingCommentId {
    _$deletingCommentIdAtom.reportRead();
    return super.deletingCommentId;
  }

  @override
  set deletingCommentId(String? value) {
    _$deletingCommentIdAtom.reportWrite(value, super.deletingCommentId, () {
      super.deletingCommentId = value;
    });
  }

  late final _$deleteErrorAtom = Atom(
    name: '_CommentsStore.deleteError',
    context: context,
  );

  @override
  Failure? get deleteError {
    _$deleteErrorAtom.reportRead();
    return super.deleteError;
  }

  @override
  set deleteError(Failure? value) {
    _$deleteErrorAtom.reportWrite(value, super.deleteError, () {
      super.deleteError = value;
    });
  }

  late final _$loadCommentsAsyncAction = AsyncAction(
    '_CommentsStore.loadComments',
    context: context,
  );

  @override
  Future<void> loadComments(String postId) {
    return _$loadCommentsAsyncAction.run(() => super.loadComments(postId));
  }

  late final _$loadMoreAsyncAction = AsyncAction(
    '_CommentsStore.loadMore',
    context: context,
  );

  @override
  Future<void> loadMore(String postId) {
    return _$loadMoreAsyncAction.run(() => super.loadMore(postId));
  }

  late final _$addCommentAsyncAction = AsyncAction(
    '_CommentsStore.addComment',
    context: context,
  );

  @override
  Future<void> addComment(String postId, String content) {
    return _$addCommentAsyncAction.run(() => super.addComment(postId, content));
  }

  late final _$deleteCommentAsyncAction = AsyncAction(
    '_CommentsStore.deleteComment',
    context: context,
  );

  @override
  Future<void> deleteComment(String id, String postId) {
    return _$deleteCommentAsyncAction.run(
      () => super.deleteComment(id, postId),
    );
  }

  @override
  String toString() {
    return '''
comments: ${comments},
isLoading: ${isLoading},
isLoadingMore: ${isLoadingMore},
error: ${error},
hasLoadedOnce: ${hasLoadedOnce},
isSubmitting: ${isSubmitting},
submitError: ${submitError},
deletingCommentId: ${deletingCommentId},
deleteError: ${deleteError}
    ''';
  }
}
