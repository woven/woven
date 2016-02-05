library server.model.item;

import 'dart:async';

import 'package:woven/src/shared/model/item.dart' as shared;
import '../firebase.dart';

class Item extends shared.Item {
  /**
   * Update an item with provided [value].
   *
   * Performs a series of PATCHes using the Firebase REST API.
   */
  static update(String id, Map value, String authToken) async {
    try {
      var type = await Firebase.get('/items/$id/type.json');
      Map getCommunities = await Firebase.get('/items/$id/communities.json');
      List communities = getCommunities.keys;

      Firebase.patch('/items/$id.json', value, auth: authToken);

      if (communities.isEmpty) return null;

      communities.forEach((community) {
        Firebase.patch('/items_by_community/$community/$id.json', value,
            auth: authToken);
        Firebase.patch('/items_by_type/$type/$id.json', value,
            auth: authToken);
        Firebase.patch(
            '/items_by_community_by_type/$community/$type/$id.json', value,
            auth: authToken);
      });

      // TODO: Update updatedDate for community?

    } catch (error, stack) {
      print('$error\n\n$stack');
    }
  }

  /**
   * Delete an item.
   *
   * Performs a series of DELETEs using the Firebase REST API.
   */
  static delete(String id, String authToken) async {
    try {
      var type = await Firebase.get('/items/$id/type.json');
      Map getCommunities = await Firebase.get('/items/$id/communities.json');
      List communities = getCommunities?.keys;

      var delete = Firebase.delete('/items/$id.json', auth: authToken);

      if (communities.isEmpty) return null;

      communities.forEach((community) {
        Firebase.delete('/items_by_community/$community/$id.json',
            auth: authToken);
        Firebase.delete('/items_by_type/$type/$id.json',
            auth: authToken);
        Firebase.delete('/items_by_community_by_type/$community/$type/$id.json',
            auth: authToken);
      });
    } catch (error, stack) {
      print('$error\n\n$stack');
    }
  }

  /**
   * Add an item with a given [value] to the given [community].
   */
  static Future<String> add(
      List communities, Map value, String authToken) async {

      Map communitiesMap = {};

      for (var community in communities) communitiesMap[community] = true;

      var type = value['type'];
      value['communities'] = communitiesMap;
      value['.priority'] = value['priority'];

      try {
      var id = await Firebase.post('/items.json', value, auth: authToken);

      for (var community in communities) {
        Firebase.put('/items_by_community/$community/$id.json', value,
            auth: authToken);
        Firebase.put('/items_by_type/$type/$id.json', value,
            auth: authToken);
        Firebase.put(
            '/items_by_community_by_type/$community/$type/$id.json', value,
            auth: authToken);

        var now = new DateTime.now().toUtc();

        Firebase.patch(
            '/communities/$community.json', {'updatedDate': now.toString()},
            auth: authToken);

      }

      return id;
    } catch (error, stack) {
      print('$error\n\n$stack');
    }
  }
}
