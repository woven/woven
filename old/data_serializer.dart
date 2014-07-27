library data_serializer;

import 'dart:async';
import 'dart:math';
//import 'dart:mirrors';

//import 'database/database.dart';
import 'database/database_model.dart';
import 'package:web_ui/observe.dart';

/**
 * A generic serializer for our application's data.
 *
 * This (de)serializes and Persistent Objects, DateTimes, and all sort of other objects we have used.
 */
class DataSerializer {
  Map deserializeCache = {};

  bool deep = true;
  bool mergeReferences = false;
  bool useDateTimeObjects = false;
//  Database database;

  DataSerializer({this.deep, this.mergeReferences: false, this.useDateTimeObjects: false, this.database});

  /**
   * Serializes the given data to a JSON-able format.
   */
  serialize(data, {parent, key, skipObjectIds, debug: false}) {
    if (skipObjectIds == null) skipObjectIds = [];

    if (data is DateTime) {
      return {
          'v': useDateTimeObjects ? data.toString() : data.millisecondsSinceEpoch,
          '\$C': 'DateTime'
      };
    }

    // TODO: Horrible hack! For some reason 'is' check fails below.
    var i;
    try {
      i = database.newInstance(data.runtimeType);
    } catch (e) {}

    if (data is DatabaseModel || i != null) {
      var type = data.dbType;
      var original = data;
      data = new Map.from(original.map);
      Map dataCopy = new Map.from(original.map);
      data['\$C'] = type;

      skipObjectIds.add(original.id);

      void serializeEntry(key, value) {
        if (original.whitelistFields == false) {
          if (original.excludeFields.contains(key)) {
            data.remove(key);
            return;
          }
        } else {
          if (original.includeFields.contains(key) == false && key != 'id') {
            data.remove(key);
            return;
          }
        }

        data[key] = serialize(value, parent: original, key: key, skipObjectIds: skipObjectIds, debug: debug);
      }

      dataCopy.forEach(serializeEntry);

    }

    if (data is Iterable) {
      var newList = [];

      data.toList().forEach((entry) {
        var serialized = serialize(entry, skipObjectIds: skipObjectIds, debug: debug);

        if (entry == null || serialized != null) newList.add(serialized);
      });

      return newList;
    }

    if (data is Map) {
      var newMap = {};

      data.forEach((key, value) {
        newMap[key] = serialize(value, key: key, skipObjectIds: skipObjectIds, debug: debug);
      });

      return newMap;
    }

    return data;
  }

  /**
   * De-serializes data.
   */
  deserialize(data) {
    if (data is Map) {
      data.forEach((key, value) {
        data[key] = deserialize(value);
      });

      var className = data['\$C'];
      if (className != null) {
        if (className == 'DateTime') {
          // I don't get it... parse() doesn't work as I expected. Should we have parseUtc() too?
          if (data['v'] is int) {
            data = new DateTime.fromMillisecondsSinceEpoch(data['v']);
          } else {
            data = DateTime.parse(data['v']);
          }
        } else if (className == 'ObjectId') {
          return data['v'];
        } else {
          var instance = database.newInstance(data['\$C']);
          data.remove('\$C');
          instance.map = deserialize(data);
          data = instance;

          if (mergeReferences) {
            var existing = database.findFromCache(instance.dbType, instance.id);
            if (existing == null) {
              database.addToCache(instance);
            } else {
              // Merge.
              instance.map.forEach((key, value) {
                existing.map[key] = value;
              });

              data = existing;
            }
          }
        }
      }
    } else if (data is List) {
      var newList = [];

      data.forEach((value) {
        newList.add(deserialize(value));
      });

      data = newList;
    }

    return data;
  }
}