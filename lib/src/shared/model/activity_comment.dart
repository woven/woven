library activity_comment_model;

import 'package:polymer/polymer.dart';

class ActivityCommentModel extends Observable {
  @observable String user;
  @observable String comment;
  @observable String createdDate;

  // Constructor.
  ActivityCommentModel([
    this.user = "",
    this.comment = "Hooray!",
    this.createdDate = ""
  ]);

  Map encode() {
    return {
        "user": user,
        "comment": comment,
        "createdDate": createdDate,
    };
  }

  static ActivityCommentModel decode(Map data) {
    return new ActivityCommentModel()
      ..user = data['user']
      ..comment = data['comment']
      ..createdDate = data['createdDate'];
  }
}
