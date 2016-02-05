library shared.model.feed;

import 'item.dart';
import '../util.dart' as util;

class FeedModel implements Item {
  String id;
  String user;
  String usernameForDisplay;
  String type;
  int priority;
  DateTime createdDate = new DateTime.now().toUtc();
  DateTime updatedDate = new DateTime.now().toUtc();
  String url;
  String siteUrl; // The user's message.
  DateTime lastCrawledDate; // The attached content's subject.
  Map communities; // Communities this feed is a part of.

  Map toJson() {
    return {
      "id": id,
      "user": user,
      "type": type,
      "priority": priority,
      "createdDate": util.encode(createdDate),
      "updatedDate": util.encode(updatedDate),
      "url": url,
      "siteUrl": siteUrl,
      // TODO: https://goo.gl/NpR6Xe
      "lastCrawledDate": util.encode(lastCrawledDate),
      "communities": communities
    };
  }

  static FeedModel fromJson(Map data) {
    return new FeedModel()
      ..id = data['id']
      ..user = data['user']
      ..type = data['type']
      ..priority = data['priority']
      ..createdDate = data['createdDate']
      ..updatedDate = data['updatedDate']
      ..url = data['url']
      ..siteUrl = data['siteUrl']
      ..lastCrawledDate = data['lastCrawledDate']
      ..communities = data['communities'];
  }
}
