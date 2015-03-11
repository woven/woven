library routes;

import 'package:route/url_pattern.dart';

class Routes {
  static final home = new UrlPattern(r'/');
  static final sayFoo = new UrlPattern(r'/say/foo');
  static final sayHello = new UrlPattern(r'/say/hello/(.+)');
  static final showItem = new UrlPattern(r'/item/(.+)');
  static final signInFacebook = new UrlPattern(r'/signin/facebook');
  static final currentUser = new UrlPattern(r'/currentuser');
  static final starred = new UrlPattern(r'/saved');
  static final people = new UrlPattern(r'/people');
  static final communityPeople = new UrlPattern(r'(.+)/people');
  static final sendWelcome = new UrlPattern(r'/sendwelcome');
  static final sendNotificationsForItem = new UrlPattern(r'/_notifyforitem');
  static final sendNotificationsForComment = new UrlPattern(r'/_notifyforcomment');
  static final getUriPreview = new UrlPattern(r'/_geturipreview');
  static final addItem = new UrlPattern(r'/_additem');
  static final addMessage = new UrlPattern(r'/_addmessage');
  static final generateDigest = new UrlPattern(r'/admin/generatedigest');
  static final exportUsers = new UrlPattern(r'/admin/exportusers');
  static final signIn = new UrlPattern(r'/_signin');
  static final signOut = new UrlPattern(r'/_signout');
  static final createNewUser = new UrlPattern(r'/_createnewuser');
}

class NoMatchingRoute {}