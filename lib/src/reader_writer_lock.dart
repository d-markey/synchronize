import 'dart:async';

import 'package:cancelation_token/cancelation_token.dart';
import 'package:using/using.dart';

import '_utils.dart';

/// Class granting access to a specific instance of an object with multiple
/// concurrent readers or a single writer. Concurrent read access is obtained
/// by calling [read], and exclusive write access by calling [write].
///
/// Please note that the locks obtained by this class are not reentrant. If a
/// piece of code calls [read] or [write] after obtaining a lock which has not
/// been released, it will deadlock. When exclusive write access is necessary
/// after obtaining a shared read lock, the code should call [upgrade] or
/// [tryUpgrade] and release the instance returned by this call.
///
/// [ReaderWriterLock] instances obtained from calling methods of this class
/// must be released by calling [release]. This includes instances returned by
/// [read], [tryRead], [write], [tryWrite], [upgrade] and [tryUpgrade].
///
/// Locks are upgradable to gain exclusive write access by calling [upgrade].
/// Each successful call to [upgrade] will also need to be paired with a call
/// to [release]. If the lock has already obtained exclusive write access,
/// [upgrade] will grant immediate access. If the lock only has shared read
/// access, exclusive write access will only be granted after other read locks
/// have been released. If the current lock is the only read lock, it will
/// obtain write access immediately. Upgrades have priority over pending
/// exclusive write lock.
///
/// Locks are also downgradable to shared read access by calling [downgrade].
/// This method sets the lock's mode to read and [release] must *NOT* be called
/// after a successful call to [downgrade]. If the lock is already a read lock,
/// calling [downgrade] has no effect. Otherwise, the lock mode is set to read
/// and pending read lock requests will be granted read access.
///
/// [Releasable] extension methods [use] and [useAsync] should be used to
/// execute the code that needs shared read or exclusive write access to an
/// object, as these methods guarantee proper release of the lock.
class ReaderWriterLock with Releasable {
  static final _locks = <Object, List<ReaderWriterLock>>{};

  ReaderWriterLock._(this._target, this._mode, Duration? timeout, this._token) {
    track();
    _timeout = (timeout == null)
        ? null
        : Timer.periodic(timeout, (t) {
            if (!_isCompleted) {
              release();
              _completer.done(
                  null, TimeoutException('ReaderWriterLock timeout'));
            }
            t.cancel();
          });

    _token?.onCanceled.then((ex) {
      if (!_isCompleted) {
        release();
        _completer.done(null, ex);
      }
    });
  }

  ReaderWriterLock._read(
      Object target, Duration? timeout, CancelationToken? token)
      : this._(target, _read, timeout, token);

  ReaderWriterLock._upgrade(
      Object target, Duration? timeout, CancelationToken? token)
      : this._(target, _upgrade, timeout, token);

  ReaderWriterLock._write(
      Object target, Duration? timeout, CancelationToken? token)
      : this._(target, _write, timeout, token);

  int _mode;
  final Object _target;
  final _completer = Completer<ReaderWriterLock>();
  late final Timer? _timeout;
  final CancelationToken? _token;

  bool get isReader => _mode == _read;
  bool get isWriter => _mode == _write;
  bool get isUpgraded => _mode == _upgrade;

  bool get _isCompleted => _completer.isCompleted;
  Future<ReaderWriterLock> get _allowed => _completer.future;

  /// Obtain shared read access to [target]. If [target] is already locked for
  /// reading, access will be granted immediately. Otherwise, access will be
  /// granted after pending write/upgrade locks have been released. Instances
  /// returned by this method must be released by a call to [release].
  static Future<ReaderWriterLock> read(Object target,
      {Duration? timeout, CancelationToken? cancelToken}) {
    final lock = ReaderWriterLock._read(target, timeout, cancelToken);
    final requests = _locks.putIfAbsent(target, () => [])..add(lock);
    return lock._proceed(requests);
  }

  /// Try to obtain shared read access to [target]. If [target] is already
  /// locked for reading, access will be granted immediately. Otherwise, this
  /// method returns `null`. Instances returned by this method must be released
  /// by a call to [release].
  static ReaderWriterLock? tryRead(Object target) {
    final requests = _locks.putIfAbsent(target, () => []);
    if (requests.isEmpty || requests.every((r) => r.isReader)) {
      final lock = ReaderWriterLock._read(target, null, null);
      requests.add(lock);
      lock._proceed(requests);
      return lock;
    } else {
      return null;
    }
  }

