library infinite_scroll;

import 'dart:html';
import 'dart:async';

class InfiniteScroll {
  int pageSize;
  int originalPageSize;
  int limit = 10;
  int offset = 0;
  int threshold = 0;
  int lastY = 0;
  bool paused = false;
  bool reversed = false;
  bool atBottom = false;

  var scroller;
  Element element;

  StreamController _controllerScroll = new StreamController();
  Stream onScroll;

  var _scrollSubscription;

  InfiniteScroll({this.pageSize: 10, this.element, this.scroller, this.threshold: 512, this.reversed: false}) {
    limit = pageSize;
    originalPageSize = pageSize;

    onScroll = _controllerScroll.stream.asBroadcastStream();

    if (scroller == null) {
      Element scroller = window.document.querySelector('.content-area');
    }

    _scrollSubscription = scroller.onScroll.listen((Event e) => checkState());
  }

  get scrollTop {
    if (scroller is Window) return scroller.scrollY;

    return scroller.scrollTop;
  }

  set scrollTop(int value) {
    if (scroller is Window) scroller.scrollTo(scroller.scrollX, value);
    else scroller.scrollTop = value;
  }

  /**
   * Checks the current state.
   */
  checkState() {
    if (scroller == null || element == null) {
      return;
    }

    var elementBottomY, scrollerBottomY, elementTopY, scrollerTopY;
    var elementScrollBottom;


    if (scroller is Window) {
      var scrollY = scroller.scrollY;
      if (scrollY == null) {
        scrollY = scroller.document.body.scrollTop;
      }

      scrollerBottomY = scrollY + scroller.innerHeight;
      elementBottomY = element.clientHeight + element.offsetTop;

      scrollerTopY = scrollY + scroller.innerHeight;
      elementTopY = element.clientHeight + element.offsetTop;
    } else {
      scrollerBottomY = scroller.scrollTop + scroller.clientHeight;
      elementBottomY = element.clientHeight + element.offsetTop - scroller.offsetTop;

      scrollerTopY = scroller.scrollTop;
      elementTopY = element.clientHeight + element.offsetTop - scroller.offsetTop;

      elementTopY = element.clientHeight + element.offsetTop - scroller.offsetTop;
//      elementScrollBottom = element.scrollHeight - element.scrollTop;
      atBottom = scroller.scrollHeight - scroller.scrollTop <= scroller.clientHeight;

    }

//    print('''
//elementTopY: $elementTopY
//scrollerTopY: $scrollerTopY
//threshhold: $threshold
//scroller.clientHeight: ${scroller.clientHeight}
//element.clientHeight: ${element.clientHeight}
//element.offsetTop: ${element.offsetTop}
//scroller.offsetTop: ${scroller.offsetTop}
//scroller.scrollHeight: ${scroller.scrollHeight}
//atBottom: $atBottom
//    ''');

    // Make sure we scrolled past the element's bottom Y, and that we have scroller more than last time.
    if (!reversed) {
      if (scrollerBottomY >= elementBottomY - threshold && /*scrollerBottomY > lastY &&*/ !paused) {
        limit += pageSize;
        lastY = scrollerBottomY;

        _controllerScroll.add(true);
      }
    } else {
      if (scrollerTopY <= scroller.clientHeight + threshold && !paused) {
        print('''
        lastY: $lastY
        current: $scrollerTopY
        ''');

        if (scrollerTopY < lastY) {
          limit += pageSize;
          _controllerScroll.add(true);
        }
        lastY = scrollerTopY;
      }
    }
  }

  increasePageSize() => pageSize += originalPageSize;
}