library routes;

import 'package:route/url_pattern.dart';

class Routes {
  static final home = new UrlPattern(r'/');
  static final sayFoo = new UrlPattern(r'/say/foo');
  static final sayHello = new UrlPattern(r'/say/hello/(.+)');
  static final signInFacebook = new UrlPattern(r'/sign-in/facebook');
  static final currentUser = new UrlPattern(r'/current-user');
}

class NoMatchingRoute {}
