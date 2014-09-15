dart-communities
==========

This demonstrates a fairly fleshed out client and server Dart application. It's a tool that lets people share across various communities.

It's free and open source. We hope it helps others as they navigate the world of Dart and Polymer, and we hope it helps us as others scrutinize our approach and help us improve.

This is serving as the base for our latest work with [Woven](http://woven.co). A live version can be found at [http://mycommunity.org](http://mycommunity.org) for now. Please sign up!

### Components

- Polymer (encapsulated and interoperable custom elements)
- Polymer core-elements (a great core set of custom elements)
- Polymer paper-elements (some elements based on Material Design from Google)
- Firebase (store and sync data in realtime)

The app demonstrates an approach to client/server routing and communication, Facebook sign in and more.

### Caveats
 
- Please note that at some point we'll likely fork continued work on our product to a private repo.
- Please excuse the mess. I'm playing and learning, and I welcome your input and contributions.

### Setup

- If you don't have it yet, get the [Dart SDK](https://www.dartlang.org/tools/download.html). This is currently tested with 1.6.
 - It's a good idea to add the Dart tools [to your $PATH](https://www.dartlang.org/tools/pub/installing.html).
- Clone this repo, then run `pub get` in the main directory to get all the dependencies.
- Create your own `config.dart` in `lib/config` by copying the example found there.
 - You may wish to set your own hostname there, and map that hostname to 127.0.0.1 in your hosts file.
- Get your own [Firebase](https://www.firebase.com/) URL – sign up, create a Firebase app and replace my URL with yours.
 - Actually, for now you have to manually create the communities in the database. So it doesn't hurt to use my development Firebase URL in the meantime.
- Start the server with `sudo dart start.dart` and then visit the URL that's set in your configuration in Dartium.
 - You can also `pub build` (dart2js) the app to run it elsewhere. Set the directory in your configuration to `build/web` first.

### Get in touch

Don't hesitate to reach out: dave@woven.co or via the app itself: http://mycommunity.org/woven

### Known issues

http://mycommunity.org/item/LUpVR2ktVnlsWU9TQmRDbnZxbGs=

### Updates

http://mycommunity.org/item/LUpWTzJSdWdqOEpNeUp1NXpCWGQ=