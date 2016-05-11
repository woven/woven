library server.crawler.atom_reader;

import 'dart:async';

import 'package:xml/xml.dart';
import 'package:logging/logging.dart';

import '../model/atom_item.dart';
import '../util.dart' as util;

class AtomReader {
  var contents;
  var url;
  var xml;

  final Logger logger = new Logger('AtomReader');

  AtomReader({this.contents, this.url});

  Future<List<AtomItem>> getItems() {
    return new Future(() {
      if (contents == null) return [];

      // Parse the ATOM message.
      var atomItems = [];
      var futures = [];

      try {
        XmlDocument xml = parse(contents);

        xml.findAllElements('entry').toList().forEach((XmlElement element) {
          var content = element.findElements('content').single.text;
          if (content == null)
            content = element.findElements('summary').single.text;

          // Try to find images.
          var logo = (element.findElements('logo').length > 0)
              ? element.findElements('logo').single.text
              : null;
          if (logo == null) {
            var imageMatcher =
                new RegExp('<img.*?src="(.*?)".*?>', caseSensitive: false);
            var matches = imageMatcher.allMatches(content).toList();
            if (matches.length > 0) {
              content = content.replaceAll(imageMatcher, '');
              logo = matches[0].group(1);
            }
          }

          // We are inside one <item></item>.
          var item = new AtomItem()
            ..title = (element.findElements('title').length > 0)
                ? element.findElements('title').single.text
                : null
            ..language = (element.findElements('language').length > 0)
                ? element.findElements('language').single.text
                : null
            ..content = content
            ..link = element.findElements('link').first.getAttribute('href')
            ..logo = logo
            ..rights = (element.findElements('rights').length > 0)
                ? element.findElements('rights').single.text
                : null;

          if (item.title == null || item.title == '') return;

          // Parse the date.
          var date = element.findElements('published')?.single.text;
          if (date == null) date = element.findElements('updated')?.single.text;

          if (date != null) {
            futures.add(util.parseDate(date).then((result) {
              if (result is DateTime) {
                item.published = result;

                // We don't want published dates to be in the future.
                DateTime now = new DateTime.now().toUtc();
                if (item.published.compareTo(now) == 1) item.published = now;

                if (item.title != null && item.title != '') atomItems.add(item);
              }
            }).catchError((error, stack) {
              logger.warning('Error parsing date for Atom item', error, stack);
              return;
            }));
            if (item.title != null && item.title != '') atomItems.add(item);
          } else {
            logger.warning("No publication date for item: ${item.link}");
            return;
          }
        });
      } catch (error, stack) {
        throw 'Exception during parsing of Atom feed: $error\n\n$stack';
        logger.severe('Exception during parsing of Atom feed', error, stack);
      }
      return Future.wait(futures).then((values) => atomItems);
    });
  }
}
