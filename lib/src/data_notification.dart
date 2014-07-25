library data_notification;

import 'dart:async';
import 'dart:math';

import 'package:polymer/polymer.dart';
import 'data_serializer.dart';

/**
 * Enum class.
 */
class DataNotificationType {
  static const UPDATE = const DataNotificationType._(0);
  static const CREATE = const DataNotificationType._(1);
  static const DELETE = const DataNotificationType._(2);
  static const INFO = const DataNotificationType._(3);

  static get values => [UPDATE, CREATE, DELETE, INFO];

  final int value;

  const DataNotificationType._(this.value);

  static String toText(int value) {
    switch (value) {
      case 0:
        return 'UPDATE';
      case 1:
        return 'CREATE';
      case 2:
        return 'DELETE';
      case 3:
        return 'INFO';
    }
  }
}

class DataNotificationStatus {
  static const OK = const DataNotificationStatus._(0);
  static const ERROR = const DataNotificationStatus._(1);
  static const WARNING = const DataNotificationStatus._(2);
  static const INFO = const DataNotificationStatus._(3);

  static get values => [OK, ERROR, WARNING, INFO];

  final int value;

  const DataNotificationStatus._(this.value);
}

/**
 * This class represents a data notification.
 */
class DataNotification {
  DataNotificationType type;
  DataNotificationStatus status;
  String model;

  /**
   * List of groups that are affected.
   */
  List<String> groupIds = [];

  /**
   * All id's that were affected.
   */
  List<String> ids = [];

  /**
   * The user who caused this action, will be null if it was automatic like the job scheduler.
   */
  var userId;

  List<String> communityIds = [];

  int count = 1;
  bool adminOnly = false;

  /**
   * A custom message.
   */
  String message;

  var data;

  DataNotification();

  /**
   * Creates a new data notification instance from the given map.
   */
  factory DataNotification.fromMap(Map map) {
    var notification = new DataNotification()
      ..model = map['model']
      ..count = map['count']
      ..adminOnly = map['adminOnly']
      ..data = new DataSerializer().deserialize(map['data'])
      ..message = map['message'];

    switch (map['type']) {
      case 0:
        notification.type = DataNotificationType.UPDATE;
        break;
      case 1:
        notification.type = DataNotificationType.CREATE;
        break;
      case 2:
        notification.type = DataNotificationType.DELETE;
        break;
      case 3:
        notification.type = DataNotificationType.INFO;
        break;
    }

    switch (map['status']) {
      case 0:
        notification.status = DataNotificationStatus.OK;
        break;
      case 1:
        notification.status = DataNotificationStatus.ERROR;
        break;
      case 2:
        notification.status = DataNotificationStatus.WARNING;
        break;
      case 3:
        notification.status = DataNotificationStatus.INFO;
        break;
    }

    if (map['ids'] != null) notification.ids = map['ids'].map((id) => id).toList();
    if (map['groupIds'] != null) notification.groupIds = map['groupIds'].map((id) => id).toList();
    if (map['userId'] != null) notification.userId = map['userId'];
    if (map['communityIds'] != null) notification.communityIds = map['communityIds'].map((id) => id).toList();

    return notification;
  }

  Map toJson() {
    var ids = this.ids.map((id) => id is String ? id : id).toList();
    var groupIdList = this.groupIds.map((id) => id is String ? id : id).toList();
    var communityIdList = this.communityIds.map((id) => id is String ? id : id).toList();

    return {
        'model': model,
        'type': type.value,
        'status': status != null ? status.value : DataNotificationStatus.OK.value,
        'ids': ids,
        'count': count,
        'adminOnly': adminOnly,
        'groupIds': groupIdList,
        'communityIds': communityIdList,
        'userId': userId != null ? (userId is! String ? userId : userId) : null,
        'message': message,
        'data': new DataSerializer().serialize(data)
    };
  }

  String toString() {
    var string = 'DataNotification($count x $model, ${DataNotificationType.toText(type.value)}, ids: $ids)';

    return string;
  }
}