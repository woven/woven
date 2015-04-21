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
final firebaseSecret = 'uY8p08LpEK6eF8JnB1ijFPdLQOoNpeJEgQEFJ3cI';

main() async {
//  updateAllItemsMoveOtherToMessages();
//  try {
//    await createPreviewForItemsWithUrls();
//  } catch(error) {
//    print('MAIN: $error');
//  }
//  moveItemsFromAtoB();
//changeAllUsersToLowercase();
//migrateAllUsersOnboardingState();
//  changeAllUsersDateToEpochFormat();
//  dumpDataToFile();
doMigration();
}

/**
 * Do ONE AT A TIME. See individual comments.
 */
doMigration() async {
//  changeAllUsersToLowercase();
//  updateAllUsersAddPriority();
//  migrateAllUsersOnboardingState();
  updateAllItemsMoveOtherToMessages();
//
//  try {
//    await createPreviewForItemsWithUrls();
//  } catch(error) {
//    print('MIGRATION: $error');
//  }
}

changeAllUsersToLowercase() {
  Firebase.get('/users.json?format=export').then((Map users) {
    users.forEach((k, v) {
      String username = k;
      Firebase.put('/users2/${username.toLowerCase()}.json', v);
      print(username);
    });
  });
}

dumpDataToFile() {
  Firebase.get('/.json?format=export&print=pretty').then((data) {
    String now = new DateTime.now().toString();
    File file = new File('firebase_dump_$now.json');
    file.writeAsString(data);
  });
}

updateAllUsersAddPriority() {
  Firebase.get('/users.json').then((Map users) {
    users.forEach((k, v) {
      String username = k;
      v['_priority'] = (v['createdDate'] != null) ? -DateTime.parse(v['createdDate']).millisecondsSinceEpoch : null;
      Firebase.put('/users/${username.toLowerCase()}.json', v);
      print(username);
    });
  });
}

migrateAllUsersOnboardingState() {
  var updateData;
  Firebase.get('/users.json').then((Map users) {
    users.forEach((k, v) {
      String username = k;
      if (v['disabled']) return;

      if (v['password'] == null || v['firstName'] == null || v['lastName'] == null) {
        updateData = {'onboardingState': 'signUpIncomplete'};
      } else {
        updateData = {'onboardingState': 'signUpComplete'};
      }
      Firebase.patch('/users/${username.toLowerCase()}.json', updateData);
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
          }, firebaseSecret);
          print(item['id']);
        }
      });
    });
  });
}

/**
 * Move items from locationA to locationB, only when it does *not* already exist in locationB.
 */
moveItemsFromAtoB() async {
  Map items = await Firebase.get('/itemsA.json');
  List itemsAsList = [];
  items.forEach((k,v) {
    Map item = v;
    item['id'] = k;
    itemsAsList.add(item);
  });

  Future.forEach(itemsAsList,(Map item) async {
//    new Future.delayed(const Duration(seconds: 1), () async {
      var itemExists = await Firebase.get('/items/${item['id']}.json');
      if (itemExists == null) return;
      await Firebase.put('/items/${item['id']}.json', item, auth: firebaseSecret);
      print('Updated ${item['id']}: ${item['subject']}');
//    });
  });
}

createPreviewForItemsWithUrls() async {
  CrawlerUtil crawler = new CrawlerUtil();
  CloudStorageUtil cloudStorageUtil;

  googleApiClient = await auth.clientViaServiceAccount(googleServiceAccountCredentials, googleApiScopes);
  cloudStorageUtil = new CloudStorageUtil(googleApiClient);

  Map items = await Firebase.get('/items.json');

  try {
    items.forEach((k, v) async {
      Map item = v;
      item['id'] = k;

      if (item['url'] != null && isValidUrl(item['url'])) {
        String uri = item['url'];

        Response crawl;
        // Crawl for some data.
        try {
          crawl = await crawler.getPreview(Uri.parse(uri));
        } catch (error) {
          print('CRAWLER: $error');
        }

        if (crawl.success == false) {
          print('FAILED:\n ${crawl.message}');
          return;
        }

        UriPreview preview = UriPreview.fromJson(crawl.data);

        if (preview.imageOriginalUrl == null || !isValidUrl(preview.imageOriginalUrl)) {
          // Save the preview.
          var name;
          try {
            name = await Firebase.post('/uri_previews.json', preview.toJson(), auth: firebaseSecret);
          } catch (error) {
            print('DEBUG1: $error');
          }
          Map updates = {
          };
          updates['uriPreviewId'] = name;
          if (item['subject'] == null) updates['subject'] = preview.title;
          if (item['body'] == null) updates['body'] = preview.teaser;
          // Update the item with a reference to the preview.
          await ItemModel.update(item['id'], updates, firebaseSecret);

        } else {
          // Resize and save a small preview image.
          ImageUtil imageUtil = new ImageUtil();

          // Set up a temporary file to write to.
          File file = await createTemporaryFile();

          // Download the image locally to our temporary file.
          try {
            await downloadFileTo(preview.imageOriginalUrl, file);
          } catch (error) {
            print('CAUGHT:\n $error');
          }

          // Resize the image.
          File convertedFile = await imageUtil.resize(file, width: 225, height: 125);

          // Save the preview.
          String name;
          try {
            name = await Firebase.post('/uri_previews.json', preview.toJson(), auth: firebaseSecret);
          } catch (error) {
            print('DEBUG2: $error');
          }


          Map updates = {
          };
          updates['uriPreviewId'] = name;
          if (item['subject'] == null) updates['subject'] = preview.title;
          if (item['body'] == null) updates['body'] = preview.teaser;

          // Update the item with a reference to the preview.
          try {
            await ItemModel.update(item['id'], updates, firebaseSecret);
          } catch (error) {
            print('DEBUG3: $error');
          }

          // Convert and save the image.
          var extension = path.extension(preview.imageOriginalUrl.toString()).split("?")[0];
          var filename = 'preview_small$extension';
          var gsBucket = 'woven';
          var gsPath = 'public/images/preview/$name/$filename';

          // Then upload the image to our filesystem and delete the temporary file.
          try {
            await cloudStorageUtil.uploadFile(convertedFile.path, gsBucket, gsPath, public: true);
          } catch (error) {
            print('DEBUG4: $error');
          }
          await file.delete();

          // Update the preview with a reference to the cloud file.
          preview.imageSmallLocation = gsPath;
          try {
            await Firebase.patch('/uri_previews/$name.json', JSON.encode(preview.toJson()), auth: firebaseSecret);
          } catch (error) {
            print('FIREBASE ERROR: $error');
          }
        }
      }
    });
  } catch (error) {
    print('FUNC: $error');
  }
}