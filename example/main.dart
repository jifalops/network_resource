import 'dart:convert';
import 'dart:io';
import 'package:network_resource/network_resource.dart';

// A string list, line by line.
final words = StringListNetworkResource(
  url: 'https://example.com/wordlist.txt',
  cacheFile: File('wordlist.txt'),
);

// Extending [NetworkResource] to provide a different data type.
class EventListResource extends NetworkResource<List<Event>> {
  EventListResource()
      : super(
            url: 'http://example.com/events.json',
            cacheFile: File('events.json'),
            maxAge: Duration(minutes: 60),
            isBinary: false);
  @override
  List<Event> parseContents(contents) {
    List events;
    json.decode(contents).forEach((item) => events.add(Event(item)));
    return events;
  }
}

class Event {
  final String title;
  Event(this.title);
}
