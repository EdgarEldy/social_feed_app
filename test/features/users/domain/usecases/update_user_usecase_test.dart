import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:social_feed_app/core/errors/failure.dart';
import 'package:social_feed_app/features/auth/domain/entities/user.dart';
import 'package:social_feed_app/features/users/domain/repositories/user_repository.dart';
import 'package:social_feed_app/features/users/domain/usecases/update_user_usecase.dart';

class _MockUserRepository extends Mock implements UserRepository {}

void main() {
  late _MockUserRepository userRepository;
  late UpdateUserUseCase useCase;

  final user = User(
    id: 'user-1',
    displayName: 'New Name',
    email: 'ada@example.com',
    createdAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    userRepository = _MockUserRepository();
    useCase = UpdateUserUseCase(userRepository: userRepository);
  });

  group('UpdateUserUseCase', () {
    test('calls UserRepository.updateCurrentUser with the given displayName and returns the updated User', () async {
      when(
        () => userRepository.updateCurrentUser(displayName: 'New Name'),
      ).thenAnswer((_) async => Right(user));

      final result = await useCase.call(displayName: 'New Name');

      verify(() => userRepository.updateCurrentUser(displayName: 'New Name')).called(1);
      expect(result, Right<Failure, User>(user));
    });

    test('propagates a failure from the repository unchanged', () async {
      const failure = ServerFailure('Unexpected server error.', statusCode: 500);
      when(
        () => userRepository.updateCurrentUser(displayName: 'New Name'),
      ).thenAnswer((_) async => const Left(failure));

      final result = await useCase.call(displayName: 'New Name');

      verify(() => userRepository.updateCurrentUser(displayName: 'New Name')).called(1);
      expect(result, const Left<Failure, User>(failure));
    });

    test('forwards a null displayName unchanged as "no change"', () async {
      when(
        () => userRepository.updateCurrentUser(displayName: null),
      ).thenAnswer((_) async => Right(user));

      await useCase.call();

      verify(() => userRepository.updateCurrentUser(displayName: null)).called(1);
    });
  });
}
