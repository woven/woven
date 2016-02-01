library client.analytics;

import 'dart:html';

import 'package:usage/usage_html.dart';

import 'package:woven/config/config.dart';

final String _ua = config['google']['analytics']['tracking_id'];

class Analytics {
  AnalyticsHtml _analytics = new AnalyticsHtml(_ua, 'Woven', '1.0');

  Analytics() {
    _analytics.optIn = true;
  }

  void changePage() {
    _analytics.sendScreenView(window.location.pathname);
  }

  void sendEvent(String category, String action, {String label, int value}) {
    _analytics.sendEvent(category, action, label: label, value: value);
  }
}