  /// Obtain exclusive write access to [target]. If [target] is not already
  /// locked, access will be granted immediately. Otherwise, access will be
  /// granted after pending read/write/upgrade locks have been released.
  /// Instances returned by this method must be released by a call to [release].
  static Future<ReaderWriterLock> write(Object target,
      {Duration? timeout, CancelationToken? cancelToken}) {
    final lock = ReaderWriterLock._write(target, timeout, cancelToken);
    final requests = _locks.putIfAbsent(target, () => [])..add(lock);
    return lock._proceed(requests);
  }

  /// Try to obtain exclusive write access to [target]. If [target] is already
  /// locked, this method returns `null`. Instances returned by this method must
  /// be released by a call to [release].
  static ReaderWriterLock? tryWrite(Object target) {
    final requests = _locks.putIfAbsent(target, () => []);
    if (requests.isEmpty) {
      final lock = ReaderWriterLock._read(target, null, null);
      requests.add(lock);
      lock._proceed(requests);
      return lock;
    } else {
      return null;
    }
  }

  /// Upgrade the current lock for exclusive write access. If the current lock
  /// has shared read access, it will be upgraded after all other read locks
  /// have been released. If the current lock already has exclusive write
  /// access, it will be granted immediate access. Instances returned by this
  /// method must be released by a call to [release].
  Future<ReaderWriterLock> upgrade(
      {Duration? timeout, CancelationToken? cancelToken}) {
    // prepare upgrade lock [U*] that will be inserted in the list of lock
    // requests
    final upgrade = ReaderWriterLock._upgrade(_target, timeout, cancelToken);
    final requests = _locks[_target]!;

    if (requests.first.isReader) {
      // upgrade request from a read lock

      // current state = [R?] ... [Rn-1] [Rn]
      //              or [R?] ... [Rn-1] [Rn]  [W/] ...
      //              or [R?] ... [Rn-1] [Un/] [Rn]
      //              or [R?] ... [Rn-1] [Un/] [Rn] [W/] ...

      // since we're in a read scenario, all read locks have been granted
      // access and this lock is a read lock (but not necessarily the first
      // one in the list)
      assert(isReader);

      var lastRIdx = -1, lastUIdx = -1, thisRIdx = -1;
      for (var i = 0; i < requests.length; i++) {
        final request = requests[i];
        if (request.isWriter) {
          break;
        } else if (request.isReader) {
          lastRIdx = i;
          if (request == this) {
            thisRIdx = i;
          }
        } else {
          lastUIdx = i;
        }
      }

      // we need to make this read lock last in the current sequence of R/U
      // lock requests, and insert the upgrade lock just before it so that
      // [U*] will be granted access only after previous read locks have been
      // released.

      if (lastUIdx < 0) {
        // this is the first upgrade request, make sure this read lock is moved
        // last in the current sequence of R locks

        if (thisRIdx != lastRIdx) {
          // swap this read lock with the last one
          final tmp = requests[thisRIdx];
          requests[thisRIdx] = requests[lastRIdx];
          requests[lastRIdx] = tmp;
        }
        // insert the upgrade lock
        requests.insert(lastRIdx, upgrade);

        // final state = [R?] ... [Rn-1] [U*/] [Rn] ...
      } else {
        // this is a new, additional upgrade

        // insert the upgrade lock and make this read lock last
        requests.insert(lastRIdx + 1, upgrade);
        requests.removeAt(thisRIdx);
        requests.insert(lastRIdx + 1, this);

        // final state = [R?] ... [Rn-1] [Un/] [Rn] [U*/] [R] ...
      }
    } else {
      // current state = [W] ...
      //              or [U] ...

      // grant immediate access
      requests.insert(0, upgrade);

      // final state   = [U*] [W] ...
      //              or [U*] [U] ...
    }

    // if the upgrade lock is first, make sure it is granted access
    return upgrade._proceed(requests);
  }

