library woven_client;

import 'dart:html';
import 'dart:convert';
import 'dart:isolate';
import 'dart:collection';
import 'dart:math';
import 'dart:async';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:yaml/yaml.dart';
import 'dart:js' as js;

import 'package:polymer/polymer.dart';

// New stuff
import 'package:woven/src/router.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/dispatcher/dispatcher.dart';
import 'package:woven/src/dispatcher/dispatcher_client.dart';

//import 'packages/woven/shared.dart';
//import 'packages/woven/src/shared_util.dart' as sharedUtil;
//import 'packages/woven/src/model/models.dart' as model;
//import 'packages/woven/src/buffered_stream_controller.dart';
//import 'packages/woven/src/input_formatter.dart';
//import 'packages/woven/src/date_group.dart';
//import 'packages/woven/src/long_polling.dart';
//import 'packages/woven/src/base64.dart';
//import 'packages/woven/src/sign_in.dart';
//import 'package:woven/client/components/dialog/user/user.dart';
//import 'package:woven/client/components/manage_page_filters/manage_page_filters.dart';
//import 'package:woven/client/components/dialog/edit_source/edit_source.dart';
//import 'packages/woven/src/visual_grid.dart';
//import 'packages/woven/src/data_notification.dart';
//import 'packages/woven/src/data_serializer.dart';
//import 'package:woven/src/data_criterion/data_criterion.dart';
//import 'package:woven/src/data_layer.dart';
//import 'package:woven/src/infinite_scroll.dart';
//import 'package:woven/src/web_socket_request.dart';
//import 'package:woven/src/web_socket_response.dart';
//import 'packages/woven/src/router.dart';

// //part 'packages/woven/src/dispatcher/dispatcher_client.dart';


//part 'packages/woven/src/view_model/admin.dart';
//part 'packages/woven/src/view_model/admin_activity.dart';
//part 'packages/woven/src/view_model/admin_data.dart';
//part 'packages/woven/src/view_model/admin_users.dart';
//part 'packages/woven/src/view_model/main.dart';
//part 'packages/woven/src/view_model/community.dart';
//part 'packages/woven/src/view_model/group.dart';
//part 'packages/woven/src/view_model/live_feed.dart';
//part 'packages/woven/src/view_model/profile.dart';
//part 'packages/woven/src/view_model/inbox.dart';
//part 'packages/woven/src/view_model/event.dart';
//part 'packages/woven/src/view_model/discover.dart';
//part 'packages/woven/src/view_model/new_page.dart';
//part 'packages/woven/src/view_model/news_page.dart';
//part 'packages/woven/src/view_model/places.dart';
//part 'packages/woven/src/view_model/feed.dart';
//part 'packages/woven/src/view_model/search.dart';
//part 'packages/woven/src/view_model/custom_page.dart';
//part 'packages/woven/src/view_model/manage_page.dart';
//part 'packages/woven/src/view_model/manage_page_sources.dart';
//part 'packages/woven/src/view_model/directory.dart';
//part 'packages/woven/src/view_model/events.dart';

class NullTreeSanitizer implements NodeTreeSanitizer {
  void sanitizeTree(Node node) {}
}

var platform;

class WovenPlatform {
  WebSocket connection;
  Router router = new Router([]);
  DispatcherClient dispatcher;
  //DataLayer data;




  @observable String language = 'en-US';
  @observable int mobileLayoutMaxWidth = 320;
  @observable bool showPersonalizedViews = false;
  @observable bool showVisualViews = false;
  @observable bool fullScreenViewing = false;
  @observable int usersOnline = 0;
  @observable bool hasLoadedContent = true;
  bool expandInlineAdd = true;
  @observable int downloadBytesTransferred = 0;
  @observable int uploadBytesTransferred = 0;
  @observable int requestsSent = 0;
  @observable var pageTitle;
  @observable var communityEditMode = false;

  String offlineMessage = '<div>The Woven cloud isn\'t responding. There\'s been a <a href="http://www.youtube.com/watch?v=KqF3J8DpEb4" target="_blank">communication breakdown</a>.</div>';

  @observable int contentPadding = 24;
  @observable int contentPaddingRight = 24;
  @observable int contentWidth = 0;
  @observable bool isScrolled = false;

  @observable var globalMessages = toObservable([]);
  @observable var globalErrors = toObservable([]);

  @observable var debug = toObservable([]);

  String get formattedBytesTransferred {
    var sizes = ['bytes', 'kB', 'MB', 'GB'];
    var index = 0, index2 = 0;
    var amount = downloadBytesTransferred;
    //while (amount >= 1024 || index == 0) {
    amount /= 1024;
    index++;
    //}

    amount = amount.toStringAsFixed(0);

    var amount2 = uploadBytesTransferred;
    //while (amount2 >= 1024 || index2 == 0) {
    amount2 /= 1024;
    index2++;
    //}

    amount2 = amount2.toStringAsFixed(0);

    return '$amount ${sizes[index]} / $amount2 ${sizes[index2]} transferred';
  }

  // Not found setters and getters and random words.
  @observable String notFoundWord;

  @observable bool _notFoundPage = false;
  @observable bool get notFoundPage => _notFoundPage;
  @observable set notFoundPage(value) {
    _notFoundPage = value;

    var words = ['Shucks', 'Grr', 'Argh', 'Uh-oh', 'Yikes', 'Woops', 'Buggers', 'Eek'];
    notFoundWord = words.elementAt(new Random().nextInt(words.length));

    if (value) {
      document.body.classes.remove('fit-screen');
    }
  }

  Map configuration = {};

//  @observable get authorized => user != null && (user.active == true || user.isAdmin);
//  @observable get isAdmin => user != null && user.isAdmin;

  // Online stuff.
  @observable bool online = false;
  @observable bool loadingPage = false;


  StreamController onOnlineStateUpdateController;
  Stream onOnlineStateUpdate;

  Map<String, DateFormat> dates = {
      'standard': new DateFormat.yMd().add_Hm(),
      'standardDate': new DateFormat.yMd()
  };

  @observable bool _showApplication = false;
  @observable bool get showApplication => _showApplication;
  @observable set showApplication(value) {
    _showApplication = value;
  }

  @observable bool reloadingEntities = false;

  Stream onDataUpdate;
  StreamController dataUpdateStreamController;

  ScriptElement facebookSdk;
  ScriptElement twitterSdk;
  ScriptElement tinyMce;

  bool facebookSdkLoaded = false;
  bool twitterSdkLoaded = false;
  bool tinyMceLoaded = false;
  bool mapsLoaded = false;

  /**
   * This future completes when the platform is ready.
   */
  Future onReady;

  /**
   * Used for WebSocket requests. Stores the last ID used.
   */
  int lastRequestId = 0;

  /**
   * A map of request ID's and completers.
   */
  Map requestCompleters = new Map();
  Map requestPaths = new Map();

  Map requestSendDates = new Map();

  bool firstTimeLoading = true;
  bool firstTimeLoadedEntity = true;



//    get isFrontPage => router.parameters['page'] == 'home' && user == null && community == null && group == null;

  @observable bool newVersionOut = false;
  @observable var restartNotification;

