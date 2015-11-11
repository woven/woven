library woven.server.daemon;

import 'util.dart';
import '../task_scheduler.dart';

import 'package:logging/logging.dart';

class Daemon {
  Daemon() {
    print('The Woven daemon is now running...');

    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((LogRecord rec) {
      print('${rec.level.name}: ${rec.time}: ${rec.message}');
    });

    TaskScheduler taskScheduler = new TaskScheduler();

    taskScheduler.run();
  }
}