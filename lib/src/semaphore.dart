import 'dart:async';

import 'package:cancelation_token/cancelation_token.dart';

import '_utils.dart';
import 'exceptions.dart';

/// Class implementing a semaphore. Client code can call [enter] or [tryEnter]
/// to eventually enter the semaphore and decrement the [currentCount], and
/// [signal] or [leave] to increment the [currentCount] and allow tasks.
class Semaphore {
  /// Create a new semaphore with [initialCount] and optional [maxCount].
  Semaphore(this.initialCount, {this.maxCount})
      : _currentAvailableCount = initialCount,
        assert(initialCount >= 0),
        assert(maxCount == null || (initialCount <= maxCount && maxCount > 0));

  final int initialCount;
  final int? maxCount;

  int _currentAvailableCount;

  /// The semaphore's current counter (represents how many resources are
  /// available).
  int get currentCount => _currentAvailableCount;

  /// The semaphore's pending count (represents how many resources have been
  /// requested but are not yet available).
  int get pendingCount => _completers.length;

  final _completers = <Completer<bool>>[];

  /// Increment [currentCount] by [count] and allow pending requests to enter
  /// the semaphore. If [maxCount] was provided and [currentCount] + [count]
  /// exceeds the limit, a [SemaphoreFullException] is thrown immediately.
  void signal([int count = 1]) {
    // verify count and max count if set
    if (count < 0) {
      throw ArgumentError.value(count, 'count');
    }
    if (maxCount != null && _currentAvailableCount + count > maxCount!) {
      throw SemaphoreFullException();
    }
    // update current count
    _currentAvailableCount += count;
    // allow pending requests
    while (_currentAvailableCount > 0 && _completers.isNotEmpty) {
      final completer = _completers.removeAt(0);
      completer.done(true);
      _currentAvailableCount -= 1;
    }
  }

  /// Alias for [signal] with `count = 1`.
  void leave() => signal(1);

  /// If [currentCount] is positive, decrement the counter and returns `true`.
  /// Otherwise, returns a future that will complete after [signal] is
  /// eventually called to free a resource. If a [timeout] is provided and the
  /// timeout expires, a [TimeoutException] will be thrown.
  FutureOr<bool> enter(
      {Duration? timeout, CancelationToken? cancelationToken}) {
    cancelationToken?.throwIfCanceled();

    // sync route
    if (_currentAvailableCount > 0) {
      _currentAvailableCount--;
      return true;
    }

    // async route
    final completer = Completer<bool>();
    _completers.add(completer);

    if (timeout != null) {
      Timer.periodic(timeout, (t) {
        _completers.remove(completer);
        completer.done(null, TimeoutException('Semaphore request timeout'));
        t.cancel();
      });
    }

    if (cancelationToken != null) {
      cancelationToken.onCanceled.then((ex) {
        _completers.remove(completer);
        completer.done(null, ex);
      });
    }

    return completer.future;
  }

  /// If [currentCount] is positive, decrement the counter and returns `true`,
  /// otherwise, returns `false`.
  bool tryEnter() {
    if (_currentAvailableCount > 0) {
      _currentAvailableCount--;
      return true;
    } else {
      return false;
    }
  }
}
