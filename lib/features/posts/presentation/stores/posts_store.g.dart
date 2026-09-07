// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'posts_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$PostsStore on _PostsStore, Store {
  late final _$postsAtom = Atom(name: '_PostsStore.posts', context: context);

  @override
  ObservableList<Post> get posts {
    _$postsAtom.reportRead();
    return super.posts;
  }

  @override
  set posts(ObservableList<Post> value) {
    _$postsAtom.reportWrite(value, super.posts, () {
      super.posts = value;
    });
  }

  late final _$isLoadingFeedAtom = Atom(
    name: '_PostsStore.isLoadingFeed',
    context: context,
  );

  @override
  bool get isLoadingFeed {
    _$isLoadingFeedAtom.reportRead();
    return super.isLoadingFeed;
  }

  @override
  set isLoadingFeed(bool value) {
    _$isLoadingFeedAtom.reportWrite(value, super.isLoadingFeed, () {
      super.isLoadingFeed = value;
    });
  }

  late final _$isLoadingMoreAtom = Atom(
    name: '_PostsStore.isLoadingMore',
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

  late final _$feedErrorAtom = Atom(
    name: '_PostsStore.feedError',
    context: context,
  );

  @override
  Failure? get feedError {
    _$feedErrorAtom.reportRead();
    return super.feedError;
  }

  @override
  set feedError(Failure? value) {
    _$feedErrorAtom.reportWrite(value, super.feedError, () {
      super.feedError = value;
    });
  }

  late final _$hasLoadedOnceAtom = Atom(
    name: '_PostsStore.hasLoadedOnce',
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

  late final _$currentPostAtom = Atom(
    name: '_PostsStore.currentPost',
    context: context,
  );

  @override
  Post? get currentPost {
    _$currentPostAtom.reportRead();
    return super.currentPost;
  }

  @override
  set currentPost(Post? value) {
    _$currentPostAtom.reportWrite(value, super.currentPost, () {
      super.currentPost = value;
    });
  }

  late final _$isLoadingCurrentPostAtom = Atom(
    name: '_PostsStore.isLoadingCurrentPost',
    context: context,
  );

  @override
  bool get isLoadingCurrentPost {
    _$isLoadingCurrentPostAtom.reportRead();
    return super.isLoadingCurrentPost;
  }

  @override
  set isLoadingCurrentPost(bool value) {
    _$isLoadingCurrentPostAtom.reportWrite(
      value,
      super.isLoadingCurrentPost,
      () {
        super.isLoadingCurrentPost = value;
      },
    );
  }

  late final _$currentPostErrorAtom = Atom(
    name: '_PostsStore.currentPostError',
    context: context,
  );

  @override
  Failure? get currentPostError {
    _$currentPostErrorAtom.reportRead();
    return super.currentPostError;
  }

  @override
  set currentPostError(Failure? value) {
    _$currentPostErrorAtom.reportWrite(value, super.currentPostError, () {
      super.currentPostError = value;
    });
  }

  late final _$deletingPostIdAtom = Atom(
    name: '_PostsStore.deletingPostId',
    context: context,
  );

  @override
  String? get deletingPostId {
    _$deletingPostIdAtom.reportRead();
    return super.deletingPostId;
  }

  @override
  set deletingPostId(String? value) {
    _$deletingPostIdAtom.reportWrite(value, super.deletingPostId, () {
      super.deletingPostId = value;
    });
  }

  late final _$deleteErrorAtom = Atom(
    name: '_PostsStore.deleteError',
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

  late final _$updatingPostIdAtom = Atom(
    name: '_PostsStore.updatingPostId',
    context: context,
  );

  @override
  String? get updatingPostId {
    _$updatingPostIdAtom.reportRead();
    return super.updatingPostId;
  }

  @override
  set updatingPostId(String? value) {
    _$updatingPostIdAtom.reportWrite(value, super.updatingPostId, () {
      super.updatingPostId = value;
    });
  }

  late final _$updateErrorAtom = Atom(
    name: '_PostsStore.updateError',
    context: context,
  );

  @override
  Failure? get updateError {
    _$updateErrorAtom.reportRead();
    return super.updateError;
  }

  @override
  set updateError(Failure? value) {
    _$updateErrorAtom.reportWrite(value, super.updateError, () {
      super.updateError = value;
    });
  }

  late final _$creatingPostAtom = Atom(
    name: '_PostsStore.creatingPost',
    context: context,
  );

  @override
  bool get creatingPost {
    _$creatingPostAtom.reportRead();
    return super.creatingPost;
  }

  @override
  set creatingPost(bool value) {
    _$creatingPostAtom.reportWrite(value, super.creatingPost, () {
      super.creatingPost = value;
    });
  }

  late final _$createErrorAtom = Atom(
    name: '_PostsStore.createError',
    context: context,
  );

  @override
  Failure? get createError {
    _$createErrorAtom.reportRead();
    return super.createError;
  }

  @override
  set createError(Failure? value) {
    _$createErrorAtom.reportWrite(value, super.createError, () {
      super.createError = value;
    });
  }

  late final _$loadPostsAsyncAction = AsyncAction(
    '_PostsStore.loadPosts',
    context: context,
  );

  @override
  Future<void> loadPosts() {
    return _$loadPostsAsyncAction.run(() => super.loadPosts());
  }

  late final _$loadMoreAsyncAction = AsyncAction(
    '_PostsStore.loadMore',
    context: context,
  );

  @override
  Future<void> loadMore() {
    return _$loadMoreAsyncAction.run(() => super.loadMore());
  }

  late final _$loadPostAsyncAction = AsyncAction(
    '_PostsStore.loadPost',
    context: context,
  );

  @override
  Future<void> loadPost(String id) {
    return _$loadPostAsyncAction.run(() => super.loadPost(id));
  }

  late final _$deletePostAsyncAction = AsyncAction(
    '_PostsStore.deletePost',
    context: context,
  );

  @override
  Future<void> deletePost(String id) {
    return _$deletePostAsyncAction.run(() => super.deletePost(id));
  }

  late final _$updatePostAsyncAction = AsyncAction(
    '_PostsStore.updatePost',
    context: context,
  );

  @override
  Future<void> updatePost(String id, {String? title, String? content}) {
    return _$updatePostAsyncAction.run(
      () => super.updatePost(id, title: title, content: content),
    );
  }

  late final _$createPostAsyncAction = AsyncAction(
    '_PostsStore.createPost',
    context: context,
  );

  @override
  Future<Either<Failure, Post>> createPost({
    required String title,
    required String content,
    File? image,
    required void Function(int, int) onSendProgress,
  }) {
    return _$createPostAsyncAction.run(
      () => super.createPost(
        title: title,
        content: content,
        image: image,
        onSendProgress: onSendProgress,
      ),
    );
  }

  @override
  String toString() {
    return '''
posts: ${posts},
isLoadingFeed: ${isLoadingFeed},
isLoadingMore: ${isLoadingMore},
feedError: ${feedError},
hasLoadedOnce: ${hasLoadedOnce},
currentPost: ${currentPost},
isLoadingCurrentPost: ${isLoadingCurrentPost},
currentPostError: ${currentPostError},
deletingPostId: ${deletingPostId},
deleteError: ${deleteError},
updatingPostId: ${updatingPostId},
updateError: ${updateError},
creatingPost: ${creatingPost},
createError: ${createError}
    ''';
  }
}
