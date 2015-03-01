library routes;

import 'package:route/url_pattern.dart';

class Routes {
  static final home = new UrlPattern(r'/');
  static final sayFoo = new UrlPattern(r'/say/foo');
  static final sayHello = new UrlPattern(r'/say/hello/(.+)');
  static final showItem = new UrlPattern(r'/item/(.+)');
  static final signInFacebook = new UrlPattern(r'/signin/facebook');
  static final currentUser = new UrlPattern(r'/currentuser');
  static final sayWelcome = new UrlPattern(r'/welcome');
  static final starred = new UrlPattern(r'/saved');
  static final people = new UrlPattern(r'/people');
  static final sendWelcome = new UrlPattern(r'/sendwelcome');
  static final sendNotifications = new UrlPattern(r'/x/sendnotifications');
  static final getUriPreview = new UrlPattern(r'/x/geturipreview');
  static final addItem = new UrlPattern(r'/x/additem');
  static final addMessage = new UrlPattern(r'/x/addmessage');
  static final generateDigest = new UrlPattern(r'/admin/generatedigest');
  static final exportUsers = new UrlPattern(r'/admin/exportusers');
  static final signIn = new UrlPattern(r'/_signin');
  static final createNewUser = new UrlPattern(r'/_createnewuser');
}

class NoMatchingRoute {}