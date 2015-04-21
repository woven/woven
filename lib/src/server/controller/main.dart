library main_controller;

import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as path;

import 'mail.dart';
import '../app.dart';
import '../firebase.dart';
import '../util/file_util.dart';
import '../util/image_util.dart';
import 'package:woven/src/shared/response.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/server/util/crawler_util.dart';
import 'package:woven/src/shared/model/uri_preview.dart';
import 'package:woven/src/server/model/item.dart';

class MainController {
  static serveApp(App app, HttpRequest request, [String path]) {
    return new File(config['server']['directory'] + '/index.html');
  }

  static serveHome(App app, HttpRequest request, [String path]) {
    // If there's an existing session cookie, use it. Else, create a new session id.
    var sessionCookie = request.cookies.firstWhere((cookie) => cookie.name == 'session', orElse: () => null);
    String sessionId = (sessionCookie == null || sessionCookie.value == null) ? null : sessionCookie.value;

    if (sessionId != null) {
      Future checkIfSessionExists = sessionExists(sessionId);
      return checkIfSessionExists.then((res) {
        if (res == false) request.response.headers.add(HttpHeaders.CACHE_CONTROL, "no-cache, no-store, must-revalidate");
        return new File(config['server']['directory'] + (res == true ? '/index.html' : '/home.html'));
      });
    } else {
      request.response.headers.add(HttpHeaders.CACHE_CONTROL, "no-cache, no-store, must-revalidate");
      return new File(config['server']['directory'] + '/home.html');
    }
  }

  static confirmEmail(App app, HttpRequest request, String confirmId) {
    // Kill any existing session since the user appears to be signing up again.
    app.sessionManager.deleteCookie(request);

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

  static aliasExists(String alias) {
    Firebase.get('/alias_index/$alias.json').then((res) {
      return (res == null ? false : true);
    });
  }

  static sessionExists(String sessionId) {
    if (sessionId == null) return false;

    return Firebase.get('/session_index/$sessionId.json').then((res) {
      return (res == null ? false : true);
    });
  }

  /**
   * Crawl for and get a preview for a given uri/link.
   */
  static addItem(App app, HttpRequest req) {
    HttpResponse res = req.response;
    String dataReceived;

    return req.listen((List<int> buffer) {
      dataReceived = new String.fromCharCodes(buffer);
    }).asFuture().then((_) {
      Map data = JSON.decode(dataReceived);
      Map item = {};
      String community = data['community'];
      String authToken = data['authToken'];
    });
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
      String authToken = data['authToken'];
      Map message = data['model'];
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

      // Add some additional stuff which we store in the main /messsages location.
      // TODO: Later, we can add more parent communities here.
      fullData['communities'] = {community: true};

      // Add the message.
      return Firebase.post('/messages_by_community/$community.json', JSON.encode(message), auth: authToken).then((String name) {
        Firebase.patch('/communities/$community.json', {'updatedDate': now.toString()}, auth: authToken);
        Firebase.put('/messages/$name.json', fullData, auth: authToken).then((_) {
          // Send a notification email to anybody mentioned in the message.
          fullData['id'] = name;
          MailController.sendNotifications('message', fullData, app);
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
    HttpResponse response = request.response;
    String dataReceived;

    return request.listen((List<int> buffer) {
      dataReceived = new String.fromCharCodes(buffer);
    }).asFuture().then((_) {
      Map data = JSON.decode(dataReceived);
      String itemId = data['itemId'];
      String authToken = data['authToken'];

      var crawler = new CrawlerUtil();

      return Firebase.get('/items/$itemId.json').then((Map itemMap) {
        String uri = itemMap['url'];
        // Crawl for some data.
        return crawler.getPreview(Uri.parse(uri)).then((Response res) {
          if (res.success == false) return Response.fromError('Could not fetch from that URL.');

          UriPreview preview = UriPreview.fromJson(res.data);
          var response = new Response();
          if (preview.imageOriginalUrl == null || preview.imageOriginalUrl.isEmpty) {
            // Save the preview.
            return Firebase.post('/uri_previews.json', preview.toJson(), auth: authToken).then((String name) {
              Map updates = {};
              updates['uriPreviewId'] = name;

              // If no subject/body, use preview's title/teaser.
              if (itemMap['subject'] == null) updates['subject'] = preview.title;
              if (itemMap['body'] == null) updates['body'] = preview.teaser;

              // Update the item with a reference to the preview.
              ItemModel.update(itemId, updates, authToken);

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
                  return Firebase.post('/uri_previews.json', preview.toJson(), auth: authToken).then((String name) {
                    Map updates = {};
                    updates['uriPreviewId'] = name;
                    if (itemMap['subject'] == null) updates['subject'] = preview.title;
                    if (itemMap['body'] == null) updates['body'] = preview.teaser;

                    // Update the item with a reference to the preview.
                    ItemModel.update(itemId, updates, authToken);

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
                        Firebase.patch('/uri_previews/$name.json', JSON.encode(preview.toJson()), auth: authToken);
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
    });
  }
}