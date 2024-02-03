import 'dart:async';

import 'package:cancelation_token/cancelation_token.dart';
import 'package:synchronize/synchronize.dart';
import 'package:test/test.dart';
import 'package:using/using.dart';

import 'utils.dart';

void main() {
  group('$Lock', () {
    final sharedResource = Object();

    group('acquire', () {
      test('+ release', () async {
        final lock = await Lock.acquire(sharedResource);
        try {
          expect(lock.isReleased, isFalse);
        } finally {
          lock.release();
        }
        expect(lock.isReleased, isTrue);
      });

      test('+ release twice', () async {
        final lock = await Lock.acquire(sharedResource);
        try {
          expect(lock.isReleased, isFalse);
        } finally {
          lock.release();
        }
        expect(lock.isReleased, isTrue);
        lock.release();
        expect(lock.isReleased, isTrue);
      });

      test('+ release after timeout', () async {
        final lock = Lock.acquire(sharedResource, timeout: timeout);
        final future = Lock.acquire(sharedResource, timeout: timeout);

        expect(lock, isA<Lock>());
        expect(future, isA<Future<Lock?>>());

        final res = checkFuture(future);

        // not enough time to complete
        await Future.delayed(smallDelay);
        expect(res.isReady, isFalse);
        expect(res.value, isNull);
        expect(res.error, isNull);

        // acquire timeout
        while (!res.isReady) {
          await Future.delayed(smallDelay);
        }
        expect(res.value, isNull);
        expect(res.error, isNotNull);
        expect(res.error, isA<TimeoutException>());

        (lock as Lock).release();

        expect(res.value, isNull);
        expect(res.error, isNotNull);
        expect(res.error, isA<TimeoutException>());
      });

      test('+ release before timeout', () async {
        final lock = Lock.acquire(sharedResource, timeout: timeout);
        final future = Lock.acquire(sharedResource, timeout: timeout);

        expect(lock, isA<Lock>());
        expect(future, isA<Future<Lock?>>());

        final res = checkFuture(future);

        // not enough time to complete
        await Future.delayed(smallDelay);
        expect(res.isReady, isFalse);
        expect(res.value, isNull);
        expect(res.error, isNull);

        // release
        (lock as Lock).release();

        // acquire success
        while (!res.isReady) {
          await Future.delayed(smallDelay);
        }
        expect(res.value, isNotNull);
        expect(res.error, isNull);
        expect(res.value, isA<Lock>());

        res.value!.release();
      });

      test('+ release after cancelation', () async {
        final token = CancelableToken();
        final lock = Lock.acquire(sharedResource, cancelationToken: token);
        final future = Lock.acquire(sharedResource, cancelationToken: token);

        expect(lock, isA<Lock>());
        expect(future, isA<Future<Lock?>>());

        final res = checkFuture(future);

        // not enough time to complete
        await Future.delayed(smallDelay);
        expect(res.isReady, isFalse);
        expect(res.value, isNull);
        expect(res.error, isNull);

        // cancel
        token.cancel();
        expect(res.isReady, isFalse);
        expect(res.value, isNull);
        expect(res.error, isNull);

        // acquire canceled
        while (!res.isReady) {
          await Future.delayed(smallDelay);
        }
        expect(res.value, isNull);
        expect(res.error, isA<CanceledException>());

        (lock as Lock).release();
      });

      test('+ release before cancelation', () async {
        final token = CancelableToken();
        final lock = Lock.acquire(sharedResource, cancelationToken: token);
        final future = Lock.acquire(sharedResource, cancelationToken: token);

        expect(lock, isA<Lock>());
        expect(future, isA<Future<Lock?>>());

        final res = checkFuture(future);

        // not enough time to complete
        await Future.delayed(smallDelay);
        expect(res.isReady, isFalse);
        expect(res.value, isNull);
        expect(res.error, isNull);

        // release
        (lock as Lock).release();

        // acquire success
        while (!res.isReady) {
          await Future.delayed(smallDelay);
        }
        expect(res.value, isA<Lock>());
        expect(res.error, isNull);

        // cancel has no effect
        token.cancel();

        res.value!.release();
      });

      test('+ use', () async {
        var count = 0;
        final lock = await Lock.acquire(sharedResource);
        expect(count, isZero);
        expect(lock.isReleased, isFalse);
        lock.use((l) => count++);
        expect(count, equals(1));
        expect(lock.isReleased, isTrue);
      });

      test('+ use error', () async {
        final lock = await Lock.acquire(sharedResource);
        expect(lock.isReleased, isFalse);
        await expectLater(() => lock.use((l) => throw TestException()),
            throwsA(isA<TestException>()));
        expect(lock.isReleased, isTrue);
      });

      test('+ runAsync', () async {
        var count = 0;
        final lock = await Lock.acquire(sharedResource);
        expect(count, isZero);
        expect(lock.isReleased, isFalse);
        await lock.runAsync(() async => count++);
        expect(count, equals(1));
        expect(lock.isReleased, isTrue);
      });

      test('+ runAsync error', () async {
        final lock = await Lock.acquire(sharedResource);
        expect(lock.isReleased, isFalse);
        await expectLater(() => lock.runAsync(() => throw TestException()),
            throwsA(isA<TestException>()));
        expect(lock.isReleased, isTrue);
      });
    });

    group('tryAcquire', () {
      test('+ release', () {
        final lock = Lock.tryAcquire(sharedResource);
        expect(lock, isNotNull);
        try {
          expect(lock!.isReleased, isFalse);
        } finally {
          lock!.release();
        }
        expect(lock.isReleased, isTrue);
      });

      test('+ release twice', () {
        final lock = Lock.tryAcquire(sharedResource);
        expect(lock, isNotNull);
        try {
          expect(lock!.isReleased, isFalse);
        } finally {
          lock!.release();
        }
        expect(lock.isReleased, isTrue);
        lock.release();
        expect(lock.isReleased, isTrue);
      });

      test('+ run', () {
        var count = 0;
        final lock = Lock.tryAcquire(sharedResource);
        expect(count, isZero);
        expect(lock, isNotNull);
        expect(lock!.isReleased, isFalse);
        lock.use((l) => count++);
        expect(count, equals(1));
        expect(lock.isReleased, isTrue);
      });

      test('+ run error', () async {
        final lock = Lock.tryAcquire(sharedResource);
        expect(lock, isNotNull);
        expect(lock!.isReleased, isFalse);
        await expectLater(() => lock.use((l) => throw TestException()),
            throwsA(isA<TestException>()));
        expect(lock.isReleased, isTrue);
      });

      test('+ runAsync', () async {
        var count = 0;
        final lock = Lock.tryAcquire(sharedResource);
        expect(count, isZero);
        expect(lock, isNotNull);
        expect(lock!.isReleased, isFalse);
        await lock.runAsync(() async => count++);
        expect(count, equals(1));
        expect(lock.isReleased, isTrue);
      });

      test('+ runAsync error', () async {
        final lock = Lock.tryAcquire(sharedResource);
        expect(lock, isNotNull);
        expect(lock!.isReleased, isFalse);
        await expectLater(() => lock.runAsync(() => throw TestException()),
            throwsA(isA<TestException>()));
        expect(lock.isReleased, isTrue);
      });
    });

    group('reentrancy', () {
      test('acquire + tryAcquire', () async {
        var reentered = false;
        await Lock.acquire(sharedResource).use((outerLock) {
          Lock.tryAcquire(sharedResource)?.use((innerLock) {
            expect(innerLock, equals(outerLock));
            reentered = true;
          });
        });
        expect(reentered, isTrue);
      });

      test('acquire + acquire', () async {
        var reentered = false;
        await Lock.acquire(sharedResource).useAsync((outerLock) async {
          await Lock.acquire(sharedResource).use((innerLock) {
            expect(innerLock, equals(outerLock));
            reentered = true;
          });
        });
        expect(reentered, isTrue);
      });

      test('tryAcquire + tryAcquire', () {
        var reentered = false;
        Lock.tryAcquire(sharedResource)?.use((outerLock) {
          Lock.tryAcquire(sharedResource)?.use((innerLock) {
            expect(innerLock, equals(outerLock));
            reentered = true;
          });
        });
        expect(reentered, isTrue);
      });

      test('tryAcquire + acquire', () async {
        var reentered = false;
        await Lock.tryAcquire(sharedResource)?.useAsync((outerLock) async {
          await Lock.acquire(sharedResource).use((innerLock) {
            expect(innerLock, equals(outerLock));
            reentered = true;
          });
        });
        expect(reentered, isTrue);
      });
    });

    group('concurrency', () {
      test('acquire', () async {
        var count = 0, totalDelay = 0;
        final futures = <Future>[];
        for (var i = 0; i < 10; i++) {
          futures.add(Future(() async {
            final lock = await Lock.acquire(sharedResource);
            await lock.runAsync(() async {
              expect(count, equals(i));
              count++;
              final delay = 70 - 5 * i;
              totalDelay += delay;
              await Future.delayed(Duration(milliseconds: delay));
            });
          }));
        }
        final sw = Stopwatch()..start();
        await Future.wait(futures);
        expect(totalDelay, equals(475));
        expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(totalDelay));
        expect(count, equals(10));
      });

      test('tryAcquire', () async {
        var count = 0, totalDelay = 0;
        final futures = <Future>[];
        for (var i = 0; i < 10; i++) {
          futures.add(Future(() async {
            await Lock.tryAcquire(sharedResource)?.runAsync(() async {
              expect(count, equals(i));
              count++;
              final delay = 70 - 5 * i;
              totalDelay += delay;
              await Future.delayed(Duration(milliseconds: delay));
            });
          }));
        }
        final sw = Stopwatch()..start();
        await Future.wait(futures);
        expect(totalDelay, equals(70));
        expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(totalDelay));
        expect(count, equals(1));
      });
    });
  });
}
