library server.crawler.feed_reader;

import 'dart:async';

import 'package:woven/src/shared/util.dart' as sharedUtil;

import '../model/feed_item.dart';
import 'rss_reader.dart';
import 'atom_reader.dart';
import '../util.dart' as util;

class FeedReader {
  String url;

  FeedReader({this.url}) {
    if (url != null) url = sharedUtil.prefixHttp(url);

    url = util.correctUrl(url);
  }

  // TODO: Not respecting limit?
  Future<List<FeedItem>> load({int limit: 10}) async {
    var contents = await util.readHttp(url);

    if (contents == null) throw 'Loading $url was empty.';

    // ATOM.
    if (contents
        .replaceAll(new RegExp('<\\?xml[^]+?\\?>'), '')
        .substring(0, 10)
        .contains('feed')) {
//      throw 'Atom not supported just yet.';
      var reader = new AtomReader(contents: contents, url: url);
      var results = await reader.getItems();
      return results.fold(
          [],
          (previous, current) =>
              previous..add(new FeedItem.fromAtomItem(current)));
    }

    // RSS.
    else {
      var reader = new RssReader(contents: contents, url: url);
      var results = await reader.getItems();
      if (results == null) return new Future.value({});
      return results.fold(
          [],
          (previous, current) =>
              previous..add(new FeedItem.fromRssItem(current)));
    }
  }
}
