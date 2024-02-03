import 'dart:async';

String toHex(int byte, {int width = 8}) =>
    '0x${byte.toRadixString(16).padLeft(width, '0')}';

void zlog(String message) =>
    print('${toHex(Zone.current.hashCode)}  |  $message');

extension ZoneExt on Zone {
  bool isParentOf(Zone other) {
    final parent = other.parent;
    return (parent == this) || (parent != null && isParentOf(parent));
  }
}

extension Done<X> on Completer<X> {
  void done(X? value, [Object? error, StackTrace? stackTrace]) {
    if (!isCompleted) {
      if (error != null) {
        completeError(error, stackTrace ?? StackTrace.current);
      } else {
        complete(value);
      }
    }
  }
}
