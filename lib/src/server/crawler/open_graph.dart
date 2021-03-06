library open_graph;

import 'dart:io';
import 'dart:mirrors';

//import 'package:html5lib/parser.dart' as htmlParser;
//import 'package:html5lib/dom.dart';


import 'package:woven/src/shared/util.dart' as sharedUtil;

/**
 * This class can parse HTML into an Open Graph class for convenient access of OpenGraph data.
 *
 * It reads both Open Graph properties, and other propeties like meta tags and titles.
 */
class OpenGraph {
  String title;
  String url;
  String description;
  String imageUrl;
  String videoUrl;
  String type;
  String locality;
  String region;
  String countryName;
  String postalCode;
  String latitude;
  String longitude;
  String siteName = '';

  static Map<String, String> propertyToFieldMap = {
    'image_url': 'imageUrl',
    'country_name': 'countryName',
    'postal_code': 'postalCode',
    'site_name': 'siteName',
    'image': 'imageUrl',
    'video': 'videoUrl'
  };

  /**
   * Parses the given content into an OpenGraph.
   */
  static OpenGraph parse(String contents) {
    if (contents == null) return null;

    var og = new OpenGraph();

    var im = reflect(og);

    var alreadySet = [], futures = [];

    var matches = new RegExp('<meta ?property="([^"]+)" ?content="[^"]+" ?/?>', caseSensitive: false).allMatches(contents).toList();
    var matches2 = new RegExp('<meta ?content="[^"]+?" ?property="(.*?)" ?/?>').allMatches(contents).toList();
    matches.addAll(matches2);

    matches.forEach((Match match) {
      var property = match.group(1);

      if (property == null) return;

      var m = new RegExp('content="([^"]+?)"').firstMatch(match.group(0));
      if (m != null) {
        var content = m.group(1);

        if (property.startsWith('og:')) {
          var propertyName = property.replaceFirst('og:', '');

          if (propertyToFieldMap.containsKey(propertyName)) propertyName = propertyToFieldMap[propertyName];

          if (alreadySet.contains(propertyName)) return;

          try {
            alreadySet.add(propertyName);

            content = sharedUtil.htmlDecode(content);

            content = content.trim();

            // TODO: Switch to Mirrors when sync.
            //im.setFieldAsync(new Symbol(propertyName), content).catchError((e) {});
            if (propertyName == 'title') og.title = content;
            if (propertyName == 'url') og.url = content;
            if (propertyName == 'description') og.description = content;
            if (propertyName == 'imageUrl') og.imageUrl = content;
            if (propertyName == 'videoUrl') og.videoUrl = content;
            if (propertyName == 'type') og.type = content;
            if (propertyName == 'locality') og.locality = content;
            if (propertyName == 'region') og.region = content;
            if (propertyName == 'countryName') og.countryName = content;
            if (propertyName == 'postalCode') og.postalCode = content;
            if (propertyName == 'latitude') og.latitude = content;
            if (propertyName == 'longitude') og.longitude = content;
            if (propertyName == 'siteName') og.siteName = content;
          } catch (e) {}
        }
      }
    });

    if (og.title == null) {
      var match = new RegExp('<title>([^]*?)</title>').firstMatch(contents);
      if (match != null) {
        og.title = match.group(1).trim();
      }
    }

    return og;
  }
}