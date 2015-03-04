library main_controller;

import 'dart:io';
import 'dart:async';
import '../app.dart';
import '../firebase.dart';
import 'package:woven/src/shared/response.dart';
import 'package:woven/config/config.dart';
import '../mailer/mailer.dart';
import 'package:woven/src/shared/shared_util.dart';
import 'package:woven/src/server/util/crawler_util.dart';
import 'dart:convert';
import 'package:woven/src/shared/model/uri_preview.dart';
import 'package:woven/src/server/model/item.dart';
import '../util/file_util.dart';
import '../util/image_util.dart';
import 'package:path/path.dart' as path;
import '../util.dart';
import 'package:woven/src/shared/regex.dart';

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
    var sessionCookie = request.cookies.firstWhere((cookie) => cookie.name == 'session', orElse: () => null);
    if (sessionCookie == null) return Response.fromError('No session cookie found.');
    if (sessionCookie.value == null) return Response.fromError('The id in the session cookie was null.');

    var sessionId = sessionCookie.value;

    Future findUser(String username) => Firebase.get('/users/$username.json');
    Future findSession(String sessionId) => Firebase.get('/session_index/$sessionId.json');
    Future findUsernameFromSession(String sessionId) => Firebase.get('/session_index/$sessionId/username.json');
    Future findUsernameFromFacebookIndex(String facebookId) => Firebase.get('/facebook_index/$facebookId/username.json');

    // Check the session index for the user associated with this session id.
    return findUsernameFromSession(sessionId).then((String username) {
      if (username == null) {
        // The user may have an old cookie, with Facebook ID, so let's check that index.
        return findUsernameFromFacebookIndex(sessionId).then((String username) {
          if (username == null) return null;
          // Update the old cookie to use a newer session ID, and add it to our session index.
          var newSessionId = app.sessionManager.createSessionId();
          app.sessionManager.addSessionCookieToRequest(request, newSessionId);
          app.authToken = generateFirebaseToken({'uid': username});
          app.sessionManager.addSessionToIndex(newSessionId, username, app.authToken);
          return username;
        });
      }
      return username;
    }).then((String username) {
      if (username == null) return Response.fromError('A user associated with that session id was not found.');
      // Generate a Firebase authentication token for this user.
      app.authToken = generateFirebaseToken({'uid': username});
      // Get the user data.
      return findUser(username).then((Map userData) {
        userData['auth_token'] = app.authToken;
        var response = new Response();
        response.data = userData;
        return response;
      });
    });
  }

  static aliasExists(String alias) {
    Firebase.get('/alias_index/$alias.json').then((res) {
      return (res == null ? false : true);
    });
  }

  /**
   * Crawl for and get a preview for a given uri/link.
   */
  static addItem(App app, HttpRequest req) {
//    HttpResponse res = req.response;
//    req.listen((List<int> buffer) {
//      // Return the data back to the client.
//      var response = new Response();
//      response.data = new String.fromCharCodes(buffer);
//      return 'Here it is: ' + response;
//    });
  }

  /**
   * Crawl for and get a preview for a given uri/link.
   */
  static addMessage(App app, HttpRequest req) {
    HttpResponse res = req.response;
    String dataReceived;

    return req.listen((List<int> buffer) {
      dataReceived = new String.fromCharCodes(buffer);
    }).asFuture().then((_) {
      Map data = JSON.decode(dataReceived);
      Map message = {};
      String community = data['community'];

      // Use the server's UTC time.
      DateTime now = new DateTime.now().toUtc();
      data['createdDate'] = now.toString();

      // Do some things with the data before saving.
      data['.priority'] = -now.millisecondsSinceEpoch;
      Map fullData = new Map.from(data);
      data.remove('community');

      // Add some additional stuff which we store in the main /messsages location.
      // TODO: Later, we can add more parent communities here.
      fullData['communities'] = {community: true};

      // Add the message.
      return Firebase.post('/messages_by_community/$community.json', JSON.encode(data), app.authToken).then((String name) {
        Firebase.patch('/communities/$community.json', {'updatedDate': now.toString()}, app.authToken);
        Firebase.put('/messages/$name.json', fullData, app.authToken).then((_) {
          // Send a notification email to anybody mentioned in the message.
          fullData['id'] = name;
          _sendNotifications('message', fullData, app);
        });

        // Return the data back to the client.
        var response = new Response();
        response.data = name;
        response.success = true;
        return response;
      });
    });
  }

  /**
   * Crawl for and get a preview for a given uri/link.
   */
  static getUriPreview(App app, HttpRequest request) {
    var item = request.requestedUri.queryParameters['itemid'];
    var crawler = new CrawlerUtil();

    return Firebase.get('/items/$item.json').then((Map itemMap) {
      String uri = itemMap['url'];
      // Crawl for some data.
      return crawler.getPreview(Uri.parse(uri)).then((Response res) {
        if (res.success == false) return Response.fromError('Could not fetch from that URL.');

        UriPreview preview = UriPreview.fromJson(res.data);
        var response = new Response();
        if (preview.imageOriginalUrl == null) {
          // Save the preview.
          return Firebase.post('/uri_previews.json', preview.toJson(), app.authToken).then((String name) {
            Map updates = {};
            updates['uriPreviewId'] = name;

            // If no subject/body, use preview's title/teaser.
            if (itemMap['subject'] == null) updates['subject'] = preview.title;
            if (itemMap['body'] == null) updates['body'] = preview.teaser;

            // Update the item with a reference to the preview.
            ItemModel.update(item, updates, app.authToken);

            // Return the preview information.
            response.data = preview;
            return response;
          });
        } else {
          // Resize and save a small preview image.
          ImageUtil imageUtil = new ImageUtil();
          // Set up a temporary file to write to.
          return createTemporaryFile().then((File file) {
            // Download the image locally to our temporary file.
            return downloadFileTo(preview.imageOriginalUrl, file).then((_) {
              // Resize the image.
              return imageUtil.resize(file, width: 225, height: 125).then((File convertedFile) {
                // Save the preview.
                return Firebase.post('/uri_previews.json', preview.toJson(), app.authToken).then((String name) {
                  Map updates = {};
                  updates['uriPreviewId'] = name;
                  if (itemMap['subject'] == null) updates['subject'] = preview.title;
                  if (itemMap['body'] == null) updates['body'] = preview.teaser;

                  // Update the item with a reference to the preview.
                  ItemModel.update(item, updates, app.authToken);

                  // Convert and save the image.
                  var extension = path.extension(preview.imageOriginalUrl.toString()).split("?")[0];
                  var filename = 'preview_small$extension';
                  var gsBucket = 'woven';
                  var gsPath = 'public/images/preview/$name/$filename';

                  // Then upload the image to our filesystem.
                  return app.cloudStorageUtil.uploadFile(convertedFile.path, gsBucket, gsPath, public: true).then((_) {
                    return file.delete().then((_) {
                      // Update the preview with a reference to the cloud file.
                      preview.imageSmallLocation = gsPath;
                      Firebase.patch('/uri_previews/$name.json', JSON.encode(preview.toJson()), app.authToken);
                      // Return the preview information.
                      response.data = preview;
                      return response;
                    });
                  });
                });
              });
            });
          });
        }
      });
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
          ..from = "Woven <hello@woven.co>"
          ..to = ['${userData['firstName']} ${userData['lastName']} <${userData['email']}>']
          ..bcc = ['David Notik <davenotik@gmail.com>']
          ..subject = 'Welcome, ${userData['firstName']}!'
          ..text = '''
Hey ${userData['firstName']},

Thank you for creating an account on the new Woven.

Beyond social networking, this is collaborative networking. Woven is being designed from the ground up to help us coordinate our actions to improve the world.

Here's a manifesto of sorts: http://woven.co/item/LUpZTWEtZWZOejRFRklYVTYxWmY=

The new Woven is starting simple and getting better every day.

Please take a moment to respond to me with your first impressions, good or bad. Please share all your feedback on the Early Adopters community on Woven as well.

And you can always call or text me on my mobile at 206-351-3948 – at any time.

Thank you for your early support!

--David Notik

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
    _sendNotifications('item', data, app);
  }

  static sendNotificationsForComment(App app, HttpRequest request) {
    Map data = request.requestedUri.queryParameters;
    _sendNotifications('comment', data, app);
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
  static _sendNotifications(type, Map data, App app) {
    bool isItem = (type == 'item') ? true : false;
    bool isComment = (type == 'comment') ? true : false;
    bool isMessage = (type == 'message') ? true : false;
    var id = data['id']; // The id of the item/comment/message we're notifying about.
    var item = (type == 'item') ? id : data['itemid']; // If this isn't an item, we still might have/need the item id.

    Map notificationData = {};

    Future findItem() {
      return Firebase.get('/items/$item.json').then((itemData) {
        notificationData['itemSubject'] = itemData['subject'];
        notificationData['itemAuthor'] = itemData['user'];
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
        notificationData['commentAuthor'] = commentData['user'];
      });
    }

    Future findMessage() {
      return Firebase.get('/messages/$id.json').then((messageData) {
        notificationData['message'] = messageData['message'];
        notificationData['messageAuthor'] = messageData['user'];
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
      .then((_) => Future.wait([findItemAuthorInfo]))
      .then(notify).catchError((error, stack) => print("Error in notify:\n$error\n\nStack trace:\n$stack"))
      .then((success) => new Response(success))
      .catchError((error) => print("Error sending notifications: $error"));
    }
    if (isComment) {
      return findItem()
      .then((_) => Future.wait([findItemAuthorInfo, findCommentInfo()]))
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

    mentions.forEach((user) {
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
}