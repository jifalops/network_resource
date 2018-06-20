import 'package:flutter/material.dart';
import '../lib/network_resource.dart';

final _resource1 = StringNetworkResource(
  url: 'http://example.com/resource1.json',
  filename: 'resource1.json',
  maxAge: Duration(minutes: 60),
);

class MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: FutureBuilder<String>(
      future: _resource1.get(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Text('${snapshot.data}');
        } else if (snapshot.hasError) {
          return Text('${snapshot.error}');
        }
        return Center(child: CircularProgressIndicator());
      },
    ));
  }
}

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Network Resource example',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  MyHomePageState createState() {
    return new MyHomePageState();
  }
}
