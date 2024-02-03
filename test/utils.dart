import 'dart:async';

final smallDelay = Duration(milliseconds: 6);
final timeout = smallDelay * 5;

class TestException implements Exception {
  TestException([this.message = 'Intended test exception']);

  final String message;
}

ErrorOr<T> checkFuture<T>(FutureOr<T> future) {
  final res = ErrorOr<T>();
  if (future is T) {
    res._set(future);
    return res;
  } else {
    future.then(
      (v) => res._set(v),
      onError: (err, st) => res._set(null, err, st),
    );
  }
  return res;
}

class ErrorOr<T> {
  bool _ready = false;

  T? _value;
  Object? _error;
  StackTrace? _stackTrace;

  bool get isReady => _ready;

  T? get value => _value;
  Object? get error => _error;
  StackTrace? get stackTrace => _stackTrace;

  void _set(T? value, [Object? error, StackTrace? stackTrace]) {
    if (_ready) {
      throw Exception('ErrorOr<$T> already set');
    }
    _ready = true;
    _value = value;
    _error = error;
    _stackTrace = stackTrace ?? StackTrace.current;
  }
}
