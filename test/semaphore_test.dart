import 'dart:async';

import 'package:cancelation_token/cancelation_token.dart';
import 'package:synchronize/synchronize.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('$Semaphore', () {
    group('enter', () {
      test('initialCount = 2', () {
        final semaphore = Semaphore(2);
        expect(semaphore.currentCount, equals(2));
        expect(semaphore.enter(), isTrue);
        expect(semaphore.currentCount, equals(1));
        expect(semaphore.pendingCount, isZero);
        expect(semaphore.enter(), isTrue);
        expect(semaphore.currentCount, isZero);
        expect(semaphore.pendingCount, isZero);
        expect(semaphore.enter(), isA<Future<bool>>());
        expect(semaphore.currentCount, isZero);
        expect(semaphore.pendingCount, equals(1));
      });

      test('initialCount = 0', () {
        final semaphore = Semaphore(0);
        expect(semaphore.currentCount, isZero);
        expect(semaphore.enter(), isA<Future<bool>>());
        expect(semaphore.currentCount, isZero);
        expect(semaphore.pendingCount, equals(1));
      });

      test('initialCount = 0, signal after timeout', () async {
        final semaphore = Semaphore(0);
        expect(semaphore.currentCount, isZero);
        final enter = semaphore.enter(timeout: timeout);
        expect(enter, isA<Future<bool>>());
        expect(semaphore.currentCount, isZero);
        expect(semaphore.pendingCount, equals(1));

        final res = checkFuture(enter);

        // not enough time to complete
        await Future.delayed(smallDelay);
        expect(semaphore.currentCount, isZero);
        expect(semaphore.pendingCount, equals(1));
        expect(res.isReady, isFalse);
        expect(res.value, isNull);
        expect(res.error, isNull);

        // enter timeout
        while (!res.isReady) {
          await Future.delayed(smallDelay);
        }
        expect(semaphore.currentCount, isZero);
        expect(semaphore.pendingCount, isZero);
        expect(res.value, isNull);
        expect(res.error, isNotNull);
        expect(res.error, isA<TimeoutException>());

        // signal
        semaphore.signal(1);

        expect(semaphore.currentCount, equals(1));
        expect(semaphore.pendingCount, isZero);
        expect(res.value, isNull);
        expect(res.error, isNotNull);
        expect(res.error, isA<TimeoutException>());
      });

      test('initialCount = 0, signal before timeout', () async {
        final semaphore = Semaphore(0);
        expect(semaphore.currentCount, isZero);
        final enter = semaphore.enter(timeout: timeout);
        expect(enter, isA<Future<bool>>());
        expect(semaphore.currentCount, isZero);
        expect(semaphore.pendingCount, equals(1));

        final res = checkFuture(enter);

        // not enough time to complete
        await Future.delayed(smallDelay);
        expect(semaphore.currentCount, isZero);
        expect(semaphore.pendingCount, equals(1));
        expect(res.isReady, isFalse);
        expect(res.value, isNull);
        expect(res.error, isNull);

        // signal
        semaphore.signal(1);
        expect(semaphore.currentCount, isZero);
        expect(semaphore.pendingCount, isZero);

        // enter success
        while (!res.isReady) {
          await Future.delayed(smallDelay);
        }
        expect(res.value, isNotNull);
        expect(res.error, isNull);
        expect(res.value, isTrue);
      });

      test('initialCount = 0, with canceled token', () async {
        final semaphore = Semaphore(0);
        expect(semaphore.currentCount, isZero);
        expect(semaphore.pendingCount, isZero);
        final token = CancelableToken();
        token.cancel();
        expectLater(() => semaphore.enter(cancelationToken: token),
            throwsA(isA<CanceledException>()));
        expect(semaphore.currentCount, isZero);
        expect(semaphore.pendingCount, isZero);
      });

      test('initialCount = 0, signal before token is canceled', () async {
        final semaphore = Semaphore(0);
        expect(semaphore.currentCount, isZero);
        expect(semaphore.pendingCount, isZero);
        final token = CancelableToken();
        final enter = semaphore.enter(cancelationToken: token);
        expect(semaphore.currentCount, isZero);
        expect(semaphore.pendingCount, equals(1));

        final res = checkFuture(enter);
        expect(res.isReady, isFalse);
        expect(res.value, isNull);
        expect(res.error, isNull);

        semaphore.signal(1);
        expect(semaphore.currentCount, isZero);
        expect(semaphore.pendingCount, isZero);

        await Future.delayed(Duration.zero);
        expect(res.isReady, isTrue);
        expect(res.value, isTrue);
        expect(res.error, isNull);

        token.cancel();
      });

      test('initialCount = 0, signal after token is canceled', () async {
        final semaphore = Semaphore(0);
        expect(semaphore.currentCount, isZero);
        expect(semaphore.pendingCount, isZero);
        final token = CancelableToken();
        final enter = semaphore.enter(cancelationToken: token);
        expect(semaphore.currentCount, isZero);
        expect(semaphore.pendingCount, equals(1));

        final res = checkFuture(enter);
        expect(res.isReady, isFalse);
        expect(res.value, isNull);
        expect(res.error, isNull);

        token.cancel();
        expect(semaphore.currentCount, isZero);
        expect(semaphore.pendingCount, equals(1));

        await Future.delayed(Duration.zero);
        expect(semaphore.currentCount, isZero);
        expect(semaphore.pendingCount, isZero);

        expect(res.isReady, isTrue);
        expect(res.value, isNull);
        expect(res.error, isA<CanceledException>());

        semaphore.signal(1);
        expect(semaphore.currentCount, equals(1));
        expect(semaphore.pendingCount, isZero);
      });
    });

    group('tryEnter', () {
      test('+ signal', () {
        final semaphore = Semaphore(2, maxCount: 3);

        expect(semaphore.currentCount, equals(2));
        expect(semaphore.tryEnter(), isTrue);
        expect(semaphore.currentCount, equals(1));
        expect(semaphore.tryEnter(), isTrue);
        expect(semaphore.currentCount, isZero);
        expect(semaphore.tryEnter(), isFalse);
        expect(semaphore.currentCount, isZero);
      });
    });

    group('signal', () {
      test('negative value', () async {
        final semaphore = Semaphore(2, maxCount: 4);
        expect(semaphore.currentCount, equals(2));
        expect(semaphore.pendingCount, isZero);
        await expectLater(() => semaphore.signal(-1), throwsArgumentError);
        expect(semaphore.currentCount, equals(2));
        expect(semaphore.pendingCount, isZero);
      });

      test('initialCount = 0, no max count, signal(2)', () async {
        final semaphore = Semaphore(0);
        expect(semaphore.currentCount, isZero);
        expect(semaphore.pendingCount, isZero);
        semaphore.signal(2);
        expect(semaphore.currentCount, equals(2));
        expect(semaphore.pendingCount, isZero);
      });

      test('initialCount = 0, maxCount = 3, signal(2)', () {
        final semaphore = Semaphore(0, maxCount: 3);
        expect(semaphore.currentCount, isZero);
        expect(semaphore.pendingCount, isZero);
        semaphore.signal(2);
        expect(semaphore.currentCount, equals(2));
        expect(semaphore.pendingCount, isZero);
      });

      test('initialCount = 0, maxCount = 3, signal(3)', () {
        final semaphore = Semaphore(0, maxCount: 3);
        expect(semaphore.currentCount, isZero);
        expect(semaphore.pendingCount, isZero);
        semaphore.signal(3);
        expect(semaphore.currentCount, equals(3));
        expect(semaphore.pendingCount, isZero);
      });

      test('initialCount = 0, maxCount = 3, signal(4)', () async {
        final semaphore = Semaphore(0, maxCount: 3);
        expect(semaphore.currentCount, isZero);
        expect(semaphore.pendingCount, isZero);
        await expectLater(
            () => semaphore.signal(4), throwsA(isA<SemaphoreFullException>()));
        expect(semaphore.currentCount, isZero);
        expect(semaphore.pendingCount, isZero);
      });

      test('initialCount = 0, no max count, 2x enter()) + signal(2)', () async {
        final semaphore = Semaphore(0);
        expect(semaphore.currentCount, isZero);
        final future1 = semaphore.enter() as Future<bool>;
        final future2 = semaphore.enter() as Future<bool>;
        expect(semaphore.currentCount, isZero);
        expect(semaphore.pendingCount, equals(2));

        final res1 = checkFuture(future1);
        final res2 = checkFuture(future2);

        expect(res1.isReady, isFalse);
        expect(res2.isReady, isFalse);
        expect(semaphore.currentCount, isZero);
        expect(semaphore.pendingCount, equals(2));

        await Future.delayed(smallDelay);

        expect(res1.isReady, isFalse);
        expect(res2.isReady, isFalse);
        expect(semaphore.currentCount, isZero);
        expect(semaphore.pendingCount, equals(2));

        semaphore.signal(2);

        expect(res1.isReady, isFalse);
        expect(res2.isReady, isFalse);
        expect(semaphore.currentCount, isZero);
        expect(semaphore.pendingCount, isZero);

        await Future.delayed(smallDelay);

        expect(res1.isReady, isTrue);
        expect(res1.value, isTrue);
        expect(res1.error, isNull);
        expect(res2.isReady, isTrue);
        expect(res2.value, isTrue);
        expect(res2.error, isNull);
        expect(semaphore.currentCount, isZero);
        expect(semaphore.pendingCount, isZero);
      });
    });
  });
}
