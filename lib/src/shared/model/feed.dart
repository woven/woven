library shared.model.feed;

import 'item.dart';
import '../util.dart' as util;

class FeedModel implements Item {
  String id;
  String user;
  String usernameForDisplay;
  String type;
  DateTime createdDate = new DateTime.now().toUtc();
  DateTime updatedDate = new DateTime.now().toUtc();
  String url;
  String siteUrl; // The user's message.
  DateTime lastCrawledDate; // The attached content's subject.

  Map toJson() {
    return {
      "user": user,
      "type": type,
      "createdDate": util.encode(createdDate),
      "updatedDate": util.encode(updatedDate),
      "url": url,
      "siteUrl": siteUrl,
      // TODO: https://goo.gl/NpR6Xe
      "lastCrawledDate": util.encode(lastCrawledDate)
    };
  }

  static FeedModel fromJson(Map data) {
    return new FeedModel()
      ..user = data['user']
      ..type = data['type']
      ..createdDate = data['createdDate']
      ..updatedDate = data['updatedDate']
      ..url = data['url']
      ..siteUrl = data['siteUrl']
      ..lastCrawledDate = data['lastCrawledDate'];
  }
}
