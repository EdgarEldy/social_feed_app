import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:social_feed_app/core/network_info/connectivity_store.dart';

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late _MockConnectivity mockConnectivity;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    mockConnectivity = _MockConnectivity();
  });

  group('ConnectivityStore initial check', () {
    test('flips isOnline to false when the device starts out offline', () async {
      when(
        () => mockConnectivity.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.none]);
      when(
        () => mockConnectivity.onConnectivityChanged,
      ).thenAnswer((_) => const Stream.empty());

      final store = ConnectivityStore(connectivity: mockConnectivity);
      await pumpEventQueue();

      expect(store.isOnline, isFalse);

      store.dispose();
    });

    test('stays true when the device starts out online', () async {
      when(
        () => mockConnectivity.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.wifi]);
      when(
        () => mockConnectivity.onConnectivityChanged,
      ).thenAnswer((_) => const Stream.empty());

      final store = ConnectivityStore(connectivity: mockConnectivity);
      await pumpEventQueue();

      expect(store.isOnline, isTrue);

      store.dispose();
    });
  });

  group('ConnectivityStore onConnectivityChanged', () {
    test('updates isOnline when a later connectivity change event fires', () async {
      final controller = StreamController<List<ConnectivityResult>>();
      when(
        () => mockConnectivity.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.wifi]);
      when(
        () => mockConnectivity.onConnectivityChanged,
      ).thenAnswer((_) => controller.stream);

      final store = ConnectivityStore(connectivity: mockConnectivity);
      await pumpEventQueue();
      expect(store.isOnline, isTrue);

      controller.add([ConnectivityResult.none]);
      await pumpEventQueue();

      expect(store.isOnline, isFalse);

      store.dispose();
      await controller.close();
    });
  });

  group('ConnectivityStore constructor exception handling', () {
    test('still starts the onConnectivityChanged subscription when the initial checkConnectivity call throws', () async {
      final controller = StreamController<List<ConnectivityResult>>();
      when(
        () => mockConnectivity.checkConnectivity(),
      ).thenThrow(Exception('platform channel unavailable'));
      when(
        () => mockConnectivity.onConnectivityChanged,
      ).thenAnswer((_) => controller.stream);

      final store = ConnectivityStore(connectivity: mockConnectivity);
      await pumpEventQueue();
      // The initial check failed, so isOnline is left at its true default
      // rather than a guess; the subscription below is what corrects it.
      expect(store.isOnline, isTrue);

      controller.add([ConnectivityResult.none]);
      await pumpEventQueue();

      expect(store.isOnline, isFalse);

      store.dispose();
      await controller.close();
    });

    test('does not crash and leaves isOnline at the last known value when subscribing to onConnectivityChanged throws', () async {
      when(
        () => mockConnectivity.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.none]);
      when(
        () => mockConnectivity.onConnectivityChanged,
      ).thenThrow(Exception('platform channel unavailable'));

      final store = ConnectivityStore(connectivity: mockConnectivity);
      await pumpEventQueue();

      // The initial check still succeeded and set isOnline to false; the
      // failed subscribe attempt afterward should not revert or crash that.
      expect(store.isOnline, isFalse);

      store.dispose();
    });
  });
}
