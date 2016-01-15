import 'dart:html';
import 'dart:async';
import 'dart:convert';

import 'package:polymer/polymer.dart';
import 'package:core_elements/core_animation.dart';
import 'package:core_elements/core_input.dart';
import 'package:core_elements/core_a11y_keys.dart';
import 'package:firebase/firebase.dart' as firebase;

import 'package:woven/src/client/app.dart';
import 'package:woven/src/shared/model/user.dart';
import 'package:woven/src/shared/routing/routes.dart';
import 'package:woven/src/shared/response.dart';
import 'package:woven/src/shared/util.dart';
import 'package:woven/src/shared/regex.dart';

@CustomTag('x-home')
class Home extends PolymerElement with Observable {
  @published App app;
  @observable String randomWord = '';
  @observable Map formData = toObservable({});

  var processing = false;
  var processingAnimation = new CoreAnimation();

  firebase.Firebase get f => app.f;

  DateTime get now => new DateTime.now().toUtc();

  CoreInput get username => this.shadowRoot.querySelector('#username');
  CoreInput get password => this.shadowRoot.querySelector('#password');
  CoreInput get firstname => this.shadowRoot.querySelector('#firstname');
  CoreInput get lastname => this.shadowRoot.querySelector('#lastname');
  CoreInput get email => this.shadowRoot.querySelector('#email');
  CoreInput get invitationCode =>
      this.shadowRoot.querySelector('#invitation-code');
  Element get submitButton => this.shadowRoot.querySelector('#submit');

  Home.created() : super.created();

  changeCta(String page) => app.homePageCta = page;

  showSignIn() {
    changeCta('sign-in');

//    if (!app.isMobile) username.autofocus = true;
  }

  showSignUp() => changeCta('sign-up');

  showSignUpNote() => changeCta('sign-up-note');

  showGetStartedNote() => changeCta('get-started-note');

  toggleMain() {
    if (app.user != null) {
      if (app.user.disabled && app.user.onboardingState == 'signUpComplete') {
        app.homePageCta = 'sign-up-note';
      }
      if (app.user.onboardingState == 'temporaryUser') {
        app.homePageCta = 'complete-sign-up';
      }
    } else {
      Uri currentPath = Uri.parse(window.location.toString());

      if (currentPath.pathSegments.contains('confirm') &&
          currentPath.pathSegments[1] != null) {
        var confirmId = currentPath.pathSegments[1].toString();
        handleConfirm(confirmId);
        app.router.dispatch(url: '/');
      } else {
        app.homePageCta = 'sign-up';
      }
    }
  }

  /**
   * Handle the case where user is coming by way of an email confirmation/invite link.
   */
  handleConfirm(String confirmId) async {
    firebase.DataSnapshot snapshot =
        await f.child('/email_confirmation_index/$confirmId').once('value');

    if (snapshot.val() == null) {
      app.homePageCta = 'sign-up';
    } else {
      Map confirmationData = snapshot.val();

      UserModel user = new UserModel();
      // If the confirmation link looks like it came from an invitation.
      if (confirmationData['fromUser'] != null) {
        user.invitation = confirmationData;
        user.invitation['confirmationId'] = confirmId;
      }

      user.email = confirmationData['email'];
      app.user = user;
      app.homePageCta = 'complete-sign-up';
    }
  }

  signInWithFacebook() {
    app.signInWithFacebook();
  }

  /**
   * Create a new user.
   */
  getStarted(Event e) async {
    e.preventDefault();

    if (email.value.trim().isEmpty || !isValidEmail(email.value.trim())) {
      window.alert("Please provide a valid email.");
      return false;
    }

    toggleProcessingIndicator();

    // Kill any existing session since the user appears to be signing up again.
    app.signOut();

    // Check credentials and sign the user in server side.
    HttpRequest request = await HttpRequest
        .request(app.serverPath + Routes.sendConfirmEmail.toString(),
            method: 'POST',
            sendData: JSON.encode({'email': email.value.trim()}))
        .catchError((e) => print(e));

    // Set up the response as an object.
    Response response = Response.fromJson(JSON.decode(request.responseText));

    if (response.success) {
      toggleProcessingIndicator();
      showGetStartedNote();
    } else {
      toggleProcessingIndicator();
      window.alert(response.message);
    }
  }

