library mail_controller;

import 'dart:io';
import 'dart:async';
import 'dart:convert';

import '../app.dart';
import '../firebase.dart';
import '../mailer/mailer.dart';
import 'package:woven/src/shared/response.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/shared/shared_util.dart';
import 'package:woven/src/shared/regex.dart';

class MailController {
  /**
   * Send a welcome email to the user when they complete sign up.
   */
  static sendWelcomeEmail(App app, HttpRequest request) {
    var id = request.cookies.firstWhere((cookie) => cookie.name == 'session').value;

    if (id == null) return new Response(false);

    // Find the username associated with the Facebook ID
    // that's in session.id, then get that user data.
    return Firebase.get('/facebook_index/$id.json').then((indexData) {
      var username = (indexData['username'] as String).toLowerCase();
      return Firebase.get('/users/$username.json').then((userData) {
        // Send the welcome email.
        var envelope = new Envelope()
          ..from = "Woven <hello@woven.co>"
          ..to = ['${userData['firstName']} ${userData['lastName']} <${userData['email']}>']
          ..bcc = ['David Notik <davenotik@gmail.com>']
          ..subject = 'Welcome, ${userData['firstName']}!'
          ..text = '''
Hi ${userData['firstName']},

Thank you for joining Woven.

Access is limited at this time. The quickest way to get in is to ask someone to invite you to an existing channel.
If you don't know someone, reply to this email and let us know which channel you believe you should have access to.

Otherwise, we'll let you know when we open up to more communities. Thank you very much for your patience.

--
Woven
http://woven.co

http://facebook.com/woven
http://twitter.com/wovenco
''';
        return app.mailer.send(envelope).then((success) {
          return new Response(success);
        });
      });
    });
  }

  static sendNotificationsForItem(App app, HttpRequest request) {
    Map data = request.requestedUri.queryParameters;
    sendNotifications('item', data, app);
  }

  static sendNotificationsForComment(App app, HttpRequest request) {
    Map data = request.requestedUri.queryParameters;
    sendNotifications('comment', data, app);
  }

//  static sendNotificationsForMessage(App app, HttpRequest request) {
//    Map data = request.requestedUri.queryParameters;
//    _sendNotifications('message', data, app);
//  }


//  static sendNotificationsForItem(App app, HttpRequest request) {
//    var item = request.requestedUri.queryParameters['itemid'];
//    var comment = request.requestedUri.queryParameters['commentid'];
//    // Sending notifications for an item itself (not a comment)?
//    String type = (comment == null) ? 'item' : 'comment';
//    String id = (comment == null) ? item : comment;
//
//    _sendNotifications(type, id);
//  }

