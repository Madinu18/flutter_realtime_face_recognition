part of 'utils.dart';

class Logger {
  static void error(String message) {
    if (kDebugMode) {
      print('ERROR: $message');
    }
  }

  static void debug(String message) {
    if (kDebugMode) {
      print('DEBUG: $message');
    }
  }
}

class MSG {
  static void ERR(String message) => Logger.error(message);
  static void DBG(String message) => Logger.debug(message);
}