  WovenPlatform() {

    this.configuration = config;

    if (window.location.search.contains('showEmailConfirmedMessage')) {
      globalMessages.add('showEmailConfirmedMessage');
    }

    // Get rid of junk from the URL (woven session, we were redirected).
    if (window.location.search.contains('wovenSession')) {
      window.history.replaceState(null, 'Woven', window.location.pathname);
    }

//    // Avoid timeouts. TODO: Don't send when the user has been active! Actually, do we still need this without nginx?
//    if (supportsWebSockets()) {
//      new Timer.periodic(const Duration(seconds: 50), (t) {
//        sendRequest(new WebSocketRequest(path: '/dev/null'));
//      });
//    }



    dataUpdateStreamController = new StreamController.broadcast();
    onDataUpdate = dataUpdateStreamController.stream;

    onOnlineStateUpdateController = new StreamController.broadcast();
    onOnlineStateUpdate = onOnlineStateUpdateController.stream;

    dispatcher = new DispatcherClient(router);
    dispatcher.platform = this;
//    if (isAndroid) window.alert('inside constructor()');
    establishConnection();

    // Either load the initial data immediately, or wait until DOM has loaded.
    // TODO: Is there a better way to determine if DOM has loaded? This event is NOT buffered.
    if (window.document.querySelector('#entity-json-container') != null) {
      loadInitialData();
    } else {
      window.onContentLoaded.listen((_) => loadInitialData());
    }

    onDataUpdate.listen((DataNotification notification) {
//      if (notification.model == 'ServerRestart') {
//        if (notification.data['silent'] != true) newVersionOut = true;
//
//        if (notification.data is Map && notification.data['force']) {
//          new Timer(const Duration(seconds: 6), () {
//            window.location.href = window.location.href;
//          });
//        } else {
//          restartNotification = notification;
//        }
//      }

      if (notification.model == 'NewConnection' && platform.user != null && platform.user.isAdmin) {
        //audioNewConnection.play();
      }

      if (notification.model == 'ConnectionClosed' && platform.user != null && platform.user.isAdmin) {
        //audioConnectionClosed.play();
      }

      if (notification.model == 'ProfilingRecord' && platform.user != null && platform.user.isAdmin) {
        window.console.groupCollapsed('Profiling results for: ${notification.data["name"]}');
        notification.data.forEach((key, value) {
          if (key != 'name') {
            if (value is num && value > 350) {
              window.console.warn('$key: ${value}ms');
            } else {
              window.console.log('$key: ${value}ms');
            }
          }
        });
        window.console.groupEnd();
      }

      if (notification.model == 'UsersOnline' && platform.user != null && platform.user.isAdmin) {
        usersOnline = notification.data;
      }

      if (notification.model == 'Tag' || notification.model == 'Community') {
        // Reload community model.
        if (community != null) loadCommunityByCode(code: community.code);
      }

      if (notification.model == 'User' && notification.ids.contains(user.id)) {
        signIn();
      }

      if (notification.model == 'Group') {
        // Reload group model.
        if (group != null) loadGroupByCode(code: group.code);
      }

      if (notification.model == 'LogRecord' && isAdmin) {
        notification.message = 'Server: ${notification.message}';

        print(notification.message);
      }

      if (notification.type == DataNotificationType.INFO && notification.message == 'logout' && user != null && notification.userId == user.id) {
        user = null;
      }
    });

    mainViewModel = new MainViewModel(this);

    var i = document.body.query('#global-loading-indicator');
    if (i != null) i.remove();
  }

  String getCommunityCodeFromHost() => '';
  bool isUnderDifferentDomain() => config['hostName'].any((h) => window.location.hostname.contains(h)) == false;

  hideTooltips() {
    onShowTooltipController.add(true);
  }

