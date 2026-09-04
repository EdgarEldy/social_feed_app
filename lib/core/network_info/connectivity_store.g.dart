// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connectivity_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ConnectivityStore on _ConnectivityStore, Store {
  late final _$isOnlineAtom = Atom(
    name: '_ConnectivityStore.isOnline',
    context: context,
  );

  @override
  bool get isOnline {
    _$isOnlineAtom.reportRead();
    return super.isOnline;
  }

  @override
  set isOnline(bool value) {
    _$isOnlineAtom.reportWrite(value, super.isOnline, () {
      super.isOnline = value;
    });
  }

  late final _$_ConnectivityStoreActionController = ActionController(
    name: '_ConnectivityStore',
    context: context,
  );

  @override
  void _updateStatus(List<ConnectivityResult> results) {
    final _$actionInfo = _$_ConnectivityStoreActionController.startAction(
      name: '_ConnectivityStore._updateStatus',
    );
    try {
      return super._updateStatus(results);
    } finally {
      _$_ConnectivityStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
isOnline: ${isOnline}
    ''';
  }
}
