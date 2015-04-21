import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async' show Timer;
import 'dart:math' show Random;
import 'package:woven/src/client/app.dart';

@CustomTag('cta-learn-more')
class LearnMoreCta extends PolymerElement {
  LearnMoreCta.created() : super.created();

  @published App app;
  @published bool opened = false;
  @observable String randomWord = "";

  /**
   * Toggle the page.
   */
  togglePage() {
  }

  void handleCallToAction(Event e) {
    e.stopPropagation();
    // Reset the current selectedItem so item-view grabs it from the URL
    app.router.selectedItem == null;
    app.router.dispatch(url: "/item/LUpZTWEtZWZOejRFRklYVTYxWmY="); //-JYMa-efNz4EFIXU61Zf
  }

  animateRandomWords() {
    List words = ['changemakers', 'community organizers', 'movers and shakers',
    'collaborators', 'the crazy ones', 'makers', 'builders', 'world changers', 'we vs. me', 'repairing the world',
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

  signIn(Event e) {
    e.stopPropagation();
    app.signInWithFacebook();
  }

  attached() {
    animateRandomWords();
  }
}