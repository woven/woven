import 'package:woven/src/server/model/item.dart';
import 'package:woven/src/server/firebase.dart';
import 'package:woven/config/config.dart';
import 'dart:io';
import 'dart:async';
import 'package:woven/src/server/util/crawler_util.dart';
import 'dart:convert';
import 'package:woven/src/shared/model/uri_preview.dart';
import 'package:woven/src/server/util/file_util.dart';
import 'package:woven/src/server/util/image_util.dart';
import 'package:woven/src/server/util/cloud_storage_util.dart';
import 'package:woven/src/shared/shared_util.dart';
import 'package:path/path.dart' as path;
import 'package:woven/src/server/app.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:googleapis/storage/v1.dart' as storage;
import 'package:googleapis/common/common.dart' show DownloadOptions, Media;
import 'package:woven/src/shared/response.dart';


final googleServiceAccountCredentials = new auth.ServiceAccountCredentials.fromJson(config['google']['serviceAccountCredentials']);
final googleApiScopes = [storage.StorageApi.DevstorageFullControlScope];
var googleApiClient;

main() {
//  updateAllItemsMoveOtherToMessages();
//  createPreviewForItemsWithUrls();
changeAllUsersToLowercase();
}

changeAllUsersToLowercase() {
  Firebase.get('/users2.json?format=export').then((Map users) {
    users.forEach((k, v) {
      String username = k;
      Firebase.put('/users/${username.toLowerCase()}.json', v);
      print(username);
    });
  });
}

updateAllItemsMoveOtherToMessages() {
  Firebase.get('/items.json').then((Map items) {
    List itemsAsList = [];
    items.forEach((k,v) {
      Map item = v;
      item['id'] = k;
      itemsAsList.add(item);
    });

    Future.forEach(itemsAsList,(Map item) {
      new Future.delayed(const Duration(seconds: 1), () {
        if (item['type'] != 'event' && item['type'] != 'news') {
          ItemModel.update(item['id'], {
              'message': item['body']
          });
          print(item['id']);
        }
      });
    });
  });
}

createPreviewForItemsWithUrls() {



  CrawlerUtil crawler = new CrawlerUtil();
  CloudStorageUtil cloudStorageUtil;

  auth.clientViaServiceAccount(googleServiceAccountCredentials, googleApiScopes).then((client) {
    googleApiClient = client;
    cloudStorageUtil = new CloudStorageUtil(googleApiClient);
  });

  Firebase.get('/items.json').then((Map items) {
    List itemsAsList = [];
    items.forEach((k,v) {
      Map item = v;
      item['id'] = k;
      itemsAsList.add(item);
    });

    Future.forEach(itemsAsList,(Map item) {
      new Future.delayed(const Duration(seconds: 1), () {
        if (item['url'] != null && isValidUrl(item['url']) && item['uriPreviewId'] == null) {
          String uri = item['url'];

          // Crawl for some data.
          return crawler.getPreview(Uri.parse(uri)).then((Response res) {
            if (res.success == false) return Response.fromError('Could not fetch from that URL.');

            UriPreview preview = UriPreview.fromJson(res.data);

            if (preview.imageOriginalUrl == null || !isValidUrl(preview.imageOriginalUrl)) {
              // Save the preview.
              return Firebase.post('/uri_previews.json', preview.toJson()).then((String name) {
                Map updates = {};
                updates['uriPreviewId'] = name;
                if (item['subject'] == null) updates['subject'] = preview.title;
                if (item['body'] == null) updates['body'] = preview.teaser;

                print(updates);

                // Update the item with a reference to the preview.
                ItemModel.update(item['id'], updates);
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
                    return Firebase.post('/uri_previews.json', preview.toJson()).then((String name) {
                      Map updates = {};
                      updates['uriPreviewId'] = name;
                      if (item['subject'] == null) updates['subject'] = preview.title;
                      if (item['body'] == null) updates['body'] = preview.teaser;

                      // Update the item with a reference to the preview.
                      ItemModel.update(item['id'], updates);

                      // Convert and save the image.
                      var extension = path.extension(preview.imageOriginalUrl.toString()).split("?")[0];
                      var filename = 'preview_small$extension';
                      var gsBucket = 'woven';
                      var gsPath = 'public/images/preview/$name/$filename';

                      // Then upload the image to our filesystem.
                      return cloudStorageUtil.uploadFile(convertedFile.path, gsBucket, gsPath, public: true).then((_) {
                        return file.delete().then((_) {
                          // Update the preview with a reference to the cloud file.
                          preview.imageSmallLocation = gsPath;
                          return Firebase.patch('/uri_previews/$name.json', JSON.encode(preview.toJson()));
                        });
                      });
                    });
                  });
                });
              });
            }
          });
        }
      });
    });
  });
}