import 'dart:html';
import 'dart:async';
import 'dart:math';
import 'dart:convert';

import 'package:polymer/polymer.dart';
import 'package:core_elements/core_animation.dart';
import 'package:core_elements/core_input.dart';
import 'package:firebase/firebase.dart' as firebase;

import 'package:woven/src/client/app.dart';
import 'package:woven/src/shared/model/user.dart';
import 'package:woven/src/shared/routing/routes.dart';
import 'package:woven/src/shared/response.dart';
import 'package:woven/src/shared/shared_util.dart';

@CustomTag('x-home')
class Home extends PolymerElement with Observable {
  @published App app;
  @observable String randomWord = '';
  @observable Map formData = toObservable({});

  var overlayAnimation = new CoreAnimation();
  var logoAnimation = new CoreAnimation();
  var menuAnimation = new CoreAnimation();
  var mainAnimation = new CoreAnimation();
  var ctaAnimation = new CoreAnimation();

  var processing = false;
  var processingAnimation = new CoreAnimation();

  firebase.Firebase get f => app.f;

  DateTime get now => new DateTime.now().toUtc();

  Element get overlay => this.shadowRoot.querySelector('div.overlay');
  Element get logo => this.shadowRoot.querySelector((app.isMobile ? 'div.logo-solo' : 'div.logo'));
  Element get menu => this.shadowRoot.querySelector('ul.menu');
  Element get cover => this.shadowRoot.querySelector('div.cover');
  Element get cta => this.shadowRoot.querySelector('div.cta');

  CoreInput get username => this.shadowRoot.querySelector('#username');
  CoreInput get password => this.shadowRoot.querySelector('#password');
  CoreInput get firstname => this.shadowRoot.querySelector('#firstname');
  CoreInput get lastname => this.shadowRoot.querySelector('#lastname');
  CoreInput get email => this.shadowRoot.querySelector('#email');
  Element get submitButton => this.shadowRoot.querySelector('#submit');

  Home.created() : super.created();

  toggleOverlay() {
    overlayAnimation.target = overlay;
    overlayAnimation.duration = 200;
    overlayAnimation.iterations = 'auto';
    overlayAnimation.easing = 'ease-out';
    overlayAnimation.composite = 'add';
    overlayAnimation.fill = 'both';
    overlayAnimation.keyframes = [
        {'height': '70px'},
        {'height': '100%'}
    ];
    overlayAnimation.play();
    toggleLogo();
    toggleMenu();

    if (overlayAnimation.direction == 'reverse') {
      overlayAnimation.direction = 'forward';
    } else {
      overlayAnimation.direction = 'reverse';
    }
  }

  changeCta(String page) {
    toggleCta();
    new Timer(new Duration(milliseconds: 100), () {
      app.homePageCta = page;
      toggleCta();
    });
  }

  showSignIn() => changeCta('sign-in');

  showSignUp() => changeCta('sign-up');

  showSignUpNote() => changeCta('sign-up-note');

  showGetStartedNote() => changeCta('get-started-note');

  toggleCta() {
    mainAnimation.target = cta;
    mainAnimation.duration = 400;
    mainAnimation.iterations = 'auto';
    mainAnimation.easing = 'ease-out';
    mainAnimation.composite = 'add';
    mainAnimation.fill = 'both';
    mainAnimation.keyframes = [
        {'opacity': '1', 'top': (app.isMobile ? '0px' : '60px')},
        {'opacity': '0', 'top': '300px'}
    ];
    mainAnimation.play();

    if (mainAnimation.direction == 'reverse') {
      mainAnimation.direction = 'forward';
    } else {
      mainAnimation.direction = 'reverse';
    }
  }

  toggleCover() {
    mainAnimation.target = cover;
    mainAnimation.duration = 300;
    mainAnimation.iterations = 'auto';
    mainAnimation.easing = 'ease-out';
    mainAnimation.composite = 'add';
    mainAnimation.fill = 'both';
    mainAnimation.keyframes = [
        {'opacity': '0'},
        {'opacity': '1'}
    ];
    mainAnimation.play();

    if (mainAnimation.direction == 'reverse') {
      mainAnimation.direction = 'forward';
    } else {
      mainAnimation.direction = 'reverse';
    }
  }

