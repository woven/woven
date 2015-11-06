library woven.server.task.crawler;

import 'dart:async';

import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';
import 'package:http/http.dart' as http;

import 'package:woven/src/shared/model/uri_preview.dart';

import 'task.dart';
import '../task_scheduler.dart';
import '../feed/feed_reader.dart';
import '../feed/feed_item.dart';

class CrawlerTask extends Task {
  bool runImmediately = true;

  final Map<String, List<String>> feeds = {
    'miamitech': ['http://miamiherald.typepad.com/the-starting-gate/rss.xml'],
    'breakshop': []
  };

  CrawlerTask();

  /**
   * Runs the task.
   */
  Future run() async {
    TaskScheduler.log("Running the crawler task");

    feeds.forEach((community, feeds) {
      Future.forEach(feeds, (feed) async {
        var feedReader = new FeedReader(url: feed);
        var feedItems = await feedReader.load();
        feedItems.forEach((FeedItem item) {
          print('''
            ${item.title}
            ${item.description}
            ${item.link}
            ${item.categories}
            ${item.publicationDate}
            ${item.image}
            ${item.copyright}
            =================
          ''');
        });
      });
    });
  }

  // TODO: Unused atm.
  Future processFeed(Uri uri) async {
    String contents = await http.read(uri);
    print(contents);
  }

  Future getPreview(Uri uri) async {
    String contents = await http.read(uri);

    UriPreview preview = new UriPreview(uri: uri);
    var document = parse(contents);
    List<Element> metaTags = document.querySelectorAll('meta');

    metaTags.forEach((Element metaTag) {
      var property = metaTag.attributes['property'];
      if (property == 'og:title') preview.title = metaTag.attributes['content'];
      if (property == 'og:description') preview.teaser =
          metaTag.attributes['content'];
      if (property == 'og:image') preview.imageOriginalUrl =
          metaTag.attributes['content'];

      if (metaTag.attributes['name'] == 'description' &&
          preview.teaser == null) preview.teaser =
          metaTag.attributes['content'];
    });

    if (preview.title == null &&
        document.querySelector('title') != null) preview.title =
        document.querySelector('title').innerHtml;
  }
}
