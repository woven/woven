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
  static update(String itemId, Map value) {
    // Update the item in /items.
    Firebase.patch('/items/$itemId.json', value).then((_) {
      // Get a list of the communities this item is in.
      Firebase.get('/items/$itemId/communities.json').then((Map res) {
        List communities = [];
        res.forEach((k, v) {
          communities.add(k);
        });
        return communities;
      }).then((List communities) {
        // For each community the item is in...
        communities.forEach((community) {
          // Update the item in items_by_community.
          Firebase.patch('/items_by_community/$community/$itemId.json', value);
          // Update the item in items_by_community_by_type.
          Firebase.patch('/items_by_community_by_type/$community/news/$itemId.json', value);
        });
      });
    });
  }
}