  /**
   * Parses URL + hostname and loads stuff as needed.
   *
   * This will load entities (community + group).
   *
   * Called when the URI changes.
   */
  loadStuff({address}) {
    if (address == null) address = '${window.location.pathname}${Uri.decodeComponent(window.location.search)}';

    router.previousParameters = new Map.from(router.parameters);

    notFoundPage = false;
    var needsNotShowApplication = false;
    var parts = router.resolvePathToParts(address);

    // Cancel previous entity request.
    if (communityRequest != null) {
      cancelRequest(communityRequest);
      needsNotShowApplication = false;
      loadingPage = false;
    }

    void continueProcessing() {
      var pageName = 'page';
      if (router.parameters['page'] != null) pageName = 'subPage';

      // Do we *still* have URL parts?
      if (parts.length > 0) {
        router.parameters[pageName] = parts[0];
        switch (parts[0]) {
          case 'events':
            if (parts.length > 1) router.restParameters.addAll(parts.sublist(1));
            break;
          case 'manage':
            if (parts.length > 1) router.parameters['itemId'] = parts[1];
            else router.parameters['itemId'] = null;

            if (parts.length > 2) router.parameters['subPage'] = parts[2];
            else router.parameters['subPage'] = 'sources';
            break;
          case 'event':
            router.parameters['eventId'] = parts[1];
            router.parameters['secondSubPage'] = 'hot';
            if (parts.length >= 4) {
              router.parameters['subPage'] = parts[3];
              if (parts.length >= 5) {
                router.parameters['secondSubPage'] = parts[4];
              }
            }
            else router.parameters['subPage'] = 'home';
            break;
          case 'onboard':
            break;
          case 'news-item':
            router.parameters['newsId'] = parts[1];
            if (parts.length >= 4) router.parameters['subPage'] = parts[3];
            else router.parameters['subPage'] = 'home';
            break;
          case 'tweet':
            router.parameters['tweetId'] = parts[1];
            break;
          case 'search':
            if (parts.length > 1) {
              router.parameters['keyword'] = Uri.decodeComponent(parts[1]);

              if (parts.length > 2) router.parameters['subPage'] = parts[2];
              else router.parameters['subPage'] = 'home';
            } else {
              router.parameters['keyword'] = '';
            }
            break;
          case 'news':
            if (parts.length > 1) router.restParameters.addAll(parts.sublist(1));
            break;
          case 'inbox':
            if (parts.length > 1) router.parameters['subPage'] = parts[1];
            break;
          case 'latest':
            if (parts.length > 1) router.parameters['subPage'] = parts[1];
            break;
          case 'popular':
            if (parts.length > 1) router.parameters['subPage'] = parts[1];
            break;
          case 'personal':
            if (parts.length > 1) router.parameters['subPage'] = parts[1];
            break;
          case 'discover':
            if (parts.length > 1) router.parameters['subPage'] = parts[1];
            break;
          case 'new':
            if (parts.length > 1) router.parameters['subPage'] = parts[1];
            else router.parameters['subPage'] = 'home';
            break;
          case 'admin':
            if (parts.length > 1) router.parameters['subPage'] = parts[1];
            else router.parameters['subPage'] = 'activity';
            break;
          case 'directory':
            if (parts.length > 1) {
              router.parameters['viewType'] = parts[1];

              if (parts.length > 2) router.restParameters.addAll(parts.sublist(2));
            } else {
              router.parameters['viewType'] = 'grid';
            }
            break;
        }
      } else {
        router.parameters['page'] = 'home';
      }

      if (needsNotShowApplication == false) {
        showApplication = true;
      }

      // Custom pages.
      if (community != null && group == null) {
        if (community.isCustomPage(router.parameters['page'])) {
          router.parameters['customPage'] = router.parameters['page'];

          // Are we on a sub-page? /about/foo
          if (parts.length > 1) {
            router.parameters['customPage'] = parts[1];
          }
        }
      }

      firstTimeLoading = false;
    }

    var communityCode = getCommunityCodeFromHost();
    isUnderCommunityDomain = communityCode != null && communityCode != 'www' && communityCode != '';

    // We are on a totally different domain.
    if (isUnderDifferentDomain()) {
      isUnderCommunityDomain = true;

      if (community == null || (community.domains != null && community.domains.contains(window.location.hostname) == false)) {
        if (communityRequest != null) cancelRequest(communityRequest);

        needsNotShowApplication = true;
        communityRequest = new WebSocketRequest()
          ..path = '/main/findEntity'
          ..parameters = {
            'domain': window.location.hostname,
        };

        sendRequest(communityRequest).then((response) {
          var community = response.data;

          if (community != null) {
            var community = response.data;

            loadCommunityByCode(code: community.code);

            if (parts.length == 0 || reservedAliases.contains(parts.first) == false) needsNotShowApplication = true;
          } else {
            needsNotShowApplication = false;
          }
        });
      }
    } else {
      if (isUnderCommunityDomain && (community == null || community.code != communityCode)) {
        if (community == null || communityCode != community.code) {
          var entity = getCommunityFromCache(code: communityCode);
          if (entity != null) {
            loadCommunityByCode(community: entity);
          } else {
            loadCommunityByCode(code: communityCode);
          }
          needsNotShowApplication = true;
        }
      }
    }

    if (parts.length > 0) {
      // Potential first parts:
      // - group
      // - community
      // - profile
      switch (parts[0]) {
        case 'profile':
          router.parameters['page'] = 'profile';
          router.parameters['userId'] = parts[1];
          parts = parts.sublist(2);
          break;
        default:
          if (!isUnderCommunityDomain && reservedAliases.contains(parts[0])) {
            community = null;
            group = null;
            break;
          }

          if (isUnderCommunityDomain == false) {
            if ((community == null || community.code != parts[0]) && (group == null || group.code != parts[0]) && reservedAliases.contains(parts[0]) == false) {
              if (communityRequest != null) cancelRequest(communityRequest);

              var code = parts[0];

              var entity = getCommunityFromCache(code: code);

              if (entity != null) {
                loadCommunityByCode(community: entity);
              } else {
                communityRequest = new WebSocketRequest()
                  ..path = '/main/findEntity'
                  ..parameters = {
                    'code': code,
                    'findFollows': true,
                    'moreFollows': true,
                };

                needsNotShowApplication = true;
                loadingPage = true;

                var savedUserStates;
                if(platform.user != null && platform.user.states != null) {
                  savedUserStates = platform.user.states;
                }

                sendRequest(communityRequest).then((response) {
                  if(response.success == false){
                    return;
                  }
                  if(savedUserStates != null) {
                    platform.user.states = savedUserStates;
                  }

                  var entity = response.data;
                  if(entity == null){
                    loadingPage = false;
                    notFoundPage = true;
                    return;
                  }

                  if (entity is Map) {
                    entity = entity['entity'];
                  }

                  if (entity.dbType == 'Community') {
                    var community = response.data;

                    loadCommunityByCode(community: entity);
                  } else if (entity.dbType == 'Group') {
                    var group = response.data;

                    loadGroupByCode(code: group.code);
                  }
                });
              }
            } else {
              if (communityRequest != null) cancelRequest(communityRequest);

              // Make sure we get rid of the group if needed.
              if (group != null && parts[0] != group.code) {
                group = null;
              }
            }

            // Get rid of the first part, since it's community/group and we already dealt with it.
            // Just make sure it's not a reserved alias.
            if (reservedAliases.contains(parts[0]) == false) {
              parts = parts.sublist(1);
            }
          } else {
            if (group == null || group.code != parts[0]) {
              if (reservedAliases.contains(parts[0]) == false) {
                if (communityRequest != null) cancelRequest(communityRequest);

                loadingPage = true;

                needsNotShowApplication = true;

                communityRequest = new WebSocketRequest()
                  ..path = '/main/findEntity'
                  ..parameters = {
                    'code': parts[0],
                };

                sendRequest(communityRequest).then((response) {
                  var group = response.data;
                  if (group != null) {
                    group = response.data;

                    loadGroupByCode(group: group);
                    parts = parts.sublist(1);
                  } else {
                    needsNotShowApplication = false;
                    loadingPage = false;
                    group = null;
                  }

                  continueProcessing();
                });
              } else {
                needsNotShowApplication = false;
                loadingPage = false;
                group = null;

                continueProcessing();
              }
            } else {
              parts = parts.sublist(1);

              continueProcessing();
            }

            return;
          }

          break;
      }
    } else {
      group = null;

      if (isUnderCommunityDomain == false) {
        community = null;
      }
    }

    continueProcessing();
  }

  var mobileLayoutWidth = 500;

  void setMobileLayoutWidth(int width) {
    if (isMobile) {
      mobileLayoutMaxWidth = width;
      window.document.query('meta[name="viewport"]').setAttribute('content', 'width=device-width');

      var scale = (document.documentElement.clientWidth / width).toStringAsPrecision(2);

      //window.document.query('#application-root-container').style.width = '${width}px';
      window.document.query('.content-area').style.width = '${width}px';
      window.document.query('meta[name="viewport"]').setAttribute('content', 'width=$width,initial-scale=$scale,minimum-scale=0.1,maximum-scale=5');
    }
  }

  void disableMobileZoom() {
    var e = window.document.query('meta[name="viewport"]');
    e.setAttribute('content', "${e.getAttribute('content')},user-scalable=no");
  }

  void enableMobileZoom() {
    var e = window.document.query('meta[name="viewport"]');
    e.setAttribute('content', e.getAttribute('content').replaceFirst(',user-scalable=no', ''));
  }

  void enableMobileZoomHack(input) {}

  int get mobileScreenHeight => window.innerHeight;

  /**
   * Generates a URL.
   */
  String generateUrl(String path, {community, group, code, log: false}) {
    var url = '';

    var communityCode = getCommunityCodeFromHost();

    if (community != null && code == null) code = community.code;
    if (group != null) code = group.code;

    // We are in totally different domain.
    if (isUnderDifferentDomain()) {
      // But the domain we are in, is different from the one we wanted to link to.
      if (community == null || community.domains == null || community.domains.contains(window.location.hostname) == false) {
        // Create an absolute URL.
        var firstPart = '${window.location.protocol}//${config['hostName'][0]}';
        if (window.location.port != 80 && window.location.port != '') firstPart = '$firstPart:${window.location.port}';

        if (community != null) return '$firstPart/${code}$path';
        else return '$firstPart$path';
      } else if (group == null) {
        return path;
      } else {
        return '/${group.code}$path';
      }
    }

    // We are in sub-domain.
    else if (communityCode != null && communityCode != 'www' && communityCode != '') {
      // But the sub-domain we are in, is different from the one we wanted to link to.
      if (community == null || community.code != communityCode) {
        // Create an absolute URL.
        var firstPart = '${window.location.protocol}//${config['hostName'][0]}';
        if (window.location.port != 80) firstPart = '$firstPart:${window.location.port}';

        if (community != null) return '$firstPart/${code}$path';
        else return '$firstPart$path';
      } else {
        return path;
      }
    }

    // We are in woven domain, just alter the path please.
    else {
      if (community != null) {
        return '/${code}$path';
      } else if (group != null) {
        return '/${code}$path';
      } else {
        return path;
      }
    }
  }

