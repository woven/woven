library client.analytics;

import 'dart:html';

import 'package:usage/usage_html.dart';

import 'package:woven/config/config.dart';



Analytics _analytics;
final String _ua = config['google']['analytics']['tracking_id'];


Analytics getAnalytics() {
  _analytics = new AnalyticsHtml(_ua, 'Woven', '1.0');
  _analytics.optIn = true;
  _analytics.sendScreenView(window.location.pathname);

  return _analytics;
}

void changePage(Analytics analytics) {
  analytics.sendScreenView(window.location.pathname);
}

//void _handleFoo(Analytics analytics) {
//  analytics.sendEvent('main', 'foo');
//}
//
//void _handleBar(Analytics analytics) {
//  analytics.sendEvent('main', 'bar');
//}