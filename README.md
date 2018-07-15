# network_resource

Automatically cache network resources and use them when offline.

`NetworkResource` fetches data over HTTP, caches it in a file, and holds it in memory.
The main method, `get()`, will return the value in memory, cache,
or fetch from the network -- in that order. If the cache file is older than `maxAge`,
the cache will be updated from the network if available. To manually refresh, use `get(forceReload: true)`
or `getFromNetwork()`. The latter can be used to avoid cache fallback.

## Example
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

> See `./example/main.dart` for a full example with pull to refresh.

## TODO

* Make `maxAge` optional.
* Make holding the raw value in memory optional.
* Consider supporting HTTP POST.
