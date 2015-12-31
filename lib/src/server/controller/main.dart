library main_controller;

import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart' as shelf;

import 'mail.dart';
import '../app.dart';
import '../firebase.dart';
import '../util/file_util.dart';
import '../util/image_util.dart';

import 'package:woven/config/config.dart';
import 'package:woven/src/shared/response.dart';
import 'package:woven/src/server/crawler/crawler.dart';
import 'package:woven/src/server/crawler/crawl_info.dart';
import 'package:woven/src/server/crawler/image_info.dart';
import 'package:woven/src/shared/model/uri_preview.dart';
import 'package:woven/src/server/model/item.dart';
import 'package:woven/src/server/util.dart';

class MainController {
  static serveApp(App app, shelf.Request request, [String path]) {
    return app.staticHandler(
        new shelf.Request('GET', Uri.parse(app.serverPath + '/')));
  }

  static confirmEmail(App app, shelf.Request request, String confirmId) {
    return app.staticHandler(
        new shelf.Request('GET', Uri.parse(app.serverPath + '/')));
  }

  static showItem(App app, shelf.Request request, String item) {
    // Serve the app as usual, and client router will handle showing the item.
    return app.staticHandler(
        new shelf.Request('GET', Uri.parse(app.serverPath + '/')));
  }

  /**
   * Add an item.
   */
  static addItem(App app, shelf.Request request) async {
    Map data = JSON.decode(await request.readAsString());

    Map item = {};

    String community = data['community'];
    String authToken = data['authToken'];

    //TODO: In progress making add item server side.
  }

  /**
   * Add an item.
   */
  static deleteItem(App app, shelf.Request request) async {
    Map data = JSON.decode(await request.readAsString());

    Map item = {};

    // TODO: Allow delete per community. It deletes everywhere right now.
    String id = data['id'];

    // TODO: Switch to more nuanced auth later.
    String authToken = config['datastore']['firebaseSecret'];

    Item.delete(id, authToken);

    var response = new Response();
    response.success = true;

    return respond(response);
  }

  /**
   * Add a chat message.
   */
  static addMessage(App app, shelf.Request request) async {
    Map data = JSON.decode(await request.readAsString());
    Map message = data['model'];
    String authToken = data['authToken'];
    String community = message['community'];

    // Do some pre-processing of the data.
    DateTime now = new DateTime.now().toUtc(); // Use the server's UTC time.
    message['createdDate'] = now.toString();
    message['updatedDate'] = now.toString();
    message['user'] = (message['user'] as String).toLowerCase();

    // Do some things with the data before saving.
    message['.priority'] = -now.millisecondsSinceEpoch;
    Map fullData = new Map.from(message);
    message.remove('community');

    // Add some additional stuff which we store in the main /messages location.
    // TODO: Later, we can add more parent communities here.
    fullData['communities'] = {community: true};

    // Add the message.
    String messageId = await Firebase.post(
        '/messages_by_community/$community.json', JSON.encode(message),
        auth: authToken);
    Firebase.patch(
        '/communities/$community.json', {'updatedDate': now.toString()},
        auth: authToken);
    await Firebase.put('/messages/$messageId.json', fullData, auth: authToken);

    // Send a notification email to anybody mentioned in the message.
    fullData['id'] = messageId;
    MailController.sendNotifications('message', fullData, app);

    // Return the data back to the client.
    var response = new Response();
    response.data = messageId;
    response.success = true;

    return respond(response);
  }

  /**
   * Add a comment on an item.
   */
  static addComment(App app, shelf.Request request) async {
    Map data = JSON.decode(await request.readAsString());
    String authToken = data['authToken'];
    Map comment = data['model'];
    String itemId = comment['itemId'];

    // Do some pre-processing of the data.
    DateTime now = new DateTime.now().toUtc(); // Use the server's UTC time.
    comment['createdDate'] = now.toString();
    comment['updatedDate'] = now.toString();
    comment['user'] = (comment['user'] as String).toLowerCase();

    // Do some things with the data before saving.
    comment['_priority'] = -now.millisecondsSinceEpoch;
    Map fullData = new Map.from(comment);

    // Add the comment.
    String name = await Firebase.post(
        '/items/$itemId/activities/comments.json', JSON.encode(comment),
        auth: authToken);

    // Update the parent item.
    Firebase.patch('/items/$itemId/updatedDate.json', now.toString(),
        auth: authToken);

    // TODO: Patch the comment_count.
    // http://stackoverflow.com/questions/23041800/firebase-transactions-via-rest-api

    // Get some details from the parent item.
    Map communities = await Firebase.get('/items/$itemId/communities.json');
    Map type = await Firebase.get('/items/$itemId/type.json');

    // Loop over and update multiple copies of the item.
    var updateData = {
      'updatedDate': now.toString(),
      '_priority': -now.millisecondsSinceEpoch
    };
    communities.keys.forEach((community) {
      Firebase.patch('/items_by_community/$community/$itemId.json', updateData,
          auth: authToken);
      Firebase.patch(
          '/items_by_community_by_type/$community/$type/$itemId.json',
          updateData,
          auth: authToken);
      Firebase.patch('/communities/$community.json', updateData,
          auth: authToken);
    });

    // Send a notification email to anybody mentioned in the message.
    fullData['id'] = name;
    MailController.sendNotifications('comment', fullData, app);

    // Return the data back to the client.
    var response = new Response();
    response.data = name;
    response.success = true;

    return respond(response);
  }

