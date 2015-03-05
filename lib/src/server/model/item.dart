library item_model_server;

import 'package:woven/src/shared/model/item.dart' as shared;
import 'dart:async';
import '../firebase.dart';

class ItemModel extends shared.ItemModel {
  /**
   * Update an item with provided [value].
   *
   * Performs a series of PATCHes using the Firebase REST API.
   */
  static update(String itemId, Map value, String authToken) {
    var type;

    // Update the item in /items.
    Firebase.patch('/items/$itemId.json', value, auth: authToken).then((res) {
      // Get the type of the item.
      Firebase.get('/items/$itemId/type.json').then((String res) {
        type = res;
      }).then((_) {
        // Get a list of the communities this item is in.
        Firebase.get('/items/$itemId/communities.json').then((Map res) {
          if (res == null) return null;
          List communities = [];
          res.forEach((k, v) {
            communities.add(k);
          });
          return communities;
        }).then((List communities) {
          if (communities == null) return;
          // For each community the item is in...
          communities.forEach((community) {
            // Update the item in items_by_community.
            Firebase.patch('/items_by_community/$community/$itemId.json', value, auth: authToken);
            // Update the item in items_by_community_by_type.
            Firebase.patch('/items_by_community_by_type/$community/$type/$itemId.json', value, auth: authToken);
          });
        }).catchError(print);
      });
    });
  }
}