  /**
   * Loads a group by code.
   */
  loadGroupByCode({String code, model.Group group}) {
    void next(group) {
      this.group = group;
      showApplication = true;
      loadingPage = false;
      onGroupChangeController.add(true);

      if (group != null) {
        firstTimeLoadedEntity = false;

        // Make sure that community is proper.
        if (community != null && (community.groupIds == null || community.groupIds.contains(group.id) == false)) {
          community = null;
        }
      } else {
        notFoundPage = true;
      }
    }

    if (group != null) {
      next(group);
    } else {
      communityRequest = new WebSocketRequest()
        ..path = '/main/findEntity'
        ..parameters = {
          'code': code,
      };

      sendRequest(communityRequest).then((response) {
        if (response.data == null) {
          return next(null);
        }

        var group = response.data;

        next(group);
      });
    }
  }

  model.Community getCommunityFromCache({String code}) {
    var entity;

    if (mainViewModel == null) return null;

    mainViewModel.communityViewModels.forEach((id, vm) {
      if (vm.community.code == code) entity = vm.community;
    });

    return entity;
  }

  /**
   * Loads a community by code.
   */
  loadCommunityByCode({String code, model.Community community}) {
    void next(community) {
      showApplication = true;

      if (community == null) {
        this.community = null;
        loadingPage = false;
        notFoundPage = true;
        return;
      }

      firstTimeLoadedEntity = false;

      this.community = community;

      // Make sure that group is proper.
      //if (group != null && community.groupIds.contains(group.id) == false) {
      group = null;
      //}

      loadingPage = false;
      onCommunityChangeController.add(true);
    }

    if (community != null) {
      next(community);
    } else {
      if (communityRequest != null) cancelRequest(communityRequest);

      communityRequest = new WebSocketRequest()
        ..path = '/main/findEntity'
        ..parameters = {
          'code': code,
      };

      sendRequest(communityRequest).then((response) {
        var community = response.data;

        next(community);
      });
    }
  }

  var communityWasPreloaded;

  /**
   * Loads the initial data such as group information.
   */
  loadInitialData() {
    if (isAndroid) window.alert('load initial data()');
    var completer = new Completer();
    onReady = completer.future;

    // Wait until CSS has loaded before we display our app.
    if (window.document.query('body').getComputedStyle().color == 'rgb(0, 0, 1)') {
      hasLoadedContent = true;
    } else {
      // Try to find the CSS.
      //var appCss = window.document.query('#application-css');
      //appCss.onLoad.listen((_) {
      hasLoadedContent = true;
      //});
    }

    // Set the Facebook JS SDK.
    var facebookAppId = config['authentication']['facebook']['appId'];
    facebookSdk = new ScriptElement()
      ..src = '//connect.facebook.net/en_US/all.js#xfbml=1&appId=$facebookAppId'
      ..async = true
      ..defer = true
      ..id = 'facebook-jssdk';

    twitterSdk = new ScriptElement()
      ..src = '//platform.twitter.com/widgets.js'
      ..async = true
      ..defer = true
      ..id = 'twitter-wjs';

    tinyMce = new ScriptElement()
      ..src = '//tinymce.cachefly.net/4.0/tinymce.min.js'
      ..async = true
      ..defer = true;

    var analytics = new ScriptElement()
      ..src = '//www.google-analytics.com/ga.js'
      ..async = true
      ..defer = true;

    void continueProcessing() {
      if (online == false) return;
      if (isAndroid) window.alert('continue processing()');

      signIn();
    }

    // Load entity and user from the document if they exist.
    try {
      var entry = new DataSerializer(database: database).deserialize(JSON.decode(sharedUtil.htmlDecode(window.document.query('#entity-json-container').innerHtml)));
      var toString = entry['entity'].toString();
      if (toString.startsWith('Community')) {
        community = entry['entity'];
        communityWasPreloaded = community.id;
      } else if (toString.startsWith('Group')) {
        group = entry['entity'];
      }
    } catch (e) {
      print('Initial data error: $e');
    }

    dispatcher.resolve();

    // Load user from the DOM.
    try {
      user = new DataSerializer(database: database).deserialize(JSON.decode(sharedUtil.htmlDecode(window.document.query('#user-json-container').innerHtml)));
      if (user != null) {
        canShowLogin = true;
        user.needsToFollowCommunities = user.followedCommunities.length == 0;
        checkUserState();
      }
    } catch (e) {
      print('Initil data error: $e');
    }

    if (online) {
      continueProcessing();
    } else {
      onOnlineStateUpdate.listen((_) => continueProcessing());
    }

    facebookSdk.onLoad.listen((_) => facebookSdkLoaded = true);
    twitterSdk.onLoad.listen((_) => twitterSdkLoaded = true);

    document.body.children
      ..add(facebookSdk)
      ..add(twitterSdk)
      ..add(analytics);
  }

  /**
   * Tries to sign in.
   */
  Future signIn() {
    return sendRequest(new WebSocketRequest(path: '/user/getCurrentUser')).then((response) {
      if (response.data == null) user = null;
      else {
        user = response.data['user'];
        userAvailable.forEach((f) => f());
        userAvailable = [];
      }

      if (user != null) {
        if (response.data['followedCommunityObjects'] != null) {
          if (user.followedCommunityObjects == null) user.followedCommunityObjects = [];
          user.followedCommunityObjects.clear();
          user.followedCommunityObjects.addAll(response.data['followedCommunityObjects']);
        }

        user.hasPassword = response.data['hasPassword'];
        user.hasEmail = response.data['hasEmail'] && user.email != null && user.email != '';
        user.locationName = user.locationFreeText;
        if (user.locationFreeText == null || user.locationFreeText == '') user.locationFreeText = user.locationName;

        checkUserState();

        //var item = 'youHaveAlreadyRequestedInvitation';
        //if (response.data['requestedInvitation'] && globalMessages.contains(item) == false) globalMessages.add(item);

        if (user.states == null) user.states = [];
        user.states = toObservable(user.states);

        if (user.active == true && user.boarded && !user.states.contains('ignoreIntroductionFlow')) user.states.add('showTogglePersonalBarTooltip');
      }

      canShowLogin = true;
    });
  }

  void checkUserState() {
    user.needsToFollowCommunities = user.followedCommunities == null || user.followedCommunities.length == 0;

    if (user.boarded != true && user.active == true && user.isAdmin != true) {
      if (user.invitationRequestedFromId == null) dispatcher.dispatch(url: '/getstarted');
    }

    if (user.boarded != true && user.active == false && user.isAdmin != true) {
      dispatcher.dispatch(url: '/onboard');
    }
  }

  var webSocketLastPortFailedIndex = -1; // The port that was used last time and failed to connect.
  List webSocketPortsToTry = [443, 80]; // 443 is default, as it works best.