  /**
   * Send email notifications as appropriate.
   */
  static sendNotifications(type, Map data, App app) {
    bool isItem = (type == 'item') ? true : false;
    bool isComment = (type == 'comment') ? true : false;
    bool isMessage = (type == 'message') ? true : false;
    var id = data['id']; // The id of the item/comment/message we're notifying about.
    var item = (type == 'item') ? id : data['itemid']; // If this isn't an item, we still might have/need the item id.

    Map notificationData = {};

    Future findItem() {
      return Firebase.get('/items/$item.json').then((itemData) {
        notificationData['itemSubject'] = itemData['subject'];
        notificationData['itemAuthor'] = (itemData['user'] as String).toLowerCase();
        notificationData['itemBody'] = itemData['body'];
        notificationData['message'] = itemData['message'];
        var encodedItem = base64Encode(id);
        notificationData['itemLink'] = "http://${config['server']['displayDomain']}/item/$encodedItem";

        if (isItem) return;

        // Find all the unique users who have commented on this item.
        Map comments = itemData['activities']['comments'];
        notificationData['participants'] = comments.values.map((v) => v['user']).toSet();
      });
    }

    Future findItemAuthorInfo(_) {
      return Firebase.get('/users/${notificationData['itemAuthor']}.json').then((userData) {
        if (isItem) {
          notificationData['itemAuthorEmail'] = userData['email'];
          notificationData['itemAuthorFirstName'] = userData['firstName'];
          notificationData['itemAuthorLastName'] = userData['lastName'];
        }
      });
    }

    Future findCommentAuthorInfo(_) {
      if (isItem) return null;
      return Firebase.get('/users/${notificationData['commentAuthor']}.json').then((userData) {
        notificationData['commentAuthorFirstName'] = userData['firstName'];
        notificationData['commentAuthorLastName'] = userData['lastName'];
      });
    }

    Future findMessageAuthorInfo(_) {
      return Firebase.get('/users/${notificationData['messageAuthor']}.json').then((userData) {
        notificationData['messageAuthorFirstName'] = userData['firstName'];
        notificationData['messageAuthorLastName'] = userData['lastName'];
      });
    }

    Future findCommentInfo() {
      if (isItem) return null;
      return Firebase.get('/items/$item/activities/comments/$id.json').then((commentData) {
        notificationData['commentBody'] = commentData['comment'];
        notificationData['commentAuthor'] = (commentData['user'] as String).toLowerCase();
      });
    }

    Future findMessage() {
      return Firebase.get('/messages/$id.json').then((messageData) {
        notificationData['message'] = messageData['message'];
        notificationData['messageAuthor'] = (messageData['user'] as String).toLowerCase();
        notificationData['itemLink'] = "http://${config['server']['displayDomain']}/${messageData['community']}";
      });
    }

    notify(_) {
      // Order matters, as we prioritize notification of mentions over multiple notifications.
      _notifyMentionedUsers(type, notificationData, app);

      // If it's a comment we're notifying about, notify participants on the parent item.
      if (isComment) {
        _notifyAuthor(app, notificationData);
        _notifyOtherParticipants(app, notificationData);
      };
    }

    // Logic for handling the notifications.
    if (isItem) {
      return findItem()
      .then((_) => Future.wait([findItemAuthorInfo(_)]))
      .then(notify).catchError((error, stack) => print("Error in notify:\n$error\n\nStack trace:\n$stack"))
      .then((success) => new Response(success))
      .catchError((error) => print("Error sending notifications: $error"));
    }
    if (isComment) {
      return findItem()
      .then((_) => Future.wait([findItemAuthorInfo(_), findCommentInfo()]))
      .then(findCommentAuthorInfo)
      .then(notify).catchError((error, stack) => print("Error in notify:\n$error\n\nStack trace:\n$stack"))
      .then((success) => new Response(success))
      .catchError((error) => print("Error sending notifications: $error"));
    }
    if (isMessage) {
      return findMessage()
      .then((_) => Future.wait([findMessageAuthorInfo(_)]))
      // TODO: Get the community details, like the name.
      .then(notify).catchError((error, stack) => print("Error in notify:\n$error\n\nStack trace:\n$stack"))
      .then((success) => new Response(success))
      .catchError((error) => print("Error sending notifications: $error"));
    }
  }

  static _notifyAuthor(App app, Map notificationData) {
    // Don't send this notification when we've already notified the author that someone mentioned him.
    if (notificationData['itemAuthorMentioned'] != null && notificationData['itemAuthorMentioned'] == true) return;

    // Don't send notifications when the item author comments on their own post.
    if (notificationData['itemAuthor'] != notificationData['commentAuthor']) {
      var commentAuthorFirstName = notificationData['commentAuthorFirstName'];
      var commentAuthorLastName = notificationData['commentAuthorLastName'];
      var itemAuthorFirstName = notificationData['itemAuthorFirstName'];
      var itemAuthorLastName = notificationData['itemAuthorLastName'];

      // Send notification.
      var envelope = new Envelope()
        ..from = "Woven <hello@woven.co>"
        ..to = ['$itemAuthorFirstName $itemAuthorLastName <${notificationData['itemAuthorEmail']}>']
        ..bcc = ['David Notik <davenotik@gmail.com>']
        ..subject = '$commentAuthorFirstName $commentAuthorLastName commented on your post'
        ..text = '''
Hey $itemAuthorFirstName,

$commentAuthorFirstName $commentAuthorLastName just commented on your post:

${notificationData['itemSubject']}
${notificationData['itemLink']}

${notificationData['commentBody']}

--
Woven
http://woven.co
''';
      app.mailer.send(envelope);
    }
    return;
  }

