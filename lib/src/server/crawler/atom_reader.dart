library server.crawler.atom_reader;

import 'dart:async';

import 'package:xml/xml.dart';

import '../model/atom_item.dart';
import '../util.dart' as util;

class AtomReader {
  var contents;
  var url;
  var xml;

  AtomReader({this.contents, this.url});

  Future<List<AtomItem>> getItems() {
    var completer = new Completer();

    // First we have to get rid of some data, because of the lack of support in the XML package.

    // Get rid of the top-level <?xml ?> line.
    contents = contents.replaceAll(new RegExp('<\\?xml[^]+?\\?>'), '');

    // Get rid of some stuff like "atom:link" and turn it into "link".
    contents = contents.replaceAll(new RegExp('<content:.*?>'), '<content>');
    contents = contents.replaceAll(new RegExp('</content:.*?>'), '</content>');
    contents = contents.replaceAll(new RegExp('<[a-zA-Z0-9]+:'), '<');
    contents = contents.replaceAll(new RegExp('</[a-zA-Z0-9]+:'), '</');
    contents = contents.replaceAll(new RegExp('xml:([a-zA-Z]+)=".*?"'), '');
    contents = contents.replaceAll(new RegExp('xmlns:atom=".*?"'), '');
    contents = contents.replaceAll(new RegExp('xmlns=".*?"'), '');
    contents = contents.replaceAll(new RegExp('xmlns:([a-zA-Z]+)=".*?"'), '');
    contents = contents.replaceAll(new RegExp('thr:([a-zA-Z]+)=".*?"'), '');

    // Parse the ATOM message.
    var items = [], futures = [];

    try {
      XmlDocument xml = parse(contents);

      xml.findAllElements('entry').toList().forEach((XmlElement element) {
        var content = element.findElements('content').single.text;
        if (content == null) content =
            element.findElements('summary').single.text;

        // Try to find images.
        var logo = (element.findElements('logo').length > 0) ? element.findElements('logo').single.text : null;
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
          ..title = (element.findElements('title').length > 0) ? element.findElements('title').single.text : null
          ..language = (element.findElements('language').length > 0) ? element.findElements('language').single.text : null
          ..content = content
          ..link = element.findElements('link').first.getAttribute('href')
          ..logo = logo
          ..rights = (element.findElements('rights').length > 0) ? element.findElements('rights').single.text : null;

        if (item.title == null || item.title == '') return;

        // Parse the date.
        var date = element.findElements('published')?.single.text;
        if (date == null) date = element.findElements('updated')?.single.text;

        if (date != null) {
          futures.add(util.parseDate(date).then((result) {
            if (result is DateTime) {
              item.published = result;

              // We don't want published dates to be in the future.
              if (item.published.compareTo(new DateTime.now()) ==
                  1) item.published = new DateTime.now();

              items.add(item);
            }
          }).catchError((e) {}));
        } else {
          items.add(item);
        }
      });
    } catch (e, stack) {
      completer
          .completeError('Exception during parsing of ATOM feed: $e $stack');
      return completer.future;
    }

    Future.wait(futures).then((values) {
      completer.complete(items);
    });

    return completer.future;
  }

  /**
   * A helper for fetching an attribute value.
   */
//  String getTagAttribute(
//      XmlElement element, String tagName, String attributeName,
//      {prioritize}) {
//    var tags = element.findElements(tagName);
//
//    print(tags.first);
//
//    XmlElement tag;
//    if (prioritize == null || tags.length == 1) tag = tags.first;
//    if (tags.length == 0) return null;
//
//    if (prioritize != null && tags.length > 1) {
//      tags.forEach((t) {
//        var match = true;
//        prioritize.forEach((key, value) {
//          if (t.attributes[key] != value) match = false;
//        });
//
//        if (match) tag = t;
//      });
//
//      if (tag == null) tag = tags.first;
//    }
//
//    tag =  tag.attributes.asMap()
//
//    return [attributeName];
//  }
}
