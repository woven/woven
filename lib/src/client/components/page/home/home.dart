import 'dart:html';
import 'dart:async';
import 'dart:math';

import 'package:polymer/polymer.dart';

import 'package:woven/config/config.dart';
import 'package:woven/src/client/app.dart';


@CustomTag('x-home')
class Home extends PolymerElement with Observable {
  @published App app;
  @observable String randomWord = '';

  Home.created() : super.created();

  signInWithFacebook() {
    app.signInWithFacebook();
  }

  close() {
    app.showHomePage = false;
    app.skippedHomePage = true;
    print(app.showHomePage);
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
    animateRandomWords();
  }
}