  /**
   * Create a new user.
   */
  signUp(Event e) async {
    e.preventDefault();

    if (email.value.trim().isEmpty || !isValidEmail(email.value.trim())) {
      window.alert("Please provide a valid email.");
      return false;
    }

    if (username.value.trim().isEmpty) {
      window.alert("Please choose a username.");
      return false;
    }

    //TODO: Regex this for all disallowed cases.
    if (!new RegExp(RegexHelper.username).hasMatch(username.value.trim())) {
      window.alert(
          "Your username may only contain letters and numbers, and must have at least one letter.");
      return false;
    }

    if (password.value.trim().isEmpty || password.value.trim().length < 6) {
      window.alert("Please choose a password at least 6 characters long.");
      return false;
    }

    toggleProcessingIndicator();

    // Check credentials and sign the user in server side.
    HttpRequest request = await HttpRequest.request(
        app.serverPath + Routes.createNewUser.toString(),
        method: 'POST',
        sendData: JSON.encode({
          'username': username.value.trim(),
          'password': password.value,
          'firstName': firstname.value.trim(),
          'lastName': lastname.value.trim(),
          'email': email.value.trim(),
          'onboardingState': app.user.onboardingState,
          'invitation': app.user.invitation,
          'facebookId':
              (app.user.facebookId != null) ? app.user.facebookId : null,
          'invitationCode':
              (invitationCode != null && invitationCode.value.isNotEmpty)
                  ? invitationCode.value.toLowerCase().trim()
                  : null
        }));

    // Set up the response as an object.
    Response response = Response.fromJson(JSON.decode(request.responseText));
    if (response.success) {
      // Set the auth token and remove it from the map.
      app.authToken = response.data['authToken'];
      // TODO: This should totally just be part of the UserModel.
      response.data.remove('authToken');

      if (response.data['disabled'] == true) {
        toggleProcessingIndicator();
        app.user = null; // Kill the disabled user.
        showSignUpNote();
      } else {
        f
            .authWithCustomToken(app.authToken)
            .catchError((error) => print(error));

        // Set up the user object.
        app.user = UserModel.fromJson(response.data);
        app.user.isNew = true;
        app.signIn();
      }
    } else {
      toggleProcessingIndicator();
      window.alert(response.message);
    }
  }

  /**
   * Updates an existing user.
   */
  updateExistingUser(Event e) async {
    e.preventDefault();

    if (email.value.trim().isEmpty || !isValidEmail(email.value.trim())) {
      window.alert("Please provide a valid email.");
      return false;
    }

    if (username.value.trim().isEmpty) {
      window.alert("Please choose a username.");
      return false;
    }

    //TODO: Regex this for all disallowed cases.
    if (username.value.trim().contains(" ")) {
      window.alert("Your username may not contain spaces.");
      return false;
    }

    if (password.value.trim().isEmpty || password.value.trim().length < 6) {
      window.alert("Please choose a password at least 6 characters long.");
      return false;
    }

    toggleProcessingIndicator();

    final userRef = f.child('/users/${username.value}');

    app.user.password = hash(password.value);
    app.user.firstName = firstname.value;
    app.user.lastName = lastname.value;
    app.user.onboardingState = OnboardingState.signUpComplete;

    Map userData = removeNullsFromMap(app.user.toJson());

    // TODO: Handle any errors with update later, and consider moving to server-side.
    await userRef.update(userData);

    f.authWithCustomToken(app.authToken).catchError((error) => print(error));

    // Set up the user object.
    if (app.user.settings == null) app.user.settings = {};

    document.body.classes.add('no-transition');
    app.user.settings = toObservable(app.user.settings);
    new Timer(new Duration(seconds: 1),
        () => document.body.classes.remove('no-transition'));

    app.cache.users[app.user.username.toLowerCase()] = app.user;

    toggleProcessingIndicator();

    // Hide the homepage and show the app.
    app.showHomePage = false;
    app.skippedHomePage = true;

    Timer.run(
        () => app.showMessage('Thanks for doing that, ${app.user.firstName}.'));
  }

  /**
   * Handle sign in.
   */
  signIn() async {
    if (username.value.trim().isEmpty || password.value.trim().isEmpty) {
      window.alert("Your username and password, please.");
      return false;
    }

    // Disable button and add activity indicator animation.
    toggleProcessingIndicator();

    // Check credentials and sign the user in server side.
    var request = await HttpRequest.request(
        app.serverPath + Routes.signIn.toString(),
        method: 'POST',
        sendData: JSON.encode({
          'username': username.value.toLowerCase(),
          'password': password.value
        }));

    // Set up the response as an object.
    Response response = Response.fromJson(JSON.decode(request.responseText));
    if (response.success) {
      // Set the auth token and remove it from the map.
      app.authToken = response.data['authToken'];
      // TODO: This should totally just be part of the UserModel.
      response.data.remove('authToken');
      app.f
          .authWithCustomToken(app.authToken)
          .catchError((error) => print(error));

      // Set up the user object.
      app.user = UserModel.fromJson(response.data);
      app.signIn();
    } else {
      toggleProcessingIndicator();
      window.alert(response.message);
      password.value = '';
    }
  }

  toggleProcessingIndicator() {
    if (processing) {
      submitButton.classes.remove('disabled');
      processingAnimation.cancel();
      processing = false;
    } else {
      submitButton.classes.add('disabled');
      processingAnimation.duration = 600;
      processingAnimation.iterations = 'Infinity';
      processingAnimation.easing = 'ease-in';
      processingAnimation.keyframes = [
        {'background-color': 'rgb(64, 136, 214)'},
        {'background-color': 'rgb(73, 168, 255)'},
        {'background-color': 'rgb(64, 136, 214)'}
      ];
      processingAnimation.target = submitButton;
      processingAnimation.play();
      processing = true;
    }
  }

  attached() {
    if (app.debugMode) print('+Home');

    if (app.isMobile) {
      this.querySelector('.page-wrapper').style.minHeight = '100vh';
    }

    document.body.classes.add('colored-bg');
    toggleMain();

    if (app.user != null && app.user.onboardingState == 'signUpIncomplete') {
      username.disabled = true;
      email.disabled = true;
      submitButton.text = 'Continue →';
    }
  }

  detached() {
    if (app.debugMode) print('-Home');
    document.body.style.backgroundImage = null;
    document.body.classes.remove('colored-bg');
  }
}
