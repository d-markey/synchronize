import 'dart:async';

import 'package:synchronize/synchronize.dart';
import 'package:test/test.dart';
import 'package:using/using.dart';

import 'utils.dart';

void main() {
  group('$ReaderWriterLock', () {
    final sharedResource = Object();

    group('read', () {
      test('+ release', () async {
        final lock = await ReaderWriterLock.read(sharedResource);
        try {
          expect(lock.isReleased, isFalse);
          expect(lock.isReader, isTrue);
          expect(lock.isWriter, isFalse);
          expect(lock.isUpgraded, isFalse);
          final stats = lock.getStats();
          expect(stats.readers, equals(1));
          expect(stats.writers, isZero);
          expect(stats.upgraded, isZero);
        } finally {
          lock.release();
        }
        expect(lock.isReleased, isTrue);
      });

      test('+ release twice', () async {
        final lock = await ReaderWriterLock.read(sharedResource);
        try {
          expect(lock.isReleased, isFalse);
        } finally {
          lock.release();
        }
        expect(lock.isReleased, isTrue);
        lock.release();
        expect(lock.isReleased, isTrue);
      });

      test('with timeout', () async {
        final future1 = ReaderWriterLock.read(sharedResource, timeout: timeout);
        final future2 = ReaderWriterLock.read(sharedResource, timeout: timeout);

        final res1 = checkFuture(future1);
        final res2 = checkFuture(future2);

        try {
          expect(res1.isReady, isFalse);
          expect(res1.value, isNull);
          expect(res1.error, isNull);

          expect(res2.isReady, isFalse);
          expect(res2.value, isNull);
          expect(res2.error, isNull);

          await Future.delayed(Duration.zero);

          expect(res1.isReady, isTrue);
          expect(res1.value, isA<ReaderWriterLock>());
          expect(res1.error, isNull);

          expect(res2.isReady, isTrue);
          expect(res2.value, isA<ReaderWriterLock>());
          expect(res2.error, isNull);

          final stats1 = (res1.value as ReaderWriterLock).getStats();
          final stats2 = (res1.value as ReaderWriterLock).getStats();

          expect(stats1.readers, equals(2));
          expect(stats1.writers, isZero);
          expect(stats1.upgraded, isZero);

          expect(stats1.readers, equals(stats2.readers));
          expect(stats1.writers, equals(stats2.writers));
          expect(stats1.upgraded, equals(stats2.upgraded));
        } finally {
          res1.value?.release();
          res2.value?.release();
        }
      });

      test('+ use', () async {
        var count = 0;
        final lock = await ReaderWriterLock.read(sharedResource);

        expect(count, isZero);
        expect(lock.isReleased, isFalse);

        var stats = lock.getStats();
        expect(stats.readers, equals(1));
        expect(stats.writers, isZero);
        expect(stats.upgraded, isZero);

        lock.use((l) => count++);

        expect(count, equals(1));
        expect(lock.isReleased, isTrue);

        stats = lock.getStats();
        expect(stats.readers, isZero);
        expect(stats.writers, isZero);
        expect(stats.upgraded, isZero);
      });

      test('+ use error', () async {
        final lock = await ReaderWriterLock.read(sharedResource);
        expect(lock.isReleased, isFalse);

        var stats = lock.getStats();
        expect(stats.readers, equals(1));
        expect(stats.writers, isZero);
        expect(stats.upgraded, isZero);

        await expectLater(() => lock.use((l) => throw TestException()),
            throwsA(isA<TestException>()));
        expect(lock.isReleased, isTrue);

        stats = lock.getStats();
        expect(stats.readers, isZero);
        expect(stats.writers, isZero);
        expect(stats.upgraded, isZero);
      });

      test('+ runAsync', () async {
        var count = 0;
        final lock = await ReaderWriterLock.read(sharedResource);
        expect(count, isZero);
        expect(lock.isReleased, isFalse);

        var stats = lock.getStats();
        expect(stats.readers, equals(1));
        expect(stats.writers, isZero);
        expect(stats.upgraded, isZero);

        await lock.runAsync((l) async => count++);
        expect(count, equals(1));
        expect(lock.isReleased, isTrue);

        stats = lock.getStats();
        expect(stats.readers, isZero);
        expect(stats.writers, isZero);
        expect(stats.upgraded, isZero);
      });

      test('+ runAsync error', () async {
        final lock = await ReaderWriterLock.read(sharedResource);
        expect(lock.isReleased, isFalse);

        var stats = lock.getStats();
        expect(stats.readers, equals(1));
        expect(stats.writers, isZero);
        expect(stats.upgraded, isZero);

        await expectLater(() => lock.runAsync((l) => throw TestException()),
            throwsA(isA<TestException>()));
        expect(lock.isReleased, isTrue);

        stats = lock.getStats();
        expect(stats.readers, isZero);
        expect(stats.writers, isZero);
        expect(stats.upgraded, isZero);
      });
    });

    group('tryRead', () {
      test('+ release', () async {
        final lock = ReaderWriterLock.tryRead(sharedResource);
        try {
          expect(lock, isNotNull);
          expect(lock!.isReleased, isFalse);

          final stats = lock.getStats();
          expect(stats.readers, equals(1));
          expect(stats.writers, isZero);
          expect(stats.upgraded, isZero);
        } finally {
          lock?.release();
        }
        expect(lock.isReleased, isTrue);
      });

      test('+ release twice', () async {
        final lock = ReaderWriterLock.tryRead(sharedResource);
        try {
          expect(lock, isNotNull);
          expect(lock!.isReleased, isFalse);
        } finally {
          lock?.release();
        }
        expect(lock.isReleased, isTrue);
        lock.release();
        expect(lock.isReleased, isTrue);
      });

      test('+ use', () async {
        var count = 0;
        final lock = ReaderWriterLock.tryRead(sharedResource);
        expect(count, isZero);
        expect(lock, isNotNull);
        expect(lock!.isReleased, isFalse);
        lock.use((l) => count++);
        expect(count, equals(1));
        expect(lock.isReleased, isTrue);
      });

      test('+ use error', () async {
        final lock = ReaderWriterLock.tryRead(sharedResource);
        expect(lock, isNotNull);
        expect(lock!.isReleased, isFalse);
        await expectLater(() => lock.use((l) => throw TestException()),
            throwsA(isA<TestException>()));
        expect(lock.isReleased, isTrue);
      });

      test('+ runAsync', () async {
        var count = 0;
        final lock = ReaderWriterLock.tryRead(sharedResource);
        expect(count, isZero);
        expect(lock, isNotNull);
        expect(lock!.isReleased, isFalse);
        await lock.runAsync((l) async => count++);
        expect(count, equals(1));
        expect(lock.isReleased, isTrue);
      });

      test('+ runAsync error', () async {
        final lock = ReaderWriterLock.tryRead(sharedResource);
        expect(lock, isNotNull);
        expect(lock!.isReleased, isFalse);
        await expectLater(() => lock.runAsync((l) => throw TestException()),
            throwsA(isA<TestException>()));
        expect(lock.isReleased, isTrue);
      });
    });

    group('write', () {
      test('+ release', () async {
        final lock = await ReaderWriterLock.write(sharedResource);
        try {
          expect(lock.isReleased, isFalse);

          final stats = lock.getStats();
          expect(stats.readers, isZero);
          expect(stats.writers, equals(1));
          expect(stats.upgraded, isZero);
        } finally {
          lock.release();
        }
        expect(lock.isReleased, isTrue);
      });

      test('+ release twice', () async {
        final lock = await ReaderWriterLock.write(sharedResource);
        try {
          expect(lock.isReleased, isFalse);
        } finally {
          lock.release();
        }
        expect(lock.isReleased, isTrue);
        lock.release();
        expect(lock.isReleased, isTrue);
      });

      test('with release after timeout', () async {
        final future1 =
            ReaderWriterLock.write(sharedResource, timeout: timeout);
        final future2 =
            ReaderWriterLock.write(sharedResource, timeout: timeout);

        final res1 = checkFuture(future1);
        final res2 = checkFuture(future2);

        try {
          expect(res1.isReady, isFalse);
          expect(res1.value, isNull);
          expect(res1.error, isNull);

          expect(res2.isReady, isFalse);
          expect(res2.value, isNull);
          expect(res2.error, isNull);

          await Future.delayed(smallDelay);

          expect(res1.isReady, isTrue);
          expect(res1.value, isA<ReaderWriterLock>());
          expect(res1.error, isNull);

          expect(res2.isReady, isFalse);

          var stats = res1.value!.getStats();
          expect(stats.readers, isZero);
          expect(stats.writers, equals(2));
          expect(stats.upgraded, isZero);

          while (!res2.isReady) {
            await Future.delayed(smallDelay);
          }

          expect(res2.isReady, isTrue);
          expect(res2.value, isNull);
          expect(res2.error, isA<TimeoutException>());

          stats = res1.value!.getStats();
          expect(stats.readers, isZero);
          expect(stats.writers, equals(1));
          expect(stats.upgraded, isZero);
        } finally {
          res1.value?.release();
          res2.value?.release();
        }
      });

      test('with release before timeout', () async {
        final future1 =
            ReaderWriterLock.write(sharedResource, timeout: timeout);
        final future2 =
            ReaderWriterLock.write(sharedResource, timeout: timeout);

        final res1 = checkFuture(future1);
        final res2 = checkFuture(future2);

        try {
          expect(res1.isReady, isFalse);
          expect(res1.value, isNull);
          expect(res1.error, isNull);

          expect(res2.isReady, isFalse);
          expect(res2.value, isNull);
          expect(res2.error, isNull);

          await Future.delayed(smallDelay);

          expect(res1.isReady, isTrue);
          expect(res1.value, isA<ReaderWriterLock>());
          expect(res1.error, isNull);

          expect(res2.isReady, isFalse);

          var stats = res1.value!.getStats();
          expect(stats.readers, isZero);
          expect(stats.writers, equals(2));
          expect(stats.upgraded, isZero);

          res1.value?.release();

          while (!res2.isReady) {
            await Future.delayed(smallDelay);
          }

          expect(res2.isReady, isTrue);
          expect(res2.value, isA<ReaderWriterLock>());
          expect(res2.error, isNull);

          stats = res1.value!.getStats();
          expect(stats.readers, isZero);
          expect(stats.writers, equals(1));
          expect(stats.upgraded, isZero);
        } finally {
          res1.value?.release();
          res2.value?.release();
        }
      });

      test('+ use', () async {
        var count = 0;
        final lock = await ReaderWriterLock.write(sharedResource);
        expect(count, isZero);
        expect(lock.isReleased, isFalse);
        lock.use((l) => count++);
        expect(count, equals(1));
        expect(lock.isReleased, isTrue);
      });

      test('+ use error', () async {
        final lock = await ReaderWriterLock.write(sharedResource);
        expect(lock.isReleased, isFalse);
        await expectLater(() => lock.use((l) => throw TestException()),
            throwsA(isA<TestException>()));
        expect(lock.isReleased, isTrue);
      });

      test('+ runAsync', () async {
        var count = 0;
        final lock = await ReaderWriterLock.write(sharedResource);
        expect(count, isZero);
        expect(lock.isReleased, isFalse);
        await lock.runAsync((l) async => count++);
        expect(count, equals(1));
        expect(lock.isReleased, isTrue);
      });

      test('+ runAsync error', () async {
        final lock = await ReaderWriterLock.write(sharedResource);
        expect(lock.isReleased, isFalse);
        await expectLater(() => lock.runAsync((l) => throw TestException()),
            throwsA(isA<TestException>()));
        expect(lock.isReleased, isTrue);
      });
    });

    group('tryWrite', () {
      test('+ release', () async {
        final lock = ReaderWriterLock.tryWrite(sharedResource);
        try {
          expect(lock, isNotNull);
          expect(lock!.isReleased, isFalse);
        } finally {
          lock?.release();
        }
        expect(lock.isReleased, isTrue);
      });

      test('+ release twice', () async {
        final lock = ReaderWriterLock.tryWrite(sharedResource);
        try {
          expect(lock, isNotNull);
          expect(lock!.isReleased, isFalse);
        } finally {
          lock?.release();
        }
        expect(lock.isReleased, isTrue);
        lock.release();
        expect(lock.isReleased, isTrue);
      });

      test('with release after timeout', () async {
        final lock = ReaderWriterLock.tryWrite(sharedResource);
        final future = ReaderWriterLock.write(sharedResource, timeout: timeout);

        final res = checkFuture(future);

        try {
          expect(lock, isNotNull);
          expect(res.isReady, isFalse);
          expect(res.value, isNull);
          expect(res.error, isNull);

          await Future.delayed(smallDelay);

          expect(res.isReady, isFalse);

          while (!res.isReady) {
            await Future.delayed(smallDelay);
          }

          expect(res.isReady, isTrue);
          expect(res.value, isNull);
          expect(res.error, isA<TimeoutException>());
        } finally {
          lock?.release();
          res.value?.release();
        }
      });

      test('with release before timeout', () async {
        final lock = ReaderWriterLock.tryWrite(sharedResource);
        final future = ReaderWriterLock.write(sharedResource, timeout: timeout);

        final res = checkFuture(future);

        try {
          expect(lock, isNotNull);

          expect(res.isReady, isFalse);
          expect(res.value, isNull);
          expect(res.error, isNull);

          await Future.delayed(smallDelay);

          expect(res.isReady, isFalse);

          lock!.release();

          while (!res.isReady) {
            await Future.delayed(smallDelay);
          }

          expect(res.isReady, isTrue);
          expect(res.value, isA<ReaderWriterLock>());
          expect(res.error, isNull);
        } finally {
          lock?.release();
          res.value?.release();
        }
      });

      test('+ use', () async {
        var count = 0;
        final lock = ReaderWriterLock.tryWrite(sharedResource);
        expect(count, isZero);
        expect(lock, isNotNull);
        expect(lock!.isReleased, isFalse);
        lock.use((l) => count++);
        expect(count, equals(1));
        expect(lock.isReleased, isTrue);
      });

      test('+ use error', () async {
        final lock = ReaderWriterLock.tryWrite(sharedResource);
        expect(lock, isNotNull);
        expect(lock!.isReleased, isFalse);
        await expectLater(() => lock.use((l) => throw TestException()),
            throwsA(isA<TestException>()));
        expect(lock.isReleased, isTrue);
      });

      test('+ runAsync', () async {
        var count = 0;
        final lock = ReaderWriterLock.tryWrite(sharedResource);
        expect(count, isZero);
        expect(lock, isNotNull);
        expect(lock!.isReleased, isFalse);
        await lock.runAsync((l) async => count++);
        expect(count, equals(1));
        expect(lock.isReleased, isTrue);
      });

      test('+ runAsync error', () async {
        final lock = ReaderWriterLock.tryWrite(sharedResource);
        expect(lock, isNotNull);
        expect(lock!.isReleased, isFalse);
        await expectLater(() => lock.runAsync((l) => throw TestException()),
            throwsA(isA<TestException>()));
        expect(lock.isReleased, isTrue);
      });
    });

    group('upgrade', () {
      test('from single reader', () async {
        final lock = await ReaderWriterLock.read(sharedResource);
        try {
          var stats = lock.getStats();
          expect(stats.readers, equals(1));
          expect(stats.writers, isZero);
          expect(stats.upgraded, isZero);

          var upgraded = false;
          await lock.runAsync((reader) async {
            expect(reader, equals(lock));
            await reader.upgrade().use((upgradedReader) {
              expect(upgradedReader, isNot(equals(reader)));
              upgraded = true;

              stats = upgradedReader.getStats();
              expect(stats.readers, equals(1));
              expect(stats.writers, isZero);
              expect(stats.upgraded, equals(1));

              stats = reader.getStats();
              expect(stats.readers, equals(1));
              expect(stats.writers, isZero);
              expect(stats.upgraded, equals(1));
            });

            stats = reader.getStats();
            expect(stats.readers, equals(1));
            expect(stats.writers, isZero);
            expect(stats.upgraded, isZero);
          });
          expect(upgraded, isTrue);

          stats = lock.getStats();
          expect(stats.readers, isZero);
          expect(stats.writers, isZero);
          expect(stats.upgraded, isZero);
        } finally {
          lock.release();
        }
      });

      test('from single writer', () async {
        final lock = await ReaderWriterLock.write(sharedResource);
        try {
          var upgraded = false;
          await lock.runAsync((writer) async {
            expect(writer, equals(lock));
            await writer.upgrade().use((upgradedWriter) {
              expect(upgradedWriter, isNot(equals(writer)));
              upgraded = true;
            });
          });
          expect(upgraded, isTrue);
        } finally {
          lock.release();
        }
      });

      test('from first reader', () async {
        var step = 0;
        final futures = [
          ReaderWriterLock.read(sharedResource).useAsync((reader) async {
            expect(step, isZero);
            step = 1;
            await reader.upgrade().use((writer) {
              expect(step, equals(2));
              step = 3;
            });
          }),
          ReaderWriterLock.read(sharedResource).useAsync((reader) async {
            expect(step, equals(1));
            await Future.delayed(smallDelay);
            step = 2;
          })
        ];

        await Future.wait(futures);

        expect(step, equals(3));
      });

      test('from second reader', () async {
        var step = 0;
        final futures = [
          ReaderWriterLock.read(sharedResource).useAsync((reader) async {
            expect(step, isZero);
            await Future.delayed(smallDelay);
            expect(step, equals(2));
            step = 1;
          }),
          ReaderWriterLock.read(sharedResource).useAsync((reader) async {
            expect(step, isZero);
            step = 2;
            await reader.upgrade().use((writer) {
              expect(step, equals(1));
              step = 3;
            });
          })
        ];

        await Future.wait(futures);

        expect(step, equals(3));
      });
    });

    group('tryUpgrade', () {
      test('from single reader', () async {
        final lock = await ReaderWriterLock.read(sharedResource);
        try {
          var upgraded = false;
          await lock.runAsync((reader) async {
            expect(reader, equals(lock));
            reader.tryUpgrade()?.use((upgradedReader) {
              expect(upgradedReader, isNot(equals(reader)));
              upgraded = true;
            });
          });
          expect(upgraded, isTrue);
        } finally {
          lock.release();
        }
      });

      test('from single writer', () async {
        final lock = await ReaderWriterLock.write(sharedResource);
        try {
          var upgraded = false;
          await lock.runAsync((writer) async {
            expect(writer, equals(lock));
            writer.tryUpgrade()?.use((upgradedWriter) {
              expect(upgradedWriter, isNot(equals(writer)));
              upgraded = true;
            });
          });
          expect(upgraded, isTrue);
        } finally {
          lock.release();
        }
      });

      test('from first reader', () async {
        var step = 0;
        final futures = [
          ReaderWriterLock.read(sharedResource).useAsync((reader) async {
            expect(step, isZero);
            step = 1;
            reader.tryUpgrade()?.use((writer) {
              expect(step, equals(2));
              step = 3;
            });
          }),
          ReaderWriterLock.read(sharedResource).useAsync((reader) async {
            expect(step, equals(1));
            await Future.delayed(smallDelay);
            step = 2;
          })
        ];

        await Future.wait(futures);

        expect(step, equals(2));
      });

      test('from second reader', () async {
        var step = 0;
        final futures = [
          ReaderWriterLock.read(sharedResource).useAsync((reader) async {
            expect(step, isZero);
            await Future.delayed(smallDelay);
            expect(step, equals(2));
            step = 1;
          }),
          ReaderWriterLock.read(sharedResource).useAsync((reader) async {
            expect(step, isZero);
            step = 2;
            reader.tryUpgrade()?.use((writer) {
              expect(step, equals(1));
              step = 3;
            });
          })
        ];

        await Future.wait(futures);

        expect(step, equals(1));
      });
    });

    group('downgrade', () {
      test('from single reader', () async {
        final lock = await ReaderWriterLock.read(sharedResource);
        try {
          var downgraded = false;
          await lock.runAsync((reader) async {
            reader.downgrade();
            downgraded = true;
          });
          expect(downgraded, isTrue);
        } finally {
          lock.release();
        }
      });

      test('from single writer', () async {
        final lock = await ReaderWriterLock.write(sharedResource);
        try {
          var downgraded = false;
          await lock.runAsync((writer) async {
            writer.downgrade();
            downgraded = true;
          });
          expect(downgraded, isTrue);
        } finally {
          lock.release();
        }
      });
    });
  });
}
