library server.model.post;

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
        Firebase.patch('/items_by_community/$community/$id.json', value, auth: authToken);
        Firebase.patch('/items_by_community_by_type/$community/$type/$id.json', value, auth: authToken);
      });
    } catch(error, stack) {
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
        Firebase.delete('/items_by_community/$community/$id.json', auth: authToken);
        Firebase.delete('/items_by_community_by_type/$community/$type/$id.json', auth: authToken);
      });
    } catch(error, stack) {
      print('$error\n\n$stack');
    }
  }
}