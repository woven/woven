import 'package:polymer/polymer.dart';
export 'package:polymer/init.dart';
import 'package:logging/logging.dart';

// HACK until we fix code gen size. This doesn't really fix it,
// just makes it better.
@MirrorsUsed(override: '*')
import 'dart:mirrors';

void main() {
  // Raise the level of logging to the console
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) => print(record.message));
  initPolymer().run(() {
    Polymer.onReady.then((_) {
      // Some things must wait until onReady callback is called
      print("Polymer ready...");
    });
  });
}