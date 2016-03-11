library mail_controller;

import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart' as shelf;
import 'package:mustache/mustache.dart' as mustache;

import '../app.dart';
import '../firebase.dart';
import '../util.dart';
import '../mailer/mailer.dart';
import 'package:woven/src/shared/response.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/shared/util.dart';
import 'package:woven/src/shared/input_formatter.dart';
import 'package:woven/src/shared/regex.dart';
import 'package:woven/src/server/model/user.dart';

class MailController {
  static sendNotificationsForItem(App app, shelf.Request request) {
    Map data = request.requestedUri.queryParameters;
    sendNotifications('item', data, app);
    return new shelf.Response.ok(null);
  }

  static sendNotificationsForComment(App app, shelf.Request request) {
    Map data = request.requestedUri.queryParameters;
    sendNotifications('comment', data, app);
    return new shelf.Response.ok(null);
  }

  /**
   * Send email notifications as appropriate.
   */
  static sendNotifications(type, Map data, App app) {
    bool isItem = (type == 'item') ? true : false;
    bool isComment = (type == 'comment') ? true : false;
    bool isMessage = (type == 'message') ? true : false;
    var id =
        data['id']; // The id of the item/comment/message we're notifying about.
    var item = (type == 'item')
        ? id
        : data[
            'itemid']; // If this isn't an item, we still might have/need the item id.

    Map notificationData = {};

    Future findItem() {
      return Firebase.get('/items/$item.json').then((itemData) {
        notificationData['itemSubject'] = itemData['subject'];
        notificationData['itemAuthor'] =
            (itemData['user'] as String).toLowerCase();
        notificationData['itemBody'] = itemData['body'];
        notificationData['message'] = itemData['message'];
        var encodedItem = base64Encode(id);
        notificationData['itemLink'] =
            "http://${config['server']['displayDomain']}/item/$encodedItem";

        if (isItem) return;

        // Find all the unique users who have commented on this item.
        Map comments = itemData['activities']['comments'];
        notificationData['participants'] =
            comments.values.map((v) => v['user']).toSet();
      });
    }

    Future findItemAuthorInfo(_) {
      return Firebase
          .get('/users/${notificationData['itemAuthor']}.json')
          .then((userData) {
        if (isItem) {
          notificationData['itemAuthorEmail'] = userData['email'];
          notificationData['itemAuthorFirstName'] = userData['firstName'];
          notificationData['itemAuthorLastName'] = userData['lastName'];
        }
      });
    }

    Future findCommentAuthorInfo(_) {
      if (isItem) return null;
      return Firebase
          .get('/users/${notificationData['commentAuthor']}.json')
          .then((userData) {
        notificationData['commentAuthorFirstName'] = userData['firstName'];
        notificationData['commentAuthorLastName'] = userData['lastName'];
      });
    }

    Future findMessageAuthorInfo(_) {
      return Firebase
          .get('/users/${notificationData['messageAuthor']}.json')
          .then((userData) {
        notificationData['messageAuthorFirstName'] = userData['firstName'];
        notificationData['messageAuthorLastName'] = userData['lastName'];
      });
    }

    Future findCommunityInfo(_) async {
      Map userData = await Firebase
          .get('/communities/${notificationData['community']}.json');

      notificationData['communityName'] = userData['name'];
    }

    Future findCommentInfo() {
      if (isItem) return null;
      return Firebase
          .get('/items/$item/activities/comments/$id.json')
          .then((commentData) {
        notificationData['commentBody'] = commentData['comment'];
        notificationData['commentAuthor'] =
            (commentData['user'] as String).toLowerCase();
      });
    }

    Future findMessage() {
      return Firebase.get('/messages/$id.json').then((messageData) {
        notificationData['message'] = messageData['message'];
        notificationData['messageAuthor'] =
            (messageData['user'] as String).toLowerCase();
        notificationData['community'] = messageData['community'];
        notificationData['itemLink'] =
            "http://${config['server']['displayDomain']}/${messageData['community']}";
      });
    }

    notify(_) {
      // Order matters, as we prioritize notification of mentions over multiple notifications.
      _notifyMentionedUsers(type, notificationData, app);

      // If it's a comment we're notifying about, notify participants on the parent item.
      if (isComment) {
        _notifyAuthor(app, notificationData);
        _notifyOtherParticipants(app, notificationData);
      }
      ;
    }

    // Logic for handling the notifications.
    if (isItem) {
      return findItem()
          .then((_) => Future.wait([findItemAuthorInfo(_)]))
          .then(notify)
          .catchError((error, stack) =>
              print("Error in notify:\n$error\n\nStack trace:\n$stack"))
          .then((success) => new Response(success))
          .catchError((error) => print("Error sending notifications: $error"));
    }
    if (isComment) {
      return findItem()
          .then((_) => Future.wait([findItemAuthorInfo(_), findCommentInfo()]))
          .then(findCommentAuthorInfo)
          .then(notify)
          .catchError((error, stack) =>
              print("Error in notify:\n$error\n\nStack trace:\n$stack"))
          .then((success) => new Response(success))
          .catchError((error) => print("Error sending notifications: $error"));
    }
    if (isMessage) {
      return findMessage()
          .then((_) =>
              Future.wait([findMessageAuthorInfo(_), findCommunityInfo(_)]))
          // TODO: Get the community details, like the name.
          .then(notify)
          .catchError((error, stack) =>
              print("Error in notify:\n$error\n\nStack trace:\n$stack"))
          .then((success) => new Response(success))
          .catchError((error) => print("Error sending notifications: $error"));
    }
  }