  static _notifyOtherParticipants(App app, Map notificationData) {
    Set participants = notificationData['participants'];
    List mentions = notificationData['mentions'];

    // Notify participants.
    participants.forEach((participant) {

      // If participant mentioned and thus already notified, don't notify again.
      if (mentions.contains(participant)) return;

      // Don't notify the author of the original item (whom we email above) or said comment.
      if (participant != notificationData['itemAuthor'] && participant != notificationData['commentAuthor']) {
        // Get the participant's user details.
        Firebase.get('/users/$participant.json').then((userData) {
          if (userData == null) return;

          var participantFirstName = userData['firstName'];
          var participantLastName = userData['lastName'];
          var participantEmail = userData['email'];
          var commentAuthorFirstName = notificationData['commentAuthorFirstName'];
          var commentAuthorLastName = notificationData['commentAuthorLastName'];
          var referToItemAuthorAs = "${notificationData['itemAuthorFirstName']} ${formatPossessive(notificationData['itemAuthorLastName'])}";

          // Don't ever say "Dave commented on Dave's post". Later we'll know his or her.
          if (notificationData['commentAuthor'] == notificationData['itemAuthor']) referToItemAuthorAs = "their";

          // Send notification.
          var envelope = new Envelope()
            ..from = "Woven <hello@woven.co>"
            ..to = ['$participantFirstName $participantLastName <$participantEmail>']
            ..bcc = ['David Notik <davenotik@gmail.com>']
            ..subject = "$commentAuthorFirstName $commentAuthorLastName also commented on $referToItemAuthorAs post"
            ..text = '''
Hey $participantFirstName,

$commentAuthorFirstName $commentAuthorLastName also commented on $referToItemAuthorAs post:

${notificationData['itemSubject']}
${notificationData['itemLink']}

${notificationData['commentBody']}

--
Woven
http://woven.co
''';
          app.mailer.send(envelope);
        });
      }
      return;
    });
  }

  static _notifyMentionedUsers(String type, Map notificationData, App app) {
    bool isItem = (type == 'item') ? true : false;
    bool isComment = (type == 'comment') ? true : false;
    bool isMessage = (type == 'message') ? true : false;

    var regExp = new RegExp(RegexHelper.mention, caseSensitive: false);

    // Combine message and item body fields for purpose of parsing all @mentions in either.
    String postText;
    if (isItem) postText = '${notificationData['message']}\n===\n${notificationData['itemBody']}';
    if (isComment) postText = notificationData['commentBody'];
    if (isMessage) postText = notificationData['message'];

    List mentions = [];

    // Remember any mentions so we can special case other notifications.
    notificationData['mentions'] = mentions;

    for (var mention in regExp.allMatches(postText)) {
      if (mentions.contains(mention.group(2))) return;
      mentions.add(mention.group(2).replaceAll("@", ""));
    }

    mentions.forEach((String user) {
      user = user.toLowerCase();
      // Don't notify when you mention yourself.
      if (user == notificationData['commentAuthor']) return;

      // If the item author is mentioned, remember it so we don't also send other notifications.
      if (user == notificationData['itemAuthor']) notificationData['itemAuthorMentioned'] = true;

      // Get the user data. TODO: Address case sensitivity of usernames.
      Firebase.get('/users/$user.json').then((userData) {
        if (userData == null) return;

        var firstName = userData['firstName'];
        var lastName = userData['lastName'];
        var email = userData['email'];
        var postAuthorFirstName;
        var postAuthorLastName;
        var notificationText;

        if (isItem) {
          notificationText = '';
          postAuthorFirstName =  notificationData['itemAuthorFirstName'];
          postAuthorLastName =  notificationData['itemAuthorLastName'];
        }

        if (isComment) {
          notificationText = '\n${notificationData['commentBody']}\n';
          postAuthorFirstName =  notificationData['commentAuthorFirstName'];
          postAuthorLastName =  notificationData['commentAuthorLastName'];
        }

        if (isMessage) {
          notificationText = '\n${notificationData['message']}\n';
          postAuthorFirstName =  notificationData['messageAuthorFirstName'];
          postAuthorLastName =  notificationData['messageAuthorLastName'];
        }

        // Send notification.
        var envelope = new Envelope()
          ..from = "Woven <hello@woven.co>"
          ..to = ['$firstName $lastName <$email>']
          ..bcc = ['David Notik <davenotik@gmail.com>']
          ..subject = "$postAuthorFirstName $postAuthorLastName mentioned you on ${(notificationData['itemAuthor'] == user) ? 'your post' : 'Woven'}"
          ..text = '''
Hey $firstName,

$postAuthorFirstName $postAuthorLastName mentioned you${(notificationData['itemAuthor'] == user) ? ' on your post:' : ':'}

${notificationData['itemLink']}

--
Woven
http://woven.co
''';
        app.mailer.send(envelope);

      });
    });
  }

