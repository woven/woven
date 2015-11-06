library server.rss_crawler;

import 'dart:async';

import 'package:http/http.dart' as http;

import 'feed_item.dart';
import 'rss_reader.dart';
import '../util.dart' as util;

class FeedReader {
  String url;

  FeedReader({this.url}) {
    if (url != null) url = util.prefixHttp(url);

    url = util.correctUrl(url);
  }

  Future<List<FeedItem>> load({int limit: 10}) async {
    // Used to use our own httpRead. See https://goo.gl/TsmG57.
    var contents = await http.read(url);

    if (contents == null) throw 'Loading $url was empty.';

    // ATOM.
    if (contents.replaceAll(new RegExp('<\\?xml[^]+?\\?>'), '').substring(0, 10).contains('feed')) {
      throw 'Atom not supported just yet.';
//      var reader = new AtomReader(contents: contents, url: url);
//      return reader.getItems().then((results) {
//        return results.fold([], (previous, current) => previous..add(new FeedItem.fromAtomItem(current)));
//      });
    }

    // RSS.
    else {
      var reader = new RssReader(contents: contents, url: url);
      var results = await reader.getItems();
      return results.fold([], (previous, current) => previous..add(new FeedItem.fromRssItem(current)));
    }
  }
}