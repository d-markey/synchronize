import 'dart:math';

final rnd = Random();

// 15 ms +/- 5 ms
Future randomDelay({int factor = 1}) =>
    Future.delayed(Duration(milliseconds: 10 + rnd.nextInt(10)) * factor);

String times(int n) {
  if (n == 1) return 'once';
  if (n == 2) return 'twice';
  return '$n times';
}

class Print {
  static const _reset = '\u001B[0m';
  static const _red = '\u001B[31m';
  static const _green = '\u001B[32m';
  static const _yellow = '\u001B[33m';
  static const _blue = '\u001B[34m';
  static const _cyan = '\u001B[36m';
  static const _gray = '\u001B[90m';

  static void _print(String message) {
    print(message);
    // stdout.nonBlocking.add(utf8.encode('$message\n'));
    // stdout.writeln(message);
    // stdout.flush();
  }

  static void std(String message) => _print(message);

  static void red(String message) => _print('$_red$message$_reset');
  static void blue(String message) => _print('$_blue$message$_reset');
  static void green(String message) => _print('$_green$message$_reset');
  static void yellow(String message) => _print('$_yellow$message$_reset');
  static void cyan(String message) => _print('$_cyan$message$_reset');
  static void gray(String message) => _print('$_gray$message$_reset');
}