  /**
   * Establishes the connection to the server and sets up listeners.
   */
  establishConnection() {
    webSocketLastPortFailedIndex++;
    if (webSocketLastPortFailedIndex >= webSocketPortsToTry.length) webSocketLastPortFailedIndex = 0;

    var port = webSocketPortsToTry[webSocketLastPortFailedIndex];

    if (connection == null || connection.readyState == WebSocket.CLOSED) {
      //print('Establishing WebSocket at ' + window.performance.now().toString());
      connection = supportsWebSockets() ? new WebSocket('ws://${config['webSocketHost']}:${port}/ws') : new LongPolling();

      // TODO: Find better way!
      if (!isMobile) connection.binaryType = 'arraybuffer';

      connection
        ..onOpen.listen((_) => invalidateOnlineState())
        ..onClose.listen((e) => invalidateOnlineState())
        ..onMessage.listen((e) {
        // LongPolling library returns data directly, but WebSockets return MessageEvent object.
        // dart2js seems to have lots of bugs with type detection, especially with some mobile devices so we use .toString().
        onResponse(connection.toString() == 'LongPolling' ? e : e.data);
      });
    }
  }

  var retryConnectionTimer;
  bool hasGoneOffline = false;

  enableFun() {
    js.context['fartscroll']();
  }

  @observable var backgroundImage = 'none';

  setBackground(url) {
    if (url == null || url == '') backgroundImage = 'none';

    if (config['enableCdn'] == true) {
      backgroundImage = 'url(http://cdn.woven.co${url})';
    } else {
      backgroundImage = 'url($url)';
    }
  }

  /**
   * Checks if the application is still online.
   */
  invalidateOnlineState() {
    var currentState = false;

    if (connection is WebSocket && connection.readyState == WebSocket.OPEN) currentState = true;

    online = currentState;

    // Damn we went offline. Make sure we "log out" the user, i.e. destroy it from memory.
    if (online == false) {
      // Complete all existing requests with success = false.
      requestCompleters.forEach((id, completer) {
        if (config['local']) print('Could not complete request, because we are offline. If you are developing a new feature, make sure you send requests ONCE you are online (platform.online, platform.onOnlineStateUpdate, etc.)!');

        completer.complete(new WebSocketResponse()
          ..success = false
          ..message = offlineMessage);
      });

      requestCompleters.clear();

      hasGoneOffline = true;

      // Upon connection close, wait a while and try to re-connect.
      new Timer(new Duration(seconds: isAdmin ? 1 : 5), establishConnection);
    } else {
      // Re-request images.
      window.document.queryAll('img').forEach((ImageElement img) {
        if (img.clientWidth == null || img.clientWidth == 0) {
          if (img.src != '') {
            var old = img.src;
            img.src = 'about:blank';
            img.src = old;
          }
        }
      });

      if (retryConnectionTimer != null) {
        retryConnectionTimer.cancel();
        retryConnectionTimer = null;
      }

      loadStuff();
    }

    onOnlineStateUpdateController.add(true);
  }

  /**
   * On server response for some request.
   */
  onResponse(data) {
    if (data == null) {
      print('Warning: no data received from the server!');
      return;
    }

    var networkDataSize;

    // Must be ZLIB compressed.
    if (data is! String) {
      networkDataSize = data.lengthInBytes;
      try {
        var inflater = new js.Proxy(js.context.Zlib.Inflate, js.array(new Uint8List.view(data)));
        var c = inflater.decompress();
        data = UTF8.decode(c);
      } catch (e) {
        print('Decompression failed: $e');
      }
    } else {
      networkDataSize = data.length;
    }

    var parsingWatcher = new Stopwatch()..start();

    WebSocketResponse response;
    try {
      response = new WebSocketResponse.fromMap(JSON.decode(data), mergeReferences: true, database: database);
    } catch (e) {
      print('Could not parse WebSocket response. The error was: $e and content was: $data');
      return;
    }

    var parsingTime = parsingWatcher.elapsed;
    var serverTook;
    var networkTook;

    try {
      downloadBytesTransferred += networkDataSize;

      new Timer(const Duration(seconds: 10), () {
        downloadBytesTransferred -= networkDataSize;
      });

      if (data.length > 2000) {
        var now = new DateTime.now();
        serverTook = response.requestProcessingTime;
        var sentAt = requestSendDates[response.id];
        networkTook = new DateTime.now().difference(sentAt.add(parsingTime)).inMilliseconds - serverTook;

        if (isAdmin) print('"${requestPaths[response.id]}" totaling ${(data.length / 1024).toStringAsFixed(2)} kB (network size: ${(networkDataSize / 1024).toStringAsFixed(2)} kB). Server took ${serverTook}ms?, network took ${networkTook}ms.');
      }
    } catch (e) {
      print('Non-important error: $e');
    }

    if (response.className == null) {
      if (requestCompleters.containsKey(response.id)) {
        // Standard WebSocketResponse to some request. Figure out the completer to use.
        requestCompleters[response.id].complete(response);

        // Remove the callback and request.
        requestCompleters.remove(response.id);

        requestPaths.remove(response.id);
      }
    } else {
      // Special case (e.g. data update notification).
      switch (response.className) {
        case 'DataChange':
          data.handleResponse(response);
          break;
        case 'DataNotification':
          var n = new DataNotification.fromMap(response.data);

          dataUpdateStreamController.add(n);
          break;
      }
    }
  }

  /**
   * Sends a request over the WebSocket connection.
   *
   * Use this for sending requests to the server, much like traditional AJAX requests.
   */
  Future<WebSocketResponse> sendRequest(WebSocketRequest request) {
    request.parameters['woven-session'] = readCookie('woven-session');

    // Since we have a single WS connection, the incoming messages need to be mapped
    // to the right "callbacks". We use Futures here, and therefore we store Completers
    // for future reference.

    var completer = new Completer();

    // Set the new ID, and keep reference to the completer and ID. Skip if it's already set.
    request.id = ++lastRequestId;
    request.database = database;

    if (online) {
      requestCompleters[request.id] = completer;

      requestSendDates[request.id] = new DateTime.now();

      requestPaths[request.id] = request.path;

      var content = JSON.encode(request);

      // Only use compression for desktop & WebSocket.
      if (!isMobile && supportsWebSockets()) {
        var deflater = new js.Proxy(js.context.Zlib.Deflate, js.array(UTF8.encode(content)));
        content = deflater.compress();

        uploadBytesTransferred += content.length;
        requestsSent += 1;

        new Timer(const Duration(seconds: 10), () {
          requestsSent -= 1;
        });

        new Timer(const Duration(seconds: 10), () {
          uploadBytesTransferred -= content.length;
        });
      }

      connection.send(content);
    } else {
      completer.complete(new WebSocketResponse()
        ..success = false
        ..message = offlineMessage);
    }

    return completer.future;
  }

  /**
   * Cancels the request.
   */
  void cancelRequest(WebSocketRequest request) {
    if (request == null) return;

    requestCompleters.remove(request.id);
  }

  /**
   * A helper method for reading a cookie.
   */
  String readCookie(String name) {
    String nameEQ = '$name=';
    List<String> ca = document.cookie.split(';');
    for (int i = 0; i < ca.length; i++) {
      String c = ca[i];
      c = c.trim();
      if (c.indexOf(nameEQ) == 0) {
        return c.substring(nameEQ.length);
      }
    }
    return null;
  }

