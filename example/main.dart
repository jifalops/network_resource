import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../lib/network_resource.dart';

// The events resource.
final eventsResource = StringNetworkResource(
  url: 'http://example.com/events.json',
  filename: 'events.json',
  maxAge: Duration(minutes: 60),
);

// Parse the JSON string into a local data type.
List<Event> parseEvents(String data) {
  List<Event> events;
  json.decode(data).forEach((item) => events.add(Event(item)));
  return events;
}

// The Widget's state, with pull to refresh.
class _EventListState extends State<EventList> {
  Future<Null> refresh() async {
    var data = await eventsResource.get(forceReload: true);
    widget.events.clear();
    widget.events.addAll(parseEvents(data));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: RefreshIndicator(
            onRefresh: refresh,
            child: ListView.builder(
                itemBuilder: (context, index) =>
                    Text(widget.events[index].title))));
  }
}

class EventList extends StatefulWidget {
  final List<Event> events;
  EventList(this.events);
  @override
  _EventListState createState() => _EventListState();
}

class Event {
  final String title;
  Event(this.title);
}

void main() => runApp(MaterialApp(
    title: 'Network Resource example',
    home: FutureBuilder<String>(
      future: eventsResource.get(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return EventList(parseEvents(snapshot.data));
        } else if (snapshot.hasError) {
          return Text('${snapshot.error}');
        }
        return Center(child: CircularProgressIndicator());
      },
    )));
