import 'dart:async';

class ConsoleLogManager {
  static final ConsoleLogManager _instance = ConsoleLogManager._internal();
  factory ConsoleLogManager() => _instance;
  ConsoleLogManager._internal();

  final StreamController<String> _logController =
      StreamController<String>.broadcast();
  final List<String> logs = [];

  Stream<String> get logStream => _logController.stream;

  void addLog(String message) {
    final timestamp = DateTime.now()
        .toIso8601String()
        .split('T')
        .last
        .substring(0, 8);
    final formattedMessage = "[$timestamp] $message";
    logs.add(formattedMessage);
    _logController.add(formattedMessage);
  }

  void clearLogs() {
    logs.clear();
    _logController.add("--- Logs Cleared ---");
  }
}
