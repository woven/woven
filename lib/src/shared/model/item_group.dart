library shared.model.item_group;

import 'package:polymer/polymer.dart';
import 'item.dart';

class ItemGroup extends Observable {
  String user;
  List<Item> items = toObservable([]);

  ItemGroup(Item item) {
    user = item.user;
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
  }

  bool hasSameUser(Item item) => item.user == user;
  bool hasDifferentUser(Item item) => !hasSameUser(item);
}