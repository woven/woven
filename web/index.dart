import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:math';
import 'dart:async';
export 'package:polymer/init.dart';
import 'package:woven/src/config.dart';

// HACK until we fix code gen size. This doesn't really fix it,
// just makes it better.
@MirrorsUsed(override: '*')
import 'dart:mirrors';

void main() {
  var fbConfig = config['authentication']['facebook'];
  var appId = fbConfig['appId'];
  var url = fbConfig['url'];

  var loginLinkUrl = 'https://www.facebook.com/dialog/oauth/?client_id=$appId&redirect_uri=$url&state=TEST_TOKEN&scope=email';

  initPolymer().run(() {
    Polymer.onReady.then((_) {
      // Some things must wait until onReady callback is called
      print("Polymer ready...");
    });
  });
}