  /**
   * Crawl for and get a preview for a given uri/link.
   */
  static getUriPreview(App app, shelf.Request request) async {
    Map data = JSON.decode(await request.readAsString());
    String itemId = data['itemId'];
    String authToken = data['authToken'];

    Map itemMap = await Firebase.get('/items/$itemId.json');

    String uri = itemMap['url'];

    var crawler = new Crawler(uri);

    // Crawl for some data.
    CrawlInfo crawlInfo = await crawler.crawl();

//    if (getPreview.success == false) return respond(
//        Response.fromError('Could not fetch from that URL.'),
//        statusCode: 404);

    ImageInfo bestImage = crawlInfo.bestImage;

    Response response = new Response();
    response.success = true;

    // Build a preview.
    UriPreview uriPreview = new UriPreview(uri: Uri.parse(uri));
    uriPreview
      ..title = crawlInfo.title
      ..teaser = crawlInfo.teaser;

    if (bestImage.url == null) {
      // Save the preview.
      String uriPreviewId = await Firebase
          .post('/uri_previews.json', uriPreview.toJson(), auth: authToken);
      Map updates = {};
      updates['uriPreviewId'] = uriPreviewId;

      // If no subject/body, use preview's title/teaser.
      if (itemMap['subject'] == null) updates['subject'] = uriPreview.title;
      if (itemMap['body'] == null) updates['body'] = uriPreview.teaser;

      // Update the item with a reference to the preview.
      Item.update(itemId, updates, authToken);

      // Return the preview information.
      response.data = uriPreview.toJson();
      return respond(response);
    } else {
      // Download the image locally to our temporary file.
      ImageInfo image = crawlInfo.bestImage;
      File imageFile = await downloadFileTo(
          image.url, await createTemporaryFile(suffix: '.' + image.extension));

      var imageUtil = new ImageUtil();
      File croppedFile =
          await imageUtil.resize(imageFile, width: 245, height: 120);

      // Save the preview.
      String uriPreviewId = await Firebase
          .post('/uri_previews.json', uriPreview.toJson(), auth: authToken);
      Map updates = {};
      updates['uriPreviewId'] = uriPreviewId;

      // If no subject/body, use preview's title/teaser.
      if (itemMap['subject'] == null) updates['subject'] = uriPreview.title;
      if (itemMap['body'] == null) updates['body'] = uriPreview.teaser;

      // Update the item with a reference to the preview.
      Item.update(itemId, updates, authToken);

      var extension = image.extension;
      var gsBucket = config['google']['cloudStorage']['bucket'];
      var gsPath = 'public/images/item/$itemId';

      var filename = 'main-photo.$extension';
      var cloudStorageResponse = await app.cloudStorageUtil.uploadFile(
          croppedFile.path, gsBucket, '$gsPath/$filename',
          public: true);

      // Update the preview with a reference to the cloud file.
      uriPreview.imageSmallLocation = cloudStorageResponse.name;
      Firebase.patch(
          '/uri_previews/$uriPreviewId.json', JSON.encode(uriPreview.toJson()),
          auth: authToken);

      imageFile.delete();
      croppedFile.delete();

      // Return the preview information.
      response.data = uriPreview.toJson();
      return respond(response);
    }
  }

  static aliasExists(String alias) async {
    var checkForAlias = await Firebase.get('/alias_index/$alias.json');
    return (checkForAlias == null ? false : true);
  }

  static sessionExists(String sessionId) async {
    if (sessionId == null) return false;

    var checkForSessionId =
        await Firebase.get('/session_index/$sessionId.json');
    return (checkForSessionId == null ? false : true);
  }
}