  void createCookie(String name, String value, int days) {
    String expires;

    if (days != null)  {
      DateTime now = new DateTime.now();
      DateTime date = new DateTime.fromMillisecondsSinceEpoch(now.value + days*24*60*60*1000, isUtc: false);
      expires = '; expires=' + date.toString();
    } else {
      DateTime then = new DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      expires = '; expires=' + then.toString();
    }

    document.cookie = name + '=' + value + expires + '; path=/;domain=.${config["hostName"].replaceFirst('www.', '')}';
  }

  void eraseCookie(String name) {
    createCookie(name, '', 0);
  }

  /**
   * Returns true if the data notification matches the current context (group/community).
   */
  bool dataNotificationMatchesContext(notification, {community, group}) {
    if (group == null) group = this.group;
    if (community == null) community = this.community;

    if (notification.communityIds.length > 0) {
      if (this.community == null) return false;

      if (notification.communityIds.contains(this.community.id) == false) return false;
    }

    if (notification.groupIds.isEmpty) {
      return true;
    }

    if (this.group != null) {
      var matches = notification.groupIds.contains(this.group.id);
      return matches;
    } else if (this.community != null) {
      if (this.community.groupIds == null) return false;

      var matches = notification.groupIds.any((id) => this.community.groupIds.contains(id));
      return matches;
    }

    return true;
  }

  @observable String windowTitle;

  void setTitle(String title) {
    window.document.query('title').text = title;
    windowTitle = title;
  }

  String getTitle() {
    return window.document.query('title').text;
  }

  var _refreshContentController = new StreamController.broadcast();
  get onRefreshContent => _refreshContentController.stream;

  void refreshTitle() {
    _refreshContentController.add(true);
  }

  bool supportsWebSockets() {
    if (!WebSocket.supported) return false;

    // Ugly. Safari 6.0 does not support binary web sockets, is there a better way to detect?
    if (window.navigator.userAgent.contains('Version/6.0') && window.navigator.userAgent.contains('Safari/') && !window.navigator.userAgent.contains('Chrome')) return false;

    return true;
  }

  bool followingAnyGroupInCommunity([community]) {
    if (user == null) return false;

    if (user.followedGroups == null) return false;

    if (community == null) return false;

    return community.groupIds.any((id) {
      return user.followedGroups.any((groupId) => groupId == id);
    });
  }

  /**
   * Makes the current user to (un)like something.
   */
  like(target) {
    var targetId = target.id;
    var like = user.likedStuff.contains(targetId) == false;

    if (like) {
      user.likedStuff.add(targetId);
    } else {
      user.likedStuff.remove(targetId);
    }

    var request = new WebSocketRequest()
      ..path = '/user/like'
      ..parameters = {
        'like': like,
        'dbType': target.dbType,
        'targetId': targetId
    };

    sendRequest(request);
  }

  vote(target, value, {bool adminVote: false}) {
    var targetId = target.id;

    if (target.votes == null) {
      target.votes = 0;
    }

    target.isVoted = !target.isVoted;

    if (target.isVoted == false) {
      target.votedBy.removeWhere((u) => u.id == user.id);

      if (target.votedByFriends != null) {
        target.votedByFriends.removeWhere((u) => u.id == user.id);
      }
    }
    else {
      target.votedBy.add(platform.user);
      //autoShareToFacebook(target);
    }

    if (value > 0) {
      ++target.votes;
    }
    else if (value < 0) {
      --target.votes;
    }
    else {
      if (target.isVoted) {
        ++target.votes;
      }
      else {
        --target.votes;
      }
    }

    var request = new WebSocketRequest()
      ..path = '/user/vote'
      ..parameters = {
        'value': value,
        'dbType': target.dbType,
        'targetId': targetId,
        'adminVote': adminVote,
        'communityId': platform.community != null ? platform.community.id : null
    };

    sendRequest(request);
  }

  autoShareToFacebook(item) {
    if (item.dbType != 'Event' && item.dbType != 'NewsArticle' && item.dbType != 'Video') return; // TODO: test other types

    if (!checkIfUserAutoShares()) return;

    platform.sendRequest(new WebSocketRequest()
      ..path = '/facebook/getPermissions'
    ).then((response) {

      //print(item.dbType);
      //print(item);

      var itemImage;

      if (item.dbType == 'Event') {
        itemImage = item.image;
      }
      else {
        if (item.images.length > 0) {
          itemImage = item.images[0];
        }
      }

      if (itemImage != null) {
        itemImage = Uri.encodeComponent(itemImage);
      }

      // User is already logged in with permissions.
      if (response.success) {
        platform.sendRequest(new WebSocketRequest()
          ..path = '/facebook/shareItemWebSocket'
          ..parameters = {
            'item': {
                'dbType': item.dbType,
                'title': item.title,
                'description': item.description,
                'teaser': item.description,
                'id': item.id,
                'image': itemImage
            },
            'userFbId': platform.user.facebookId
        });
      }
      else {  // Pop-up a dialog asking for sign in and permissions.
        var path = window.location.href;
        var domain = Uri.encodeComponent('${window.location.origin}¤$path');
        var appId = config['authentication']['facebook']['appId'];
        var url = 'http%3A%2F%2F${config["hostName"][0]}/facebook/shareItemWebService';

        var itemTitle = (item.title != null) ? Uri.encodeComponent(item.title) : null;
        var itemDescription = (item.description != null) ? Uri.encodeComponent(item.description) : null;
        var itemTeaser = (item.teaser != null) ? Uri.encodeComponent(item.teaser) : null;

        var buff = new StringBuffer('https://www.facebook.com/dialog/oauth/?page=popup&');
        buff.write('client_id=$appId&');
        buff.write('redirect_uri=$url&');
        buff.write('state=${item.dbType}$itemTitle¤$itemDescription¤$itemTeaser¤${item.id}$itemImage&');
        buff.write('scope=email,user_location,publish_actions');

        window.open(buff.toString(), "Facebook Login", "status = 1, height = 350, width = 860");//, resizable = 0
      }
    });
  }

  bool checkIfUserAutoShares() {
    if (platform.user.autoShareToFb != null && platform.user.autoShareToFb) {
      return true;
    }

    if (platform.user.autoShareToFb == null && window.confirm('Woven can post your likes to Facebook. Would you like to turn this feature on? (You can always turn this off later)')) {
      platform.sendRequest(new WebSocketRequest()
        ..path = '/facebook/updateUserAutoShare'
        ..parameters = {
          'autoShareToFb': true
      });

      platform.user.autoShareToFb = true;
      return true;
    }
    else {
      platform.sendRequest(new WebSocketRequest()
        ..path = '/facebook/updateUserAutoShare'
        ..parameters = {
          'autoShareToFb': false
      });

      platform.user.autoShareToFb = false;
      return false;
    }
  }

  var fullScreenResizeListener;
  var fullScreenIframe;

  enableFullScreenViewerFor(iframe) {
    resize() {
      iframe.style.width = '${window.innerWidth}px';
      iframe.style.height = '${window.innerHeight - 48}px';
    }

    fullScreenIframe = iframe;

    document.body.scrollTop = 0;
    document.body.scrollLeft = 0;

    document.body.style.overflow = 'hidden';
    resize();
    fullScreenViewing = true;

    fullScreenResizeListener = window.onResize.listen((_) {
      resize();
    });
  }