  /// Try to upgrade the current lock for exclusive write access. This method
  /// will succeed only if 1/ the current lock has shared read access and is the
  /// active read lock or 2/ if the current lock already has exclusive write
  /// access. Instances returned by this method must be released by a call to
  /// [release].
  ReaderWriterLock? tryUpgrade() {
    // prepare upgrade lock [U*] that could be inserted in the list of lock
    // requests
    ReaderWriterLock? upgrade;
    final requests = _locks[_target]!;

    if (requests.first.isReader) {
      // upgrade request from a read lock

      // current state = [R]
      //              or [R] [W/] ...

      // since we're in a read scenario, all read locks have been granted
      // access and this lock is a read lock
      assert(isReader);

      if (requests.length == 1 || requests[1].isWriter) {
        upgrade = ReaderWriterLock._upgrade(_target, null, null);
        requests.insert(0, upgrade);
      }

      // final state   = [U*] [R]
      //              or [U*] [R] [W/] ...
    } else {
      // current state = [W] ...
      //              or [U] ...

      // grant immediate access
      upgrade = ReaderWriterLock._upgrade(_target, null, null);
      requests.insert(0, upgrade);

      // final state   = [U*] [W] ...
      //              or [U*] [U] ...
    }

    // if the upgrade lock is first, make sure it is granted access
    upgrade?._proceed(requests);
    return upgrade;
  }

  /// Downgrade the current lock to shared read access. If the current lock
  /// already has shared read access, calling this method has no effect.
  /// Otherwise, the current lock mode is set to read and any pending shared
  /// read requests will be granted access.
  void downgrade() {
    if (isReader) {
      // nothing to do
    } else {
      // convert current lock to read
      final requests = _locks[_target]!;
      assert(requests.first == this);
      requests.first._mode = _read;
      // grant read access now (will allow pending readers immediately)
      _proceed(requests);
    }
  }

  /// Release the lock. Instances returned by [read], [tryRead], [write],
  /// [tryWrite], [upgrade] and [tryUpgrade] must be released. [Releasable]
  /// extension methods [use] and [useAsync] will automatically release the
  /// locks. It is highly recommended to use these methods to execute code
  /// right after obtaining a lock.
  @override
  void release() {
    final requests = _locks[_target];
    if (requests != null) {
      requests.remove(this);
      if (requests.isEmpty) {
        _locks.remove(_target);
      } else {
        _proceed(requests);
      }
    }
    super.release();
  }

  /// Execute [process] in the context of this lock, then releases the lock.
  R run<R>(R Function(ReaderWriterLock) process) => use(process);

  /// Asynchronously execute [process] in the context of this lock, then
  /// releases the lock after [process] has completed.
  Future<R> runAsync<R>(Future<R> Function(ReaderWriterLock) process) =>
      useAsync(process);

  Future<ReaderWriterLock> _proceed(List<ReaderWriterLock> requests) {
    if (requests.isNotEmpty) {
      final next = requests.first;
      if (next.isReader) {
        // grant all subsequent read access in one go
        for (var read in requests.takeWhile((r) => r.isReader)) {
          read._allow();
        }
      } else {
        // grant upgrade/write access one at a time
        next._allow();
      }
    }
    return _allowed;
  }

  void _allow() {
    _timeout?.cancel();
    if (!_isCompleted && !(_token?.isCanceled ?? false)) {
      _completer.done(this);
    }
  }

  Stats getStats() {
    final requests = _locks[_target];
    if (requests == null || requests.isEmpty) {
      return Stats.zero;
    }
    final counters = {_read: 0, _upgrade: 0, _write: 0};
    for (var mode in requests.map((r) => r._mode)) {
      counters.update(mode, (c) => c + 1);
    }
    return Stats(counters[_read]!, counters[_write]!, counters[_upgrade]!);
  }

  @override
  String toString() {
    final requests = _locks[_target];
    if (requests == null || requests.isEmpty) {
      return '\u2205';
    } else {
      final stats = getStats();
      return '${toShortString()} 0x${toHex(hashCode)} (r:${stats.readers}/u:${stats.upgraded}/w:${stats.writers})';
    }
  }

  String toShortString() =>
      '${String.fromCharCode(_mode)}${_isCompleted ? '' : '/'}';

  // String _dump(String label, List<ReaderWriterLock> requests) => requests
  //         .isEmpty
  //     ? '$label => \u2205'
  //     : '$label => ${requests.map((l) => '[${(l == this) ? '*' : ''}${l.toShortString()}]').join(' ')}';
}

class Stats {
  const Stats(this.readers, this.writers, this.upgraded);

  static const zero = Stats(0, 0, 0);

  final int readers;
  final int writers;
  final int upgraded;
}

const _read = 0x52; // R
const _upgrade = 0x55; // U
const _write = 0x57; // W
