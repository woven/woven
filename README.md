Woven
==========

This is the code for the Woven application that lives at http://woven.co.

Woven lets you talk and share across various channels.

It is a fairly fleshed out client and server Dart application. I'm currently developing out in the open. I hope this helps you as you navigate the world of Dart and Polymer, and I hope your input helps me improve.

### Components

- Polymer (encapsulated and interoperable custom elements)
- Polymer core-elements (a great core set of custom elements)
- Firebase (store and sync data in realtime)

### Caveats
 
- Please note that at some point I'll likely fork continued work on Woven to a private repo.
- Please excuse the mess. I'm playing and learning.

### Setup

- If you don't have it yet, get the [Dart SDK](https://www.dartlang.org/tools/download.html).
 - It's a good idea to add the Dart tools [to your $PATH](https://www.dartlang.org/tools/pub/installing.html).
- Clone this repo, then run `pub get` in the main directory to get all the dependencies.
- Create your own `config.dart` in `lib/config` by copying the example found there.
 - You may wish to set your own hostname there, and map that hostname to 127.0.0.1 in your hosts file.
- Get your own [Firebase](https://www.firebase.com/) URL – sign up, create a Firebase app and replace my URL with yours.
 - Actually, for now you have to manually create the communities in the database. Hrm. Contact me, and I'll help.
- Start the server with `sudo dart bin/start.dart` and then visit the URL that's set in your configuration in Dartium.
 - You can also `pub build` (dart2js) the app to run it in any modern browser. Set the directory in your configuration to `build/web` first.

### Get in touch

Don't hesitate to reach out: dave@woven.co or via the app itself: http://woven.co/woven

### Issues & Roadmap

Issues are in a separate repo:

http://github.com/woven/tracker

### Credits

Author: [David Notik](http://github.com/davenotik)

Contributors: [Kai Sellgren](http://github.com/kaisellgren)

Thank you to the Dart team and community.