  /**
   * Generate a confirmation code and send a link to confirm user's email.
   */
  static sendConfirmEmail(App app, HttpRequest request) async {
    String dataReceived;

    await request.listen((List<int> buffer) {
      dataReceived = new String.fromCharCodes(buffer);
    }).asFuture();

    Map data = JSON.decode(dataReceived);

    // Prepare the data for save and response.
    data['email'] = (data['email'] as String).toLowerCase();
    DateTime now = new DateTime.now().toUtc();
    data['createdDate'] = now.toString();
    data['.priority'] = -now.millisecondsSinceEpoch;

    // Kill any existing session if the user signs up again.
    app.sessionManager.deleteCookie(request);

    var hash = generateRandomHash();
    var confirmLink = "http://${config['server']['displayDomain']}/confirm/$hash";

    print(hash);

    // Email the confirmation link to the user.
    var envelope = new Envelope()
      ..from = "Woven <hello@woven.co>"
      ..to = ['<${data['email']}>']
      ..bcc = ['David Notik <davenotik@gmail.com>']
      ..subject = "Please confirm your email"
      ..text = '''
Please go to this link to confirm your email address:

$confirmLink

Awaiting your return,

--
Woven
http://woven.co
''';
    app.mailer.send(envelope);


    // Save the confirmation hash to an index.
    Firebase.put('/email_confirmation_index/$hash.json', data, auth: config['datastore']['firebaseSecret']);

    var response = new Response();
    response.success = true;
    return response;
  }

  /**
   * Generate a confirmation code and send a link to confirm user's email.
   */
  static inviteUserToChannel(App app, HttpRequest request) async {
    String dataReceived;

    await request.listen((List<int> buffer) {
      dataReceived = new String.fromCharCodes(buffer);
    }).asFuture();

    Map data = JSON.decode(dataReceived);

    var getData = await Future.wait([
      Firebase.get('/users/${data['fromUser']}.json'),
      Firebase.get('/communities/${data['community']}.json')
    ]);

    Map fromUser = getData[0];
    Map community = getData[1];

    // Prepare the data for save and response.
    data['email'] = (data['email'] as String).toLowerCase();
    DateTime now = new DateTime.now().toUtc();
    data['createdDate'] = now.toString();
    data['.priority'] = -now.millisecondsSinceEpoch;
    data.remove('authToken');

    var hash = generateRandomHash();
    var confirmLink = "http://${config['server']['displayDomain']}/confirm/$hash";

    print(hash);

    // Email the confirmation link to the user.
    var envelope = new Envelope()
      ..from = "Woven <hello@woven.co>"
      ..to = ['<${data['email']}>']
      ..bcc = ['David Notik <davenotik@gmail.com>']
      ..subject = "${fromUser['firstName']} invited you to ${community['name']}"
      ..text = '''
${fromUser['firstName']} ${fromUser['lastName']} (${fromUser['username']} ) has invited you to ${community['name']} (${community['alias']}) on Woven.

Please go to this link to accept the invitation:

$confirmLink

--
Woven
http://woven.co
''';
    app.mailer.send(envelope);


    // Save the confirmation hash to an index.
    Firebase.put('/email_confirmation_index/$hash.json', data, auth: config['datastore']['firebaseSecret']);

    var response = new Response();
    response.success = true;
    return response;
  }
}