library shared.model.item_group;

import 'package:observe/observe.dart';

import 'package:woven/src/shared/input_formatter.dart';
import 'item.dart';
import 'target_group_enum.dart';

class ItemGroup extends Observable {
  String user;
  String type;
  List<Item> items = toObservable([]);
  @observable DateTime latestDate;

  ItemGroup(Item item) {
    user = item.user;
    type = item.type;
    items.add(item);
  }

  ItemGroup.fromItems(List<Item> list) {
    user = list.first.user;
    items.addAll(list);
  }

  DateTime getOldestDate() => items.first.createdDate;
  DateTime getLatestDate() => items.last.createdDate;

  /**
   * Returns true when the given [DateTime] is in between
   * the oldest and the latest item in this group.
   */
  bool isDateWithin(DateTime date) => date.isAfter(getOldestDate()) && date.isBefore(getLatestDate());

  /**
   * Returns the index of where the given item should go to in this group.
   */
  int indexOf(Item item) {
    for (var i = 0; i < items.length; i++) {
      if (item.createdDate.isBefore(items[i].createdDate)) {
        return i;
      }
    }
    return items.length;
  }

  /**
   * Puts the given item into this group at the right position.
   */
  void put(Item item) {
    items.insert(indexOf(item), toObservable(item));
    latestDate = getLatestDate();
  }

  Map toJson() {
    return {
      'user': user,
      'type': type,
      'items': items
    };
  }

  /**
   * Returns true if a) the user doesn't match the group's, b) this is a notification
   * or c) this group is already holding a notification (we want one per group for styling purposes).
   */
  bool needsNewGroup(Item item) {
    var i = indexOf(item);
    if (item.user != user || item.type == 'notification' || this.isNotification || this.isItem) return true;

    if (i > 0) {
      Item previousItem = items[i - 1];
      DateTime previousDate = previousItem.createdDate;

      if (item.createdDate.isAfter(previousDate.add(new Duration(seconds: 180)))) return true;

      if (i < items.length) {
        Item nextItem = items[i + 1];
        DateTime nextDate = nextItem.createdDate;

        if (item.createdDate.isBefore(nextDate.subtract(new Duration(seconds: 180)))) return true;
      }
    }
  }

  /**
   * Returns TargetGroup, which specifies where the item belongs to.
   */
  TargetGroup determineTargetGroup(Item item) {
    var index = indexOf(item);
    var lastIndex = items.length - 1;

    bool farFromAboveItem = index > 0 && items[index - 1].createdDate.difference(item.createdDate).inSeconds.abs() > 20;
    bool farFromBelowItem = index < lastIndex && items[index + 1].createdDate.difference(item.createdDate).inSeconds.abs() > 20;

    if (item.user != user || item.type == 'notification' || this.isNotification || this.isItem) {
      return TargetGroup.New;
    }

    if (!farFromAboveItem && !farFromBelowItem) {
      return TargetGroup.Same;
    }

    if (!farFromAboveItem && farFromBelowItem) {
      return TargetGroup.Above;
    }

    if (farFromAboveItem && !farFromBelowItem) {
      return TargetGroup.Below;
    }

    return TargetGroup.New;
  }

  bool get isNotification => items.first.type == 'notification';

  bool get isItem => items.first.type == 'item';

  String get usernameForDisplay => items.first.usernameForDisplay;

  String get fullCreatedDate => InputFormatter.formatDate(items.last.createdDate.toLocal());

  // TODO: This duplicates getLatestDate() due to observe issues. Fix later.
  DateTime get lastCreatedDate => items.last.createdDate;
}