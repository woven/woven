library shared.model.item_group;

import 'package:observe/observe.dart';
import 'item.dart';

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
  bool needsNewGroup(Item item) => item.user != user || item.type == 'notification' || this.isNotification;

  bool get isNotification => items.first.type == 'notification';

  String get usernameForDisplay => items.first.usernameForDisplay;

  // TODO: This duplicates getLatestDate() due to observe issues. Fix later.
  DateTime get lastCreatedDate => items.last.createdDate;
}