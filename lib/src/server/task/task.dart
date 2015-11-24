library task;

import 'dart:async';

abstract class Task {
  bool runImmediately = false;
  bool isRunning = false;

  Duration interval = const Duration(seconds: 60);
  bool onceADay = false;
  DateTime runAtDailyTime = null; // Expects UTC.

  Future run();
}