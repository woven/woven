library woven.server.daemon;

import 'util.dart';
import '../task_scheduler.dart';

class Daemon {
  Daemon() {
    print('The Woven daemon is now running...');

    TaskScheduler taskScheduler = new TaskScheduler(this);

    taskScheduler.run();
  }
}