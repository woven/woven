library tool.main;

import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:woven/src/server/app.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:googleapis/storage/v1.dart' as storage;
import 'package:googleapis/common/common.dart' show DownloadOptions, Media;

import 'package:woven/config/config.dart';
import 'package:woven/src/server/util/crawler_util.dart';
import 'package:woven/src/server/firebase.dart';
import 'package:woven/src/server/model/post.dart';
import 'package:woven/src/shared/model/uri_preview.dart';
import 'package:woven/src/server/util/file_util.dart';
import 'package:woven/src/server/util/image_util.dart';
import 'package:woven/src/server/util/cloud_storage_util.dart';
import 'package:woven/src/shared/shared_util.dart';

import 'package:woven/src/shared/response.dart';
import 'package:woven/src/server/mail_sender.dart';

final googleServiceAccountCredentials = new auth.ServiceAccountCredentials.fromJson(config['google']['serviceAccountCredentials']);
final googleApiScopes = [storage.StorageApi.DevstorageFullControlScope];
var googleApiClient;
final firebaseSecret = config['datastore']['firebaseSecret'];

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
//  createEmailIndex();
//  fixItemsNotProperlyDuplicated2();

//  dumpDataToFile();
//  doMigration();
//updateAllUsersAddPriority();
updateAllMessagesAddPriority();
//  getAllUsersMissingPassword();
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
      Firebase.patch('/users/${username.toLowerCase()}.json', v);
      print(username);
    });
  });
}

updateAllMessagesAddPriority() {
  int count = 0;
  Firebase.get('/messages_by_community.json').then((Map communities) {
    print(communities);
    communities.forEach((k, v) {
      String community = k;
      Map messagesInCommunity = v;
      messagesInCommunity.forEach((k, v) {
        count++;
        String messageId = k;
        v['_priority2'] = (v['createdDate'] != null) ? DateTime.parse(v['createdDate']).millisecondsSinceEpoch : null;
        new Timer(new Duration(milliseconds: count * 100), () {
          Firebase.patch('/messages_by_community2/$community/$messageId.json', v, auth: firebaseSecret);
          print('$community/$messageId');
        });
      });
    });
  });
}

getAllUsersMissingPassword() async {
  Map users = await Firebase.get('/users.json');
  print(users.length);
  return;
  users.forEach((k, v) {
    Map user = v;
    if (user['onboardingState'] == 'signUpComplete' && user['password'] == null) {
      Firebase.delete('/users/${user['username'].toLowerCase()}.json');
      print('$k: ${user['disabled']}');
//      MailSender.sendFixPasswordEmail(user['username']);
    }
  });
}

createEmailIndex() {
  Firebase.get('/users.json').then((Map users) {
    users.forEach((k, v) {
      var user = k;
      String email = v['email'];
      if (email == null || email.isEmpty) return;
      Firebase.put('/email_index/${encodeFirebaseKey(email.toLowerCase())}.json', {'user': user, 'email': email.toLowerCase()});
    });
  });
}

/**
 * Can be used to update child usernames like at users_who_starred/item/someitem/dave.
 * Modify as appropriate.
 */
updateUsersWhoStarredAndRelated() async {
  String location = "starred_by_user";
  Map query = await Firebase.get('/$location.json');
  query.forEach((k, v) {
    String parent = k;
    Map children = v;
    children.forEach((k, v) {
      String item = k;
      Map finalChildren = v;
      finalChildren.forEach((k, v) async {
        String finalChild = k;
        await Firebase.delete('/$location/$parent/$item/${finalChild}.json');
        Firebase.put('/$location/${parent.toLowerCase()}/$item/$finalChild.json', v);
        print(finalChild);
      });
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
          Post.update(item['id'], {
              'message': item['body']
          }, firebaseSecret);
          print(item['id']);
        }
      });
    });
  });
}

/**
 * Fix items that exist in /items but not properly duplicated to /items_by*.
 */
fixItemsNotProperlyDuplicated() async {
  Map items = await Firebase.get('/items.json?format=export');
  List itemsAsList = [];
  int count = 0;
  items.forEach((k, v) {
    Map item = v;
    item['id'] = k;
    Map communities = item['communities'];
    if (communities == null) {
      print('NULL FOUND: ' + item['id']);
      return;
    }
    communities.keys.forEach((community) async {
      Map itemsBy = await Firebase.get('/items_by_community_by_type/$community/${item['type']}/${item['id']}.json');
      print(itemsBy);
      return;
      if (itemsBy == null) {
        count++;
        var priority = item['.priority'].toString();
        priority = priority.replaceAll('.0', '');
        item['.priority'] = priority;

        if (item['type'] == 'event') {
          var startPriority = DateTime.parse(item['startDateTime']).millisecondsSinceEpoch;
          item['startDateTimePriority'] = startPriority;
          print(item['startDateTimePriority']);
        }

//        print(count.toString() + ': ' + item['id'] + ' / ' + item['.priority'].toString() + ' / ' + item['startDateTimePriority'].toString());

        Map itemToSave = new Map.from(item);
        itemToSave.remove('communities');
        itemToSave.remove('activities');
        itemToSave.remove('id');
        //Firebase.put('/items_by_community_by_type/$community/${item['type']}/${item['id']}.json', itemToSave, auth: firebaseSecret);
      }
    });
  });
}

/**
 * Fix items that exist in /items but not properly duplicated to /items_by*.
 */
fixItemsNotProperlyDuplicated2() async {
  Map items = await Firebase.get('/items.json?format=export');
  List itemsAsList = [];
  int count = 0;

  items.forEach((k,v) {
    Map item = v;
    item['id'] = k;
//    Map communities = item['communities'];
//    if (communities == null) {
//      print('NULL FOUND: ' + item['id']);
//      return;
//    }
    itemsAsList.add(item);
  });

  Future.forEach(itemsAsList,(Map item) {
      if (item['type'] == 'event' && item['startDateTime'] != null) {
        var newPriority = DateTime.parse(item['startDateTime']).toUtc().millisecondsSinceEpoch.toString();

          Firebase.patch('/items/${item['id']}.json', {'startDateTimePriority': newPriority}, auth: firebaseSecret);

        Map communities = item['communities'];

        if (communities == null) return;

//        item['.priority'] = DateTime.parse(item['createdDate'])

        communities.keys.forEach((community) {
          Map itemToSave = new Map.from(item);
          itemToSave.remove('communities');
          itemToSave.remove('activities');
          itemToSave.remove('id');

          new Timer(new Duration(milliseconds: count * 800), () {
            print('$count. ${item['id']}');
            Firebase.put('/items_by_community_by_type/$community/${item['type']}/${item['id']}.json', itemToSave, auth: firebaseSecret);
          });
          count++;
        });
      }
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
          await Post.update(item['id'], updates, firebaseSecret);

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
            await Post.update(item['id'], updates, firebaseSecret);
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