  disableFullScreenViewerFor(iframe, {leave: false}) {
    if (iframe == null) iframe = fullScreenIframe;

    if (leave) {
      window.location.href = iframe.src;
      showApplication = false;
      return;
    }

    document.body.style.overflow = 'auto';
    fullScreenViewing = false;
    if (fullScreenResizeListener != null) {
      fullScreenResizeListener.cancel();
      fullScreenResizeListener = null;
    }
  }

  void resetScroll({int amount: 1, bool force, skipTop: false}) {
    if (isMobile || force) {
      if (skipTop) {
        var c = window.document.query('.mobile-navigation');
        if (c != null) amount = c.clientHeight;
      }

      window.scrollTo(0, amount);
    } else {
      document.body.scrollTop = 0;
    }
  }

  String getNameForUser(target) {
    if (target == null) return 'Woven';

    return user == null || target.id != user.id ? target.name : 'You';
  }

  @observable bool _isMobile;

  bool get isMobile {
    if (_isMobile == null) {
      //http://stackoverflow.com/questions/11381673/javascript-solution-to-detect-mobile-browser
      var a = window.navigator.userAgent;

      if (window.screen.width < 640 ||
      a.contains('Android') ||
      a.contains('webOS') ||
      a.contains('iPhone') ||
      a.contains('iPad') ||
      a.contains('iPod') ||
      a.contains('BlackBerry') ||
      a.contains('Windows Phone')
      ) {
        _isMobile = true;
      } else {
        _isMobile = false;
      }
    }

    return _isMobile;
  }

  set isMobile(bool value) => _isMobile = value;

  void hideMobileAddressBar() {
    if (isMobile && document.body.scrollTop == 0) {
      Timer.run(() {
        if (group != null || community != null) window.scrollTo(0, 48);
        else window.scrollTo(0, 1);
      });
    }
  }

  int getLimitFromScreenSize() {
    return max(10, (window.innerWidth / (253) * (window.innerHeight - 150) / 150).ceil());
  }

  void refreshPage() {
    var page = router.parameters['page'];

    if (page == 'refreshing') return;

    router.parameters['page'] = 'refreshing';

    Timer.run(() {
      Timer.run(() {
        var currentPage = router.parameters['page'];
        if (page != currentPage && currentPage != 'refreshing') page = currentPage;

        router.parameters['page'] = page;
      });
    });
  }

  String htmlDecode(String text) {
    if (text == null) {
      return '';
    }

    return text.replaceAll("&amp;", "&")
    .replaceAll("&lt;", "<")
    .replaceAll("&gt;", ">")
    .replaceAll("&quot;", '"')
    .replaceAll("&apos;", "'")
    .replaceAllMapped(new RegExp('&#([0-9]+);'), (Match match) {
      try {
        var value = int.parse(match.group(1));
        var character = new String.fromCharCode(value);

        return character;
      } catch (e) {
        return '';
      }
    });
  }

  void hideScrollbars() {
    window.document.query('body').style.overflow = 'hidden';
  }

  void showScrollbars() {
    window.document.query('body').style.overflow = 'auto';
  }

  bool disableScroll = false;
  int scrollbarWidth;

  int getScrollbarWidth() {
    if (scrollbarWidth != null) return scrollbarWidth;

    var outer = new Element.tag("div");
    outer.style.visibility = "hidden";
    outer.style.width = "100px";
    document.body.children.add(outer);

    var widthNoScroll = outer.offsetWidth;
    // Force scrollbars.
    outer.style.overflow = "scroll";

    // Add innerdiv.
    var inner = new Element.tag("div");
    inner.style.width = "100%";
    outer.children.add(inner);

    var widthWithScroll = inner.offsetWidth;

    // Remove divs.
    outer.remove();

    scrollbarWidth = widthNoScroll - widthWithScroll;

    return scrollbarWidth;
  }

  @observable bool hasAccess(entity, {wikiStyle: false}) {
    if (entity == null || user == null) return false;

    if (user != null && user.isAdmin) return true;

    if (wikiStyle) {
      if (platform.user == null) return false;

      if (entity.managers.any((m) => m.id == user.id)) return true;

      return entity.managers.length == 0;
    }

    if (entity.managers.any((m) => m.id == user.id)) return true;

    return false;
  }

  void markAsRead(item) {
    if (user == null) return;

    sendRequest(new WebSocketRequest(path: '/user/markAsRead')..parameters = {'id': item.id});

    user.readStuff.add(item.id);
  }

  void dismiss(id) {
    if (user.dismissedStuff == null) user.dismissedStuff = [];
    user.dismissedStuff.add(id);
    sendRequest(new WebSocketRequest(path: '/user/dismiss')..parameters = {'id': id});
  }

  void logout() {
    platform.sendRequest(new WebSocketRequest(path: '/logout')).then((_) {
      dispatcher.dispatch(url: '/');
      user = null;
      showPersonalizedViews = false;
      refreshPage();
    });
  }

  void addVotedBys(item, list) {
    if (list != null) {
      if (item.votedBy == null) item.votedBy = toObservable([]);

      list.forEach((v) {
        if (item.votedBy.any((u) => u.id == v.id) == false) {
          void cb() {
            if (user != null && user.id == v.id) {
              item.isVoted = true;
              //user.votedUpStuff.add(item.id);
            }
          }

          if (online == false) userAvailable.add(cb);

          cb();
          item.votedBy.add(v);
        }
      });
    }
  }

  /**
   * TODO: In the future with time, we should build proper i18n support.
   */
  String t(String input) {
    if (isSpanish) {
      switch (input) {
        case 'Today': return 'Hoy';
        case 'Tomorrow': return 'Mañana';
        case 'Happening now': return 'En este momento';
        case 'Happened': return 'Ocurrió';
        case 'ago': return 'atrás';
        case 'News': return 'Noticias';
        case 'Say something': return 'Di algo';
        case 'Express yourself': return 'Di algo';
        case 'Share your thoughts': return 'Di algo';
        case 'Event': return 'Evento';
        case 'Video': return 'Video';
        case 'Live activity': return 'Actividad en vivo';
        case 'Photo': return 'Foto';
        case 'Tweet': return 'Tweet';
        case 'Videos': return 'Videos';
        case 'Photos': return 'Fotos';
        case 'Load more': return 'Más';
        case 'See realtime event activity': return 'Mira la actividad del evento';
        case 'Link': return 'Link';
        case 'Close': return 'Cerrar';
        case 'Share': return 'Compartir';
        case 'Join me on': return 'Únete a toda la información de';
        case 'on Woven.': return 'con Woven.';
        case 'Click me': return 'Haz click';
        case 'Sign in with your email address': return 'Regístrate con tu mail';
        case 'Your email': return 'Tu mail';
        case 'Your name': return 'Tu nombre';
        case 'Sign up': return 'Regístrate';
        case 'Continue': return 'Continúa';
        case 'Your password': return 'Contraseña';
        case 'Your new password': return 'Tu nueva contraseña';
        case "It's quiet around here": return 'Es tranquilo por aquí';
        case 'Search': return 'Buscador';
        case 'Feedback': return 'Feedback';
        case 'Help Center': return 'Ayuda';
        case 'Welcome to Woven': return 'Bienvenida a Woven';
        case 'Go to latest stuff': return 'Anda a lo último';
        case 'Invite friends to this page.': return 'Invita a tus amigos a esta página';
        case 'Woven will start gathering activity 2 hours before the event.': return 'Woven empezará a mostrarte toda la actividad 2 horas antes de este evento.';
        case 'Not much activity yet.': return 'No hay mucha actividad hasta el momento.';
        case 'This is your personal bar. Jump to your inbox, pages you follow, search and more.': return 'Esta es tu barra personal. Navega a tu inbox, páginas que sigues, redes, búsquedas y más.';
        case 'This is your notifications bar. See important activity about your shares and from your friends.': return 'Esta es tu barra de notificaciones. Revisa toda la actividad sobre la información que compartiste y la de tus amigos.';
        case 'More': return 'Más';
        case 'new': return 'más';
        case 'Live': return 'En vivo';
        case 'Event details': return 'Detalles del evento';
        case 'Sign in to request an invitation.': return 'Regístrate para solicitar tu código.';
        case 'Be first to comment' : return 'Se el primero en comentar';
      }
    }

    return input;
  }
}

