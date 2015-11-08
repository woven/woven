library feed_item;

import 'package:woven/src/server/model/rss_item.dart';

/**
 * This class represents one item from either RSS or ATOM.
 */
class FeedItem {
  String title;
  String link;
  String description;
  String language;
  String copyright;
  DateTime publicationDate;
  List<String> categories = [];
  String image;

  FeedItem.fromRssItem(RssItem item) {
    title = item.title;
    link = item.link;
    description = item.description;
    language = item.language;
    copyright = item.copyright;
    publicationDate = item.publicationDate;
    categories = item.categories;
    image = item.image;
  }
}