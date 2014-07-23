import 'package:polymer/polymer.dart';  // XXX DO NOT USE SHOW HERE
import "package:google_oauth2_client/google_oauth2_browser.dart" show SimpleOAuth2;
import "package:google_plus_v1_api/plus_v1_api_client.dart" show Person;
import "package:google_plus_v1_api/plus_v1_api_browser.dart" show Plus, Person;
import 'dart:html' show CustomEvent, Element, HttpRequest, Node, ScriptElement, document;
import 'package:logging/logging.dart' show Logger;
import 'dart:convert' show JSON;
import 'dart:async' show Future;
import 'dart:js' as js;

final Logger log = new Logger('google-signin-element');

@CustomTag('google-signin')
class GoogleSignin extends PolymerElement {
  @published String clientId;
  @published String signInMsg;
  @observable String oauthStateToken;
  @observable String gplusId;

  SimpleOAuth2 authenticationContext;
  @observable Plus plusClient;

  GoogleSignin.created() : super.created() {
    log.fine('GoogleSignin created');

    js.context["onSignInCallback"] = (authResult) {
      log.fine('AuthResult callback from G+ signin');
      // TODO is there a better way to get this data over? Is there a dejsify ?
      Map dartAuthResult = JSON.decode(js.context["JSON"].callMethod("stringify", [authResult]));
      _onSignInCallback(dartAuthResult);
    };

    ScriptElement script = new ScriptElement()
      ..type = 'text/javascript'
      ..src = 'https://plus.google.com/js/client:plusone.js'
      ..async = true;
    document.body.append(script);

  }

  _onSignInCallback(Map authResult) {
    log.fine('In signin callback');
    if (authResult["access_token"] != null) {
      log.fine('looks like signin worked!');

      authenticationContext = new SimpleOAuth2(authResult["access_token"], tokenType: authResult["token_type"]);

      plusClient = new Plus(authenticationContext);
      plusClient.makeAuthRequests = true;

      _requestSessionToken()
      .then((_) => plusClient.people.get('me'))
      .then((Person person) => gplusId = person.id)
      .then((_) => _connectWithServer(authResult))
      .then((_) {
        dispatchEvent(new CustomEvent('signincomplete'));
        document.querySelector('#signin').style.display = 'none';
        log.fine('Signin complete!');
      });

    } else if (authResult["error"] != null) {
      log.info("There was an error authenticating: ${authResult["error"]}");

      // Update the app to reflect a signed out user
      // Possible error values:
      //   "user_signed_out" - User is signed-out
      //   "access_denied" - User denied access to your app
      //   "immediate_failed" - Could not automatically log in the user

      dispatchEvent(new CustomEvent('signinerror', detail: authResult["error"]));
    }
  }

  Future _connectWithServer(Map authResult) {
    final String stateToken = oauthStateToken;
    final String url = "/connect?state_token=${stateToken}&gplus_id=${gplusId}";
    log.fine("Connecting with oauth server at $url");

    return HttpRequest.request(url, method: "POST",
    withCredentials: true,
    requestHeaders: {'Content-Type': 'application/json'},
    sendData: JSON.encode(authResult))
    .then((HttpRequest request) {
      log.fine("OAuth2 connected with status ${request.responseText}");
      if (request.status == 401) {
        log.fine("Oauth2 server connect 401: request.responseText = ${request.responseText}");
        return;
      }

    }).catchError((error) {
      log.fine("Oauth2 Server Connect Error: $error");
    });
  }

  /**
   * Request the anti-request forgery state token.
   */
  Future _requestSessionToken() {
    log.fine('Getting state token');
    return HttpRequest.getString("/session", withCredentials: true)
    .then((data) {
      var stateTokenData = JSON.decode(data);
      oauthStateToken = stateTokenData['state_token'];
      log.fine('State token retrieval successful');
    })
    .catchError((error) {
      log.severe("Requesting Session Token Failed: $error");
    });
  }

  // BUG, can't use shadow dom for some reason.
  // See https://code.google.com/p/dart/issues/detail?id=14210
  // See also https://code.google.com/p/dart/issues/detail?id=14230
  // No time to figure it out. Let's use the LightDOM!
  @override
  Node shadowFromTemplate(Element template) {
    var dom = instanceTemplate(template);
    append(dom);
    shadowRootReady(this);
    return null; // no shadow here, it's all bright and shiny
  }

  attached() {
    print("+GoogleSignin");
  }

}