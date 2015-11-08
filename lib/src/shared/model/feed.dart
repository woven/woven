library shared.model.feed;

import 'item.dart';

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

  Map encode() {
    return {
      "user": user,
      "type": type,
      "createdDate": createdDate.toString(),
      "updatedDate": updatedDate.toString(),
      "url": url,
      "siteUrl": siteUrl,
      // TODO: https://goo.gl/NpR6Xe
      "lastCrawledDate":
          (lastCrawledDate != null ? lastCrawledDate.toString() : null)
    };
  }

  static FeedModel decode(Map data) {
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