  toggleMain() {
    new Timer(new Duration(milliseconds: 300), () {
      toggleLogo();
      new Timer(new Duration(milliseconds: 600), () async {
        if (app.user != null) {
          if (app.user.disabled && app.user.onboardingStatus == 'signUpComplete') {
            app.homePageCta = 'sign-up-note';
          }
          if (app.user.onboardingStatus == 'temporaryUser') {
            app.homePageCta = 'complete-sign-up';
          }
        } else {
          Uri currentPath = Uri.parse(window.location.toString());

          if (currentPath.pathSegments.contains('confirm') && currentPath.pathSegments[1] != null) {
            var confirmId = currentPath.pathSegments[1].toString();
            handleConfirm(confirmId);
            app.router.dispatch(url: '/');
          } else {
            app.homePageCta = 'sign-up';
          }
        }
        toggleCta();
      });
    });
  }

  /**
   * Handle the case where user is coming by way of an email confirmation/invite link.
   */
  handleConfirm(String confirmId) async {
    firebase.DataSnapshot snapshot = await f.child('/email_confirmation_index/$confirmId').once('value');
    if (snapshot.val() == null) {
      app.homePageCta = 'sign-up';
    } else {
      Map confirmationData = snapshot.val();

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

  toggleLogo() {
    logoAnimation.target = logo;
    logoAnimation.duration = 600;
    logoAnimation.iterations = 'auto';
    logoAnimation.easing = 'ease-out';
    logoAnimation.composite = 'add';
    logoAnimation.fill = 'both';
    logoAnimation.keyframes = [
        {'opacity': '0'},
        {'opacity': '1'}
    ];

    logoAnimation.play();

    if (logoAnimation.direction == 'reverse') {
      logoAnimation.direction = 'forward';
    } else {
      logoAnimation.direction = 'reverse';
    }
  }

  toggleMenu() {
    menuAnimation.target = menu;
    menuAnimation.duration = 300;
    menuAnimation.iterations = 'auto';
    menuAnimation.easing = 'ease-out';
    menuAnimation.composite = 'add';
    menuAnimation.fill = 'both';
    menuAnimation.keyframes = [
        {'font-size': '24px', 'margin-left': '0px'},
        {'font-size': '32px', 'margin-left': '80px'}
    ];

    menuAnimation.play();

    if (menuAnimation.direction == 'reverse') {
      menuAnimation.direction = 'forward';
    } else {
      menuAnimation.direction = 'reverse';
    }
  }

  signInWithFacebook() {
    app.signInWithFacebook();
  }

  close() {
    toggleCta();
    new Timer(new Duration(milliseconds: 400), () {
      toggleLogo();
      new Timer(new Duration(milliseconds: 400), () {
        toggleCover();
        new Timer(new Duration(milliseconds: 400), () {
          if (app.user != null && app.user.disabled == true) {
            app.user = null; // Kill the disabled user before entering app.
          }

          app.showHomePage = false;
          app.skippedHomePage = true;
        });
      });
    });
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

    // Check credentials and sign the user in server side.
    HttpRequest request = await HttpRequest.request(
        Routes.sendConfirmEmail.toString(),
        method: 'POST',
        sendData: JSON.encode({
          'email': email.value.trim()
        }));

    toggleProcessingIndicator();

    showGetStartedNote();
  }

  /**
   * Create a new user.
   */
  signUp(Event e) {
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

    // Check credentials and sign the user in server side.
    HttpRequest.request(
        Routes.createNewUser.toString(),
        method: 'POST',
        sendData: JSON.encode({
            'username': username.value.trim(),
            'password': password.value,
            'firstName': firstname.value,
            'lastName': lastname.value,
            'email': email.value.trim(),
            'onboardingStatus': app.user.onboardingStatus,
            'invitation': app.user.invitation,
            'facebookId': (app.user.facebookId != null) ? app.user.facebookId : null
        }))
    .then((HttpRequest request) {
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
          return;
        }

        f.authWithCustomToken(app.authToken).catchError((error) => print(error));

        // Set up the user object.
        app.user = UserModel.fromJson(response.data);
        if (app.user.settings == null) app.user.settings = {};

        document.body.classes.add('no-transition');
        app.user.settings = toObservable(app.user.settings);
        new Timer(new Duration(seconds: 1), () => document.body.classes.remove('no-transition'));

        app.cache.users[app.user.username.toLowerCase()] = app.user;

        // Trigger changes to app state in response to user sign in/out.
        //TODO: Aha! This triggers a feedViewModel load.
        app.mainViewModel.invalidateUserState();

        // Hide the homepage and show the app.
        app.showHomePage = false;
        app.skippedHomePage = true;

        // When the user completes the welcome dialog, send them a welcome email.
//    HttpRequest.request(Routes.sendWelcome.toString());

        Timer.run(() => app.showMessage('Welcome to Woven, ${app.user.username}!'));
      } else {
        toggleProcessingIndicator();
        window.alert(response.message);
      }
    });
  }

