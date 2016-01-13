library server.crawler.feed_reader;

import 'dart:async';

import 'package:woven/src/shared/util.dart' as sharedUtil;
import 'package:logging/logging.dart';

import '../model/feed_item.dart';
import 'rss_reader.dart';
import 'atom_reader.dart';
import '../util.dart' as util;

class FeedReader {
  String url;

  final Logger logger = new Logger('FeedReader');

  FeedReader({this.url}) {
    if (url != null) url = sharedUtil.prefixHttp(url);

    url = util.correctUrl(url);
  }

  // TODO: Not respecting limit?
  Future<List<FeedItem>> load({int limit: 10}) {
//    if (!url.contains('knightfoundation')) return new Future.value([]); // TODO: Kill me.
    return new Future(() async {
      var contents;
      contents = await util.readHttp(url);

      if (contents == null) {
        logger.warning('Loading $url was empty');
        return new Future.value([]);
      }

      // ATOM.
      if (contents
          .replaceAll(new RegExp('<\\?xml[^]+?\\?>'), '')
          .substring(0, 10)
          .contains('feed')) {
        var reader = new AtomReader(contents: contents, url: url);
        var results = await reader.getItems();
        logger.fine('${results.length} results for ${url}');
        if (results == null) return new Future.value([]);
        return results.fold(
            [],
            (previous, current) =>
                previous..add(new FeedItem.fromAtomItem(current)));
      }

      // RSS.
      else {
        var reader = new RssReader(contents: contents, url: url);
        var results = await reader.getItems();

        for (var result in results) {
          var a = new FeedItem.fromRssItem(result);
        }
        if (results == null) return new Future.value([]);
        return results.fold(
            [],
            (previous, current) =>
                previous..add(new FeedItem.fromRssItem(current)));
      }
    }).catchError((error, stack) {
      logger.severe("Error loading feed items", error, stack);
      return new Future.value([]);
    });
  }
}
