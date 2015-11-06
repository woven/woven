library task_scheduler;

import 'dart:async';
import 'task/daily_digest.dart';
import 'task/crawler.dart';
import 'task/task.dart';
import 'app.dart';

/**
 * A very simple task scheduler.
 */
class TaskScheduler {
  App app;

  List<Task> tasks = [new DailyDigestTask(), new CrawlerTask()];

  TaskScheduler(this.app);

  run() {
    tasks.forEach((task) {
      task.app = app; // Inject app dependency.
      if (task.runImmediately) {
        task.run();
      } else {
        next() {
          if (task.isRunning) return;

          // Run at a specific daily time.
          if (task.runAtDailyTime != null) {
            var now = new DateTime.now().toUtc();

            var runAtTime = task.runAtDailyTime;
            var runAtTimeToToday = new DateTime.utc(
                now.year, now.month, now.day, runAtTime.hour, runAtTime.minute);
            var diff = now.difference(runAtTimeToToday);

//            print("now: $now / runAtTime: $runAtTime / runAtTimeToToday: $runAtTimeToToday / diff: $diff / diff.inSeconds: ${diff.inSeconds}");

            // If we're not within a minute of the scheduled time, get out of here.
            // TODO: What about edge cases like server restarts? We'll have to save last send to db.
            if (diff.inSeconds > 60 || diff.inSeconds <= 0) {
              // We match this diff to the task run interval in task.dart.
              return;
            }
          }

          if (task.onceADay) {
            var now = new DateTime.now();
            var diff = now.difference(
                new DateTime(now.year, now.month, now.day + 1, 0, 0, 0));
            if (diff.inMinutes >= 0 || diff.inMinutes < -15) {
              return;
            }
          }

          task.isRunning = true;

          var result = task.run();

          if (result is! Future) {
            task.isRunning = false;
            return;
          }

          result.whenComplete(() {
            task.isRunning = false;
          });
        }

        new Timer.periodic(task.interval, (t) {
          var f = next();
          if (f is Future) {
            f.catchError((e, s) {
              print('Caught severe zone error on Task Scheduler: $e\n\n$s');
            });
          }
        });
      }
    });
  }

  static log(String message) {
    DateTime now = new DateTime.now().toUtc();
    print('[$now]\t$message');
  }
}
