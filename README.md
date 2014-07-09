dart-stack
==========

A simple Dart stack I'm experimenting with. No server code whatsoever.

### Components

- Polymer.dart <–– custom elements, aka Web Components
- Polymer core-elements <–– some rad elements
- AngularDart <–– framework with routes, MVC and more
- angular_node_bind <–– Polymer<–>Angular bi-directional data binding
- firebase.dart <-- simple db in the cloud (replace with your own URI)

### Requirements


- [Dart SDK](https://www.dartlang.org/tools/download.html) – currently tested on 1.5.3
 - It's a good idea to add the Dart tools [to your $PATH](https://www.dartlang.org/tools/pub/installing.html)
- [Firebase](https://www.firebase.com/) Data URL – sign up, create a Firebase app, replace my data URL with yours 
- Clone this repo, then run `pub get` in the main directory to get all the dependencies
- Use Dart Editor to open `index.html` in Chromium, or (if you have Python) serve it up using e.g. `python -m SimpleHTTPServer`

### Known issues

- dart2js has an issue with core-scaffold; remove that element before `pub build` or `pub serve` (both of which use dart2js)

### Updates

Latest notable updates at top.

- Showing 
- Handles on-click events in Polymer elements 