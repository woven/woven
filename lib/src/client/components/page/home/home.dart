import 'dart:html';
import 'dart:async';
import 'dart:math';

import 'package:polymer/polymer.dart';
import 'package:core_elements/core_animation.dart';

import 'package:woven/config/config.dart';
import 'package:woven/src/client/app.dart';


@CustomTag('x-home')
class Home extends PolymerElement with Observable {
  @published App app;
  @observable String randomWord = '';

  var overlayAnimation = new CoreAnimation();
  var logoAnimation = new CoreAnimation();
  var menuAnimation = new CoreAnimation();

  Element get overlay => this.shadowRoot.querySelector('div.overlay');
  Element get logo => this.shadowRoot.querySelector('div.logo');
  Element get menu => this.shadowRoot.querySelector('ul.menu');

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

  toggleLogo() {
    logoAnimation.target = logo;
    logoAnimation.duration = 200;
    logoAnimation.iterations = 'auto';
    logoAnimation.easing = 'ease-out';
    logoAnimation.composite = 'add';
    logoAnimation.fill = 'both';
    logoAnimation.keyframes = [
        {'opacity': '1'},
        {'opacity': '0'}
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
    menuAnimation.duration = 200;
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
    app.showHomePage = false;
    app.skippedHomePage = true;
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
  }
}