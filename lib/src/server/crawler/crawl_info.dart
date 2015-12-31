library server.crawler.crawl_info;

import 'package:woven/src/server/crawler/image_info.dart';

class CrawlInfo {
  Uri uri;
  String title;
  String teaser;
  ImageInfo bestImage;

  CrawlInfo({this.uri});

  Map toJson() {
    return {
      'uri': uri.toString(),
      'title': title,
      'teaser': teaser,
      'bestImage': bestImage
    };
  }

  static CrawlInfo fromJson(Map data) {
    if (data == null) return null;
    return new CrawlInfo()
      ..uri = data['uri']
      ..title = data['title']
      ..teaser = data['teaser']
      ..bestImage = data['bestImage'];
  }
}