void main() {
  if (isAndroid) window.alert('main()');

  if(window.location.hostname != "woven.local"){
    print('''
8b      db      d8  ,adPPYba,  8b       d8  ,adPPYba,  8b,dPPYba,
`8b    d88b    d8' a8"     "8a `8b     d8' a8P_____88  88P'   `"8a
 `8b  d8'`8b  d8'  8b       d8  `8b   d8'  8PP"""""""  88       88
  `8bd8'  `8bd8'   "8a,   ,a8"   `8b,d8'   "8b,        88       88
    YP      YP      `"YbbdP"'      "8"      `"Ybbd88"  88       88

Hi there! Please follow us at twitter.com/wovenco and facebook.com/woven.

''');
  }

  database.dataMapDecorator = (m) => toObservable(m);
  database.dataListDecorator = (m) => toObservable(m);
  database.useCache = true;

  database
    ..registerClass(model.NewsArticle,() => new model.NewsArticle(), () => new List<model.NewsArticle>())
    ..registerClass(model.NewsFeed,() => new model.NewsFeed(), () => new List<model.NewsFeed>())
    ..registerClass(model.Group,() => new model.Group(), () => new List<model.Group>())
    ..registerClass(model.Community,() => new model.Community(), () => new List<model.Community>())
    ..registerClass(model.Place,() => new model.Place(), () => new List<model.Place>())
    ..registerClass(model.User,() => new model.User(), () => new List<model.User>())
    ..registerClass(model.ContactDetail,() => new model.ContactDetail(), () => new List<model.ContactDetail>())
    ..registerClass(model.ContactDetailOption,() => new model.ContactDetailOption(), () => new List<model.ContactDetailOption>())
    ..registerClass(model.Duplicates,() => new model.Duplicates(), () => new List<model.Duplicates>())
    ..registerClass(model.Type,() => new model.Type(), () => new List<model.Type>())
    ..registerClass(model.Tag,() => new model.Tag(), () => new List<model.Tag>())
    ..registerClass(model.Category,() => new model.Category(), () => new List<model.Category>())
    ..registerClass(model.Joined,() => new model.Joined(), () => new List<model.Joined>())
    ..registerClass(model.Follow,() => new model.Follow(), () => new List<model.Follow>())
    ..registerClass(model.Tweet,() => new model.Tweet(), () => new List<model.Tweet>())
    ..registerClass(model.Text,() => new model.Text(), () => new List<model.Text>())
    ..registerClass(model.Link,() => new model.Link(), () => new List<model.Link>())
    ..registerClass(model.Question,() => new model.Question(), () => new List<model.Question>())
    ..registerClass(model.Discussion,() => new model.Discussion(), () => new List<model.Discussion>())
    ..registerClass(model.TagGroup,() => new model.TagGroup(), () => new List<model.TagGroup>())
    ..registerClass(model.Event,() => new model.Event(), () => new List<model.Event>())
    ..registerClass(model.Message,() => new model.Message(), () => new List<model.Message>())
    ..registerClass(model.Reminder,() => new model.Reminder(), () => new List<model.Reminder>())
    ..registerClass(model.Log,() => new model.Log(), () => new List<model.Log>())
    ..registerClass(model.ItemScore,() => new model.ItemScore(), () => new List<model.ItemScore>())
    ..registerClass(model.Setting,() => new model.Setting(), () => new List<model.Setting>())
    ..registerClass(model.FacebookPost,() => new model.FacebookPost(), () => new List<model.FacebookPost>())
    ..registerClass(model.Vote,() => new model.Vote(), () => new List<model.Vote>())
    ..registerClass(model.Ad,() => new model.Ad(), () => new List<model.Ad>())
    ..registerClass(model.CommunityModule,() => new model.CommunityModule(), () => new List<model.CommunityModule>())
    ..registerClass(model.Badge,() => new model.Badge(), () => new List<model.Badge>())
    ..registerClass(model.ExpiringCode,() => new model.ExpiringCode(), () => new List<model.ExpiringCode>())
    ..registerClass(model.ItemPromotion,() => new model.ItemPromotion(), () => new List<model.ItemPromotion>())
    ..registerClass(model.ItemRead,() => new model.ItemRead(), () => new List<model.ItemRead>())
    ..registerClass(model.HideItem,() => new model.HideItem(), () => new List<model.HideItem>())
    ..registerClass(model.CommunityGroupLink,() => new model.CommunityGroupLink(), () => new List<model.CommunityGroupLink>())
    ..registerClass(model.Comment,() => new model.Comment(), () => new List<model.Comment>())
    ..registerClass(model.Revision,() => new model.Revision(), () => new List<model.Revision>())
    ..registerClass(model.LatestActivity,() => new model.LatestActivity(), () => new List<model.LatestActivity>())
    ..registerClass(model.FeaturedItem,() => new model.FeaturedItem(), () => new List<model.FeaturedItem>())
    ..registerClass(model.StarredItem,() => new model.StarredItem(), () => new List<model.StarredItem>())
    ..registerClass(model.Comment,() => new model.Comment(), () => new List<model.Comment>())
    ..registerClass(model.Video,() => new model.Video(), () => new List<model.Video>())
    ..registerClass(model.Page,() => new model.Page(), () => new List<model.Page>())
    ..registerClass(model.CustomSource,() => new model.CustomSource(), () => new List<model.CustomSource>())
    ..registerClass(model.SourceInformation,() => new model.SourceInformation(), () => new List<model.SourceInformation>())
    ..registerClass(model.Flag,() => new model.Flag(), () => new List<model.Flag>())
    ..registerClass(model.Photo,() => new model.Photo(), () => new List<model.Photo>())
    ..registerClass(model.SourceFilter,() => new model.SourceFilter(), () => new List<model.SourceFilter>())
    ..registerClass(model.EventFeed,() => new model.EventFeed(), () => new List<model.EventFeed>());

  runZoned(() {
    if (isAndroid) window.alert('inside zone');
    platform = new WovenPlatform();
  }, onError: (e, s) {
    //if (isMobile) window.alert('$e $s');

    var message = 'A severe error was uncaught at ${window.location.href}:\n$e\n\nStacktrace:\n$s';
    print(message);
    //platform.sendRequest(new WebSocketRequest(path: '/main/report')..parameters = {'message': message});
  });
}