  /**
   * Handle sign in.
   */
  signIn() {
    if (username.value.trim().isEmpty || password.value.trim().isEmpty) {
      window.alert("Your username and password, please.");
      return false;
    }

    // Disable button and add activity indicator animation.
    toggleProcessingIndicator();

    // Check credentials and sign the user in server side.
    HttpRequest.request(
        Routes.signIn.toString(),
        method: 'POST',
        sendData: JSON.encode({'username': username.value.toLowerCase(), 'password': password.value}))
    .then((HttpRequest request) {
      // Set up the response as an object.
      Response response = Response.fromJson(JSON.decode(request.responseText));
      if (response.success) {
        // Set the auth token and remove it from the map.
        app.authToken = response.data['authToken'];
        // TODO: This should totally just be part of the UserModel.
        response.data.remove('authToken');
        app.f.authWithCustomToken(app.authToken).catchError((error) => print(error));

        // Set up the user object.
        app.user = UserModel.fromJson(response.data);
        if (app.user.settings == null) app.user.settings = {};

        document.body.classes.add('no-transition');
        app.user.settings = toObservable(app.user.settings);
        new Timer(new Duration(seconds: 1), () => document.body.classes.remove('no-transition'));

        app.cache.users[app.user.username.toLowerCase()] = app.user;

        // Mark as new so the welcome pops up.
        app.user.isNew = true;

        // Trigger changes to app state in response to user sign in/out.
        //TODO: Aha! This triggers a feedViewModel load.
        app.mainViewModel.invalidateUserState();

        // Hide the homepage and show the app.
        app.showHomePage = false;
        app.skippedHomePage = true;

        Timer.run(() => greetUser());
      } else {
        toggleProcessingIndicator();
        window.alert(response.message);
      }
    });
  }

  // Greet the user upon sign in.
  greetUser() {
    var greeting;
    DateTime now = new DateTime.now();

    if (now.hour < 12) {
      greeting = "Good morning";
    } else {
      if (now.hour >= 12 && now.hour <= 17) {
        greeting = "Good afternoon";
      } else if (now.hour > 17 && now.hour <= 24) {
        greeting = "Good evening";
      } else {
        greeting = "Hello";
      }
    }

    app.showMessage("$greeting, ${app.user.firstName}.");
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
          {
              'background-color': 'rgb(64, 136, 214)'
          },
          {
              'background-color': 'rgb(73, 168, 255)'
          },
          {
              'background-color': 'rgb(64, 136, 214)'
          }
      ];
      processingAnimation.target = submitButton;
      processingAnimation.play();
      processing = true;
    }
  }

  animateRandomWords() {
    List words = ['changemakers', 'community organizers', 'movers and shakers',
    'collaborators', 'the crazy ones', 'makers', 'world changers', 'we vs. me', 'repairing the world',
    'collective action', 'collaborative networking'];
    words.shuffle(new Random());

    randomWord = words[0]; // Initial random word.
    var i = 1; // Because we already used the first word, start iterating at the second.

    Timer timer = new Timer.periodic(new Duration(seconds: 4), (f) {
      HtmlElement el;
      el = $['random-word'];
      el.style.opacity = '0';

      new Timer(new Duration(milliseconds: 750), () {
        el.style.opacity = '1';
        if (i == words.length) {
          i = 0;
        }
        randomWord = words[i];
        i++;
      });
    });
  }

  attached() {
    if (app.debugMode) print('+Home');
    ImageElement coverImage = new ImageElement(src: 'http://storage.googleapis.com/woven/public/images/bg/wynwood_26st.jpg');
    document.body.classes.add('colored-bg');
    Timer.run(() => toggleCover());
    toggleMain();
    coverImage.onLoad.listen((e) {
      cover.style.backgroundImage = 'url(http://storage.googleapis.com/woven/public/images/bg/wynwood_26st.jpg)';
    });
  }

  detached() {
    if (app.debugMode) print('-Home');
    document.body.classes.remove('colored-bg');
  }
}