library server.crawler.rss_reader;

import 'dart:async';
import '../model/rss_item.dart';

import 'package:xml/xml.dart';

import '../util.dart' as util;
import 'crawler.dart';

class RssReader {
  var contents;
  var url;
  var message = '';
  XmlDocument xml;

  RssReader({this.contents, this.url});

  /**
   * Loads the RSS feed.
   */
  Future<List<RssItem>> getItems() {
    return new Future(() {
      if (contents == null) return [];

      // First we have to get rid of some data, because of the lack of support in the XML package.
      // TODO: Still needed now that we're using the new xml lib?

      // Get rid of the top-level <?xml ?> line.
//      contents = contents.replaceAll(new RegExp('<\\?xml[^]+?\\?>'), '');
//
//      // Get rid of some stuff like "atom:link" and turn it into "link".
//      contents = contents.replaceAll(new RegExp('<content:.*?>'), '<content>');
//      contents =
//          contents.replaceAll(new RegExp('</content:.*?>'), '</content>');
//      contents = contents.replaceAll(new RegExp('<[a-zA-Z0-9]+:'), '<');
//      contents = contents.replaceAll(new RegExp('</[a-zA-Z0-9]+:'), '</');
//      contents = contents.replaceAll(new RegExp('xml:base=".*?"'), '');
//      contents = contents.replaceAll(new RegExp('xmlns:atom=".*?"'), '');

      // Parse the RSS message.
      var rssItems = [];
      var futures = [];

      try {
        try {
//          if (url.contains('techcrunch.com')) {
//            print(contents.substring(0, 500));
//          }
          xml = parse(contents);

        } on ArgumentError catch (e, s) {
          print('$e\n\n$s');
          // TODO: How do I get this to bubble up so my CrawlerTask can handle it?
          print('Invalid RSS feed for $url');
          return null;
        }
//        print('$xml XDDD');
//        print(url);
//        return null;
        var items = xml.findAllElements('item').forEach((XmlElement element) {
          var image;
          var description = element.findElements('description').single.text;
          if (description == null) {
            description = element.findElements('content').single.text;
          }
//          description = sharedUtil.htmlDecode(description);

          // Try to find images.
          var imageMatcher =
              new RegExp('<img.*?src="(.*?)".*?>', caseSensitive: false);
          var matches = imageMatcher.allMatches(description).toList();
          if (matches.length > 0) {
            description = description.replaceAll(imageMatcher, '');
            image = matches[0].group(1);
          }

          // We are inside one <item></item>.
          var item = new RssItem()
            ..title = element.findElements('title').single.text
            ..link = element.findElements('link').single.text
            // TODO: Bad state, handle better?
            ..language = (element.findElements('language').length > 0)
                ? element.findElements('language').single.text
                : null
            ..description = description
            ..image = image
            ..copyright = (element.findElements('copyright').length > 0)
                ? element.findElements('copyright').single.text
                : null;

          if (item.image is String) {
            futures.add(Crawler.isImageBigEnough(item.image).then((size) {
              if (size == false) item.image = null;
            }));
          }

          // Build a list of categories (List<String>) based on the XML tree.
          List categories = element.findElements('category');
          categories.forEach((XmlElement c) => item.categories.add(c.text));

          // There can be additional information in the permalink.
          var additionalInfoUrl = element.findElements('guid').single.text;
          if (additionalInfoUrl != null &&
              additionalInfoUrl.startsWith('http')) {
            item.link = additionalInfoUrl;
          }

          // Parse the date.

          futures.add(util
              .parseDate(element.findElements('pubDate').first.text)
              .then((result) {
            if (result is DateTime) {
              item.publicationDate = result;
            } else {
              item.publicationDate = new DateTime.now();
            }

            // We don't want published dates to be in the future.
            if (item.publicationDate.compareTo(new DateTime.now()) ==
                1) item.publicationDate = new DateTime.now();
          }).catchError((e) {}));

          if (item.title != null && item.title != '') rssItems.add(item);
        });
      } catch (error, stack) {
        throw 'Exception during parsing of RSS feed: $error\n\n$stack';
      }

      return Future.wait(futures).then((values) => rssItems);
    });
  }
}
