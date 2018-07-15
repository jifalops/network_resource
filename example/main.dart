// This example subclasses `NetworkResource` to manage fetching and parsing
// an event list in JSON format. Items are shown in a list with pull-to-refresh.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../lib/network_resource.dart';

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
