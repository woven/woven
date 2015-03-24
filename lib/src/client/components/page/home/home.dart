import 'dart:html';
import 'dart:async';
import 'dart:math';
import 'dart:convert';

import 'package:polymer/polymer.dart';
import 'package:core_elements/core_animation.dart';
import 'package:core_elements/core_overlay.dart';
import 'package:core_elements/core_input.dart';

import 'package:woven/config/config.dart';
import 'package:woven/src/client/app.dart';
import 'package:woven/src/shared/model/user.dart';
import 'package:woven/src/shared/routing/routes.dart';
import 'package:woven/src/shared/response.dart';

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

  Element get overlay => this.shadowRoot.querySelector('div.overlay');
  Element get logo => this.shadowRoot.querySelector('div.logo');
  Element get menu => this.shadowRoot.querySelector('ul.menu');
  Element get main => this.shadowRoot.querySelector('div.cover');
  Element get cta => this.shadowRoot.querySelector('div.cta');

  CoreInput get username => $['username'];
  CoreInput get password => $['password'];
  CoreInput get email => $['email'];
  Element get submitButton => $['submit'];

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

  toggleCover() {
    mainAnimation.target = main;
    mainAnimation.duration = 400;
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
    new Timer(new Duration(milliseconds: 500), () {
      toggleLogo();
      new Timer(new Duration(milliseconds: 800), () {
        toggleCta();
      });
//      toggleMenu();
    });
  }

  toggleCta() {
    ctaAnimation.target = cta;
    ctaAnimation.duration = 500;
    ctaAnimation.iterations = 'auto';
    ctaAnimation.easing = 'ease-out';
    ctaAnimation.composite = 'add';
    ctaAnimation.fill = 'both';
    ctaAnimation.keyframes = [
        {'opacity': '0', 'top': '300px'},
        {'opacity': '1', 'top': '60px'}
    ];
    ctaAnimation.play();

    if (ctaAnimation.direction == 'reverse') {
      ctaAnimation.direction = 'forward';
    } else {
      ctaAnimation.direction = 'reverse';
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
          app.showHomePage = false;
          app.skippedHomePage = true;
        });
      });
    });

  }

  /**
   * Submit the form and choose what to do.
   */
  submit(Event e) {
    e.preventDefault();

    if (email.value.trim().isEmpty) {
      window.alert("Please provide your email.");
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

//    if (firstname.value.trim().isEmpty || lastname.value.trim().isEmpty) {
//      window.alert("Please give us your full name so we can be cordial.");
//      return false;
//    }

    createNewUser();
  }

  /**
   * Create a new user.
   */
  createNewUser() {
    toggleProcessingIndicator();

    // Check credentials and sign the user in server side.
    HttpRequest.request(
        Routes.createNewUser.toString(),
        method: 'POST',
        sendData: JSON.encode({
            'username': username.value,
            'password': password.value,
//            'firstName': firstname.value,
//            'lastName': lastname.value,
            'email': email.value
        }))
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

        app.cache.users[app.user.username] = app.user;

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
    ImageElement coverImage = new ImageElement(src: 'http://storage.googleapis.com/woven/public/images/bg/wynwood_26st.jpg');
    coverImage.onLoad.listen((e) {
      main.style.backgroundImage = 'url(http://storage.googleapis.com/woven/public/images/bg/wynwood_26st.jpg)';
      Timer.run(() => toggleCover());
      toggleMain();
    });
  }
}