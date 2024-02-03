import 'dart:async';

import 'package:synchronize/synchronize.dart';
import 'package:using/using.dart';

import 'impl/utils.dart';

void main() async {
  // enable tracking
  ReleasableTracker.enable();

  // the lock target
  final target = Object();

  final serializedFutures = <Future<void>>[];

  String zoneId() => Zone.current.hashCode.toRadixString(16).padLeft(8, '0');

  for (var i = 0; i < 5; i++) {
    serializedFutures.add(Future(() async {
      final lock = Lock.tryAcquire(target);
      if (lock != null) {
        lock.use((l) {
          Print.green('[${zoneId()}] Future #$i got $l with tryAcquire');
        });

        lock.isReleased
            ? Print.green('[${zoneId()}] $lock has been released')
            : Print.red('[${zoneId()}] $lock has NOT been released');
      } else {
        Print.green('[${zoneId()}] Future #$i missed lock with tryAcquire');
      }

      await Lock.acquire(target).useAsync((l) async {
        Print.blue('[${zoneId()}] Future #$i got $l with acquire');
        await randomDelay(factor: 10);

        // try to re-acquire a new lock
        await Lock.tryAcquire(target)?.useAsync((l) async {
          Print.blue('[${zoneId()}] Future #$i got $l with tryAcquire');
          await randomDelay(factor: 10);
        });

        // re-enter
        await Lock.acquire(target).useAsync((l) async {
          Print.blue('[${zoneId()}] Future #$i got $l with acquire');
          await randomDelay(factor: 10);
        });
      });
    }));
  }

  await Future.wait(serializedFutures);

  Print.blue('Done');

  // report
  Print.std('Tracked count = ${ReleasableTracker.releasables.length}');
}
