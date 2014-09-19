library main_controller;

import 'dart:io';
import 'dart:convert';
import 'dart:async';
import '../app.dart';
import '../firebase.dart';
import '../../shared/response.dart';
import '../../shared/model/user.dart';
import '../../../config/config.dart';
import '../mailer/mailer.dart';
import 'package:crypto/crypto.dart';

class MainController {
  static serveApp(App app, HttpRequest request, [String path]) {
    return new File(config['server']['directory'] + '/index.html');
  }

  static showCommunity(App app, HttpRequest request, String community) {
    if (Uri.parse(community).pathSegments[0].length > 0) {
      community = Uri.parse(community).pathSegments[0];
      Firebase.get('/alias_index/$community.json').then((indexData) {
        if (indexData == null) {
          return;
        } else {
          var type = indexData['type'];
        }
      });
    }

    // If you return an instance of File, it will be served.
    return new File(config['server']['directory'] + '/index.html');
  }

  static showItem(App app, HttpRequest request, String item) {
    // Serve the app as usual, and client router will handle showing the item.
    return new File(config['server']['directory'] + '/index.html');
  }

  static getCurrentUser(App app, HttpRequest request) {
    var id = request.cookies.firstWhere((cookie) => cookie.name == 'session').value;

    if (id == null) return new Response(false);

    // Find the username associated with the Facebook ID
    // that's in session.id, then get that user data.
    return Firebase.get('/facebook_index/$id.json').then((indexData) {
      var username = indexData['username'];
      return Firebase.get('/users/$username.json').then((userData) {
        return new Response()
          ..data = userData;
      });
    });
  }

  static aliasExists(String alias) {
    Firebase.get('/alias_index/$alias.json').then((res) {
      return (res == null ? false : true);
    });
  }

  /**
   * Send a welcome email to the user when they complete sign up.
   */
  static sendWelcomeEmail(App app, HttpRequest request) {
    var id = request.cookies.firstWhere((cookie) => cookie.name == 'session').value;

    if (id == null) return new Response(false);

    // Find the username associated with the Facebook ID
    // that's in session.id, then get that user data.
    return Firebase.get('/facebook_index/$id.json').then((indexData) {
      var username = indexData['username'];
      return Firebase.get('/users/$username.json').then((userData) {
        // Send the welcome email.
        var envelope = new Envelope()
          ..from = "Woven <support@woven.org>"
          ..to = "${userData['firstName']} ${userData['lastName']} <${userData['email']}>"
          ..bcc = "David Notik <davenotik@gmail.com>"
          ..subject = 'Welcome, ${userData['firstName']}!'
          ..text = '''
Hey ${userData['firstName']},

Thank you for creating an account on the new Woven.

Beyond social networking, this is collaborative networking. Woven is being designed from the ground up to help us coordinate our actions to improve the world.

The new Woven is starting simple and getting better every day.

Please take a moment to respond to me with your first impressions, good or bad. Please share all your feedback on the Early Adopters community on Woven as well.

And you can always call or text me on my mobile at 206-351-3948 – at any time.

Thank you for your early support!

--David Notik

--
Woven
http://mycommunity.org
''';
        return app.mailer.send(envelope).then((success) {
          return new Response(success);
        });
      });
    });
  }

  /**
   * Send email notifications as appropriate.
   */
  static sendNotifications(App app, HttpRequest request) {
    var item = request.requestedUri.queryParameters['itemid'];
    var comment = request.requestedUri.queryParameters['commentid'];
    Map notificationData = {};

    return Firebase.get('/items/$item.json').then((itemData) {
      notificationData['itemSubject'] = itemData['subject'];
      notificationData['itemAuthor'] = itemData['user'];
      var encodedItem = CryptoUtils.bytesToBase64(UTF8.encode(item));
      notificationData['itemLink'] = "http://${config['server']['domain']}/item/$encodedItem";
    }).then((_) {
      return Firebase.get('/users/${notificationData['itemAuthor']}.json').then((userData) {
        notificationData['itemAuthorEmail'] = userData['email'];
        notificationData['itemAuthorFirstName'] = userData['firstName'];
        notificationData['itemAuthorLastName'] = userData['lastName'];
      });
    }).then((_) {
      return Firebase.get('/items/$item/activities/comments/$comment.json').then((commentData) {
        notificationData['commentText'] = commentData['comment'];
        notificationData['commentAuthor'] = commentData['user'];
      });
    }).then((_) {
      return Firebase.get('/users/${notificationData['commentAuthor']}.json').then((userData) {
        notificationData['commentAuthorFirstName'] = userData['firstName'];
        notificationData['commentAuthorLastName'] = userData['lastName'];
      });
    }).then((_) {
      // Send the welcome email.
      var envelope = new Envelope()
        ..from = "Woven <support@woven.co>"
        ..to = "${notificationData['itemAuthorFirstName']} ${notificationData['itemAuthorLastName']} <${notificationData['itemAuthorEmail']}>"
        ..bcc = "David Notik <davenotik@gmail.com>"
        ..subject = '${notificationData['commentAuthorFirstName']} ${notificationData['commentAuthorLastName']} commented on your post'
        ..text = '''
Hey ${notificationData['itemAuthorFirstName']},

${notificationData['commentAuthorFirstName']} ${notificationData['commentAuthorLastName']} just commented on your post:

${notificationData['itemSubject']}
${notificationData['itemLink']}

${notificationData['commentText']}

--
Woven
http://mycommunity.org
''';
      return app.mailer.send(envelope).then((success) {
        return new Response(success);
      });
    });
  }
}
