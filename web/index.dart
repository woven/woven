import 'package:polymer/polymer.dart';
export 'package:polymer/init.dart';
import 'package:logging/logging.dart';
import 'package:route/client.dart';
import 'package:woven/src/shared/routing/routes.dart';
import 'package:woven/src/client/controller/main.dart';
import 'package:woven/src/client/app.dart';


// HACK until we fix code gen size. This doesn't really fix it,
// just makes it better.
//@MirrorsUsed(override: '*')
//import 'dart:mirrors';

void main() {
  Router router;
  App app;
  // Raise the level of logging to the console
  //Logger.root.level = Level.ALL;
  //Logger.root.onRecord.listen((record) => print(record.message));

  router = new Router()
    ..addHandler(Routes.sayWelcome, MainController.sayWelcome(app))
    ..listen();

  initPolymer().run(() {
    Polymer.onReady.then((_) => print("Polymer ready..."));
  });
}
