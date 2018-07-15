# network_resource

Automatically cache network resources and use them when offline.

`NetworkResource` fetches data over HTTP, caches it in a file, and holds it in memory.
The main method, `get()`, will return the value in memory, cache,
or fetch from the network -- in that order. If the cache file is older than `maxAge`,
the cache will be updated from the network if available. To manually refresh, use `get(forceReload: true)`
or `getFromNetwork()`. The latter can be used to avoid cache fallback.

## Examples

There are three concrete classes included.

* `StringNetworkResource`
* `StringListNetworkResource`
* `BinaryNetworkResource`

```dart
// String data.
final eventsResource = StringNetworkResource(
  url: 'https://example.com/events.json',
  filename: 'events.json',
  maxAge: Duration(minutes: 60),
);

// Binary data.
final photo = BinaryNetworkResource(
  url: 'https://example.com/photo.png',
  filename: 'photo.png',
  maxAge: Duration(hours: 24),
);

// A string list, line by line.
 final words = StringListNetworkResource(
  url: 'https://example.com/wordlist.txt',
  filename: 'wordlist.txt',
  maxAge: Duration(hours: 24),
);

// Parsing a JSON string into a `List<Event>`.
json.decode(data).forEach((item) => events.add(Event(item)));
```

### Extend
Instead of declaring the resource and parsing its data separately, extend the
base class and implement `parseContents(contents)` where either a `String` or `List<int>` will be passed, depending on the value of `isBinary`.

```dart
// This example subclasses `NetworkResource` to manage fetching and parsing
// an event list in JSON format. Items are shown in a list with pull-to-refresh.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:network_resource/network_resource.dart';

class Event {
  final String title;
  Event(this.title);
}

class EventListResource extends NetworkResource<List<Event>> {
  EventListResource()
      : super(
            url: 'http://example.com/events.json',
            filename: 'events.json',
            maxAge: Duration(minutes: 60),
            isBinary: false);
  @override
  List<Event> parseContents(contents) {
    List events;
    json.decode(contents).forEach((item) => events.add(Event(item)));
    return events;
  }
}

final eventsResource = EventListResource();

// The Widget's state, with pull to refresh.
class _EventListState extends State<EventList> {
  Future<Null> refresh() async {
    await eventsResource.get(forceReload: true);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: RefreshIndicator(
            onRefresh: refresh,
            child: ListView.builder(
                itemBuilder: (context, index) =>
                    Text(eventsResource.data[index].title))));
  }
}

class EventList extends StatefulWidget {
  @override
  _EventListState createState() => _EventListState();
}

void main() => runApp(MaterialApp(
    title: 'Network Resource example',
    home: FutureBuilder<List<Event>>(
      future: eventsResource.get(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return EventList();
        } else if (snapshot.hasError) {
          return Text('${snapshot.error}');
        }
        return Center(child: CircularProgressIndicator());
      },
    )));
```
