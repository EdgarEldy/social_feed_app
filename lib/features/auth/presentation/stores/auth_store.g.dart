// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$AuthStore on _AuthStore, Store {
  Computed<bool>? _$isAuthenticatedComputed;

  @override
  bool get isAuthenticated => (_$isAuthenticatedComputed ??= Computed<bool>(
    () => super.isAuthenticated,
    name: '_AuthStore.isAuthenticated',
  )).value;

  late final _$currentUserAtom = Atom(
    name: '_AuthStore.currentUser',
    context: context,
  );

  @override
  User? get currentUser {
    _$currentUserAtom.reportRead();
    return super.currentUser;
  }

  @override
  set currentUser(User? value) {
    _$currentUserAtom.reportWrite(value, super.currentUser, () {
      super.currentUser = value;
    });
  }

  late final _$hasStoredSessionAtom = Atom(
    name: '_AuthStore.hasStoredSession',
    context: context,
  );

  @override
  bool get hasStoredSession {
    _$hasStoredSessionAtom.reportRead();
    return super.hasStoredSession;
  }

  @override
  set hasStoredSession(bool value) {
    _$hasStoredSessionAtom.reportWrite(value, super.hasStoredSession, () {
      super.hasStoredSession = value;
    });
  }

  late final _$isRestoringSessionAtom = Atom(
    name: '_AuthStore.isRestoringSession',
    context: context,
  );

  @override
  bool get isRestoringSession {
    _$isRestoringSessionAtom.reportRead();
    return super.isRestoringSession;
  }

  @override
  set isRestoringSession(bool value) {
    _$isRestoringSessionAtom.reportWrite(value, super.isRestoringSession, () {
      super.isRestoringSession = value;
    });
  }

  late final _$isSubmittingAtom = Atom(
    name: '_AuthStore.isSubmitting',
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

  late final _$lastErrorAtom = Atom(
    name: '_AuthStore.lastError',
    context: context,
  );

  @override
  Failure? get lastError {
    _$lastErrorAtom.reportRead();
    return super.lastError;
  }

  @override
  set lastError(Failure? value) {
    _$lastErrorAtom.reportWrite(value, super.lastError, () {
      super.lastError = value;
    });
  }

  late final _$restoreSessionAsyncAction = AsyncAction(
    '_AuthStore.restoreSession',
    context: context,
  );

  @override
  Future<void> restoreSession() {
    return _$restoreSessionAsyncAction.run(() => super.restoreSession());
  }

  late final _$signUpAsyncAction = AsyncAction(
    '_AuthStore.signUp',
    context: context,
  );

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _$signUpAsyncAction.run(
      () => super.signUp(
        email: email,
        password: password,
        displayName: displayName,
      ),
    );
  }

  late final _$signInAsyncAction = AsyncAction(
    '_AuthStore.signIn',
    context: context,
  );

  @override
  Future<void> signIn({required String email, required String password}) {
    return _$signInAsyncAction.run(
      () => super.signIn(email: email, password: password),
    );
  }

  late final _$signOutAsyncAction = AsyncAction(
    '_AuthStore.signOut',
    context: context,
  );

  @override
  Future<void> signOut() {
    return _$signOutAsyncAction.run(() => super.signOut());
  }

  late final _$_AuthStoreActionController = ActionController(
    name: '_AuthStore',
    context: context,
  );

  @override
  void forceSignOut() {
    final _$actionInfo = _$_AuthStoreActionController.startAction(
      name: '_AuthStore.forceSignOut',
    );
    try {
      return super.forceSignOut();
    } finally {
      _$_AuthStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void updateCurrentUser(User user) {
    final _$actionInfo = _$_AuthStoreActionController.startAction(
      name: '_AuthStore.updateCurrentUser',
    );
    try {
      return super.updateCurrentUser(user);
    } finally {
      _$_AuthStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _applyAuthResult(Either<Failure, User> result) {
    final _$actionInfo = _$_AuthStoreActionController.startAction(
      name: '_AuthStore._applyAuthResult',
    );
    try {
      return super._applyAuthResult(result);
    } finally {
      _$_AuthStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void _clearSession() {
    final _$actionInfo = _$_AuthStoreActionController.startAction(
      name: '_AuthStore._clearSession',
    );
    try {
      return super._clearSession();
    } finally {
      _$_AuthStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
currentUser: ${currentUser},
hasStoredSession: ${hasStoredSession},
isRestoringSession: ${isRestoringSession},
isSubmitting: ${isSubmitting},
lastError: ${lastError},
isAuthenticated: ${isAuthenticated}
    ''';
  }
}
