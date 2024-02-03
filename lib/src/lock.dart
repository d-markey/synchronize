import 'dart:async';

import 'package:cancelation_token/cancelation_token.dart';
import 'package:using/using.dart';

import '_utils.dart';

/// Class granting exclusive access to a specific instance of an object. The
/// lock is reentrant: if the calling code has already obtained the lock and
/// tries to acquire it again, access will be granted. Each successfull call
/// to [acquire] or [tryAcquire] must be matched by a call to [release].
/// Method [runAsync] will automatically release the lock after processing is
/// complete, as well as [Releasable] extension methods [use] and [useAsync].
class Lock with Releasable {
  Lock._(this._target)
      : _zone = Zone.current,
        _counter = 1;

  final Object _target;
  final Zone _zone;
  final _completer = Completer();
  int _counter;

  static final _locks = <Object, Lock>{};

  /// Acquire exclusive access to [target]. If [target] is not already locked
  /// or if the caller has already locked this instance, access is immediately
  /// granted. Otherwise, access will be granted when the code that placed the
  /// lock will release it. If a [timeout] is provided and the timeout expires,
  /// a [TimeoutException] will be thrown. If a [cancelationToken] was provided
  /// and the token is cancelled, a [CanceledException] will be thrown.
  static FutureOr<Lock> acquire(Object target,
      {Duration? timeout, CancelationToken? cancelationToken}) {
    // sync part
    cancelationToken?.throwIfCanceled();
    final existingLock = _locks[target];
    if (existingLock == null) {
      return _placeLock(target);
    } else if (_tryReenter(existingLock)) {
      return existingLock;
    }

    // async part, initialize completer
    final completer = Completer<Lock>();

    // install timeout timer
    Timer? timer;
    if (timeout != null) {
      timer = Timer.periodic(timeout, (t) {
        completer.done(null, TimeoutException('Lock request timeout'));
        t.cancel();
      });
    }

    // install cancelation handler
    cancelationToken?.onCanceled.then((ex) {
      completer.done(null, ex);
    });

    // install handlers for when the existing lock is released
    final sw = Stopwatch()..start();
    existingLock._completer.future.then(
      (_) async {
        // cancel timeout timer
        timer?.cancel();
        if (!completer.isCompleted) {
          // check remaining timeout
          timeout = (timeout == null) ? null : (timeout! - sw.elapsed);
          if (timeout?.isNegative ?? false) {
            completer.done(null, TimeoutException('Lock request timeout'));
            return;
          }
          // try acquire again with remaining timeout
          final lock = await acquire(target,
              timeout: timeout, cancelationToken: cancelationToken);
          completer.done(lock);
        }
      },
      onError: (ex, st) => completer.done(null, ex, st),
    );

    return completer.future;
  }

  /// Try to acquire exclusive access to [target]. If [target] is not locked
  /// yet or if the caller already owns the lock on this instance, access is
  /// granted immediately. Otherwise, this method returns `null`.
  static Lock? tryAcquire(Object target) {
    final existingLock = _locks[target];
    if (existingLock == null) {
      return _placeLock(target);
    } else {
      return _tryReenter(existingLock) ? existingLock : null;
    }
  }

  static bool _tryReenter(Lock existingLock) {
    if (existingLock._zone.isParentOf(Zone.current)) {
      existingLock._counter++;
      return true;
    } else {
      return false;
    }
  }

  static Lock _placeLock(Object target) {
    final lock = Lock._(target);
    _locks[target] = lock;
    return lock;
  }

  /// Execute [process] in the context of this lock, then releases the lock
  /// after [process] has completed. If [process] tries to reenter the lock,
  /// access will be granted immediately.
  R run<R>(R Function() process) => use((_) => process());

  /// Asynchronously execute [asyncProcess] in the context of this lock, then
  /// releases the lock after [asyncProcess] has completed. If [asyncProcess]
  /// tries to reenter the lock, access will be granted immediately.
  Future<R> runAsync<R>(Future<R> Function() asyncProcess) =>
      useAsync((_) => asyncProcess());

  @override

  /// Release the lock. Each successfull call to [acquire] or [tryAcquire] must
  /// be matched with a call to [release]. [run] and [runAsync] as well as
  /// [Releasable] extension methods [use] and [useAsync] will automatically
  /// call this method.
  void release() {
    if (_counter > 0) {
      _counter--;
      if (_counter == 0) {
        _locks.remove(_target);
        _completer.complete();
        super.release();
      }
    }
  }

  @override
  String toString() => '$runtimeType (${toHex(_target.hashCode)})';
}