  static _notifyAuthor(App app, Map notificationData) {
    // Don't send this notification when we've already notified the author that someone mentioned him.
    if (notificationData['itemAuthorMentioned'] != null &&
        notificationData['itemAuthorMentioned'] == true) return;

    // Don't send notifications when the item author comments on their own post.
    if (notificationData['itemAuthor'] != notificationData['commentAuthor']) {
      var commentAuthorFirstName = notificationData['commentAuthorFirstName'];
      var commentAuthorLastName = notificationData['commentAuthorLastName'];
      var itemAuthorFirstName = notificationData['itemAuthorFirstName'];
      var itemAuthorLastName = notificationData['itemAuthorLastName'];

      // Send notification.
      var envelope = new Envelope()
        ..from = "Woven <hello@woven.co>"
        ..to = [
          '$itemAuthorFirstName $itemAuthorLastName <${notificationData['itemAuthorEmail']}>'
        ]
        ..bcc = ['David Notik <davenotik@gmail.com>']
        ..subject =
            '$commentAuthorFirstName $commentAuthorLastName commented on your post'
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
      Mailgun.send(envelope);
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
      if (participant != notificationData['itemAuthor'] &&
          participant != notificationData['commentAuthor']) {
        // Get the participant's user details.
        Firebase.get('/users/$participant.json').then((userData) {
          if (userData == null) return;

          var participantFirstName = userData['firstName'];
          var participantLastName = userData['lastName'];
          var participantEmail = userData['email'];
          var commentAuthorFirstName =
              notificationData['commentAuthorFirstName'];
          var commentAuthorLastName = notificationData['commentAuthorLastName'];
          var referToItemAuthorAs =
              "${notificationData['itemAuthorFirstName']} ${formatPossessive(notificationData['itemAuthorLastName'])}";

          // Don't ever say "Dave commented on Dave's post". Later we'll know his or her.
          if (notificationData['commentAuthor'] ==
              notificationData['itemAuthor']) referToItemAuthorAs = "their";

          // Send notification.
          var envelope = new Envelope()
            ..from = "Woven <hello@woven.co>"
            ..to = [
              '$participantFirstName $participantLastName <$participantEmail>'
            ]
            ..bcc = ['David Notik <davenotik@gmail.com>']
            ..subject =
                "$commentAuthorFirstName $commentAuthorLastName also commented on $referToItemAuthorAs post"
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
          Mailgun.send(envelope);
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
    if (isItem)
      postText =
          '${notificationData['message']}\n===\n${notificationData['itemBody']}';
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
      if (user == notificationData['itemAuthor'])
        notificationData['itemAuthorMentioned'] = true;

      // Get the user data. TODO: Address case sensitivity of usernames.
      Firebase.get('/users/$user.json').then((userData) async {
        if (userData == null) return;

        var firstName = userData['firstName'];
        var lastName = userData['lastName'];
        var email = userData['email'];
        var postAuthor;
        var postAuthorFirstName;
        var postAuthorLastName;
        var notificationText;

        if (isItem) {
          notificationText = '';
          postAuthor = notificationData['itemAuthor'];
          postAuthorFirstName = notificationData['itemAuthorFirstName'];
          postAuthorLastName = notificationData['itemAuthorLastName'];
        }

        if (isComment) {
          notificationText = '${notificationData['commentBody']}';
          postAuthor = notificationData['commentAuthor'];
          postAuthorFirstName = notificationData['commentAuthorFirstName'];
          postAuthorLastName = notificationData['commentAuthorLastName'];
        }

        if (isMessage) {
          notificationText = InputFormatter
              .formatUserTextForEmail(notificationData['message']);
          postAuthor = notificationData['messageAuthor'];
          postAuthorFirstName = notificationData['messageAuthorFirstName'];
          postAuthorLastName = notificationData['messageAuthorLastName'];
        }

        // Build the HTML template for notifications.
        List messages = [];
        Map message = {};
        // TODO: Later, we can show more messages for better context.
        List items = [
          {'message': notificationText}
        ];
        var templateValues = {};

        message['usernameForDisplay'] =
            await UserModel.usernameForDisplay(postAuthor);
        var getPicture = await UserModel.getFullPathToPicture(postAuthor);
        message['fullPathToPicture'] = (getPicture != null ? getPicture : null);
        message['items'] = items;

        messages.add(message);

        templateValues['communityName'] = notificationData['communityName'];
        templateValues['community'] = notificationData['community'];
        templateValues['leaderText'] =
            '$postAuthorFirstName $postAuthorLastName mentioned you${(notificationData['itemAuthor'] == user) ? ' on your post.' : '.'}';
        templateValues['messages'] = messages;
        templateValues['has_messages'] = true;

        String contents =
            await new File('web/static/templates/user_mentioned_email.mustache')
                .readAsString();

        // Parse the template.
        var template = mustache.parse(contents);
        var output = template.renderString(templateValues);

        var subject =
            '$postAuthorFirstName $postAuthorLastName mentioned you on ${(notificationData['itemAuthor'] == user) ? 'your post' : 'Woven'}';

        // Send notification.
        var envelope = new Envelope()
          ..from = "Woven <hello@woven.co>"
          ..to = ['$firstName $lastName <$email>']
          ..bcc = ['David Notik <davenotik@gmail.com>']
          ..subject = subject
          ..html = output;
        Mailgun.send(envelope);
      });
    });
  }

  /**
   * Generate a confirmation code and send a link to confirm user's email.
   */
  static sendConfirmEmail(App app, shelf.Request request) async {
    Map data = JSON.decode(await request.readAsString());

    // Prepare the data for save and response.
    data['email'] = (data['email'] as String).toLowerCase();
    DateTime now = new DateTime.now().toUtc();
    data['createdDate'] = now.toString();
    data['.priority'] = -now.millisecondsSinceEpoch;

    var checkForExistingEmail = await Firebase
        .get('/email_index/${encodeFirebaseKey(data['email'])}.json');
    if (checkForExistingEmail != null)
      return respond(Response.fromError(
          'There\'s already an account associated with that email address.'));

    // Kill any existing session if the user signs up again.
//    app.sessionManager.deleteCookie(request);

    var hash = generateRandomHash();
    var confirmLink =
        "http://${config['server']['displayDomain']}/confirm/$hash";

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
    Mailgun.send(envelope);

    // Save the confirmation hash to an index.
    await Firebase
        .put('/email_confirmation_index/$hash.json', data,
            auth: config['datastore']['firebaseSecret'])
        .catchError((e) => print(e));

    var response = new Response();
    response.success = true;
    return respond(response);
  }

  /**
   * Generate a confirmation code and send a link to confirm user's email.
   */
  static inviteUserToChannel(App app, shelf.Request request) async {
    Map data = JSON.decode(await request.readAsString());

    if (!isValidEmail(data['email']))
      return Response
          .fromError('That doesn\'t look like a valid email address.');

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
    var confirmLink =
        "http://${config['server']['displayDomain']}/confirm/$hash";

    print(hash);

    // Email the confirmation link to the user.
    var envelope = new Envelope()
      ..from = "Woven <hello@woven.co>"
      ..to = ['<${data['email']}>']
      ..bcc = ['David Notik <davenotik@gmail.com>']
      ..subject = "${fromUser['firstName']} invited you to ${community['name']}"
      ..text = '''
${fromUser['firstName']} ${fromUser['lastName']} (${fromUser['username']}) has invited you to ${community['name']} (${community['alias']}) on Woven.

Please go to this link to accept the invitation:

$confirmLink

--
Woven
http://woven.co
''';
    Mailgun.send(envelope);

    // Save the confirmation hash to an index.
    Firebase.put('/email_confirmation_index/$hash.json', data,
        auth: config['datastore']['firebaseSecret']);

    var response = new Response();
    response.success = true;
    return respond(response);
  }
}
