library network_resource;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

/// A class to fetch data from the network, cache it in a file, and hold it
/// in memory. Use the [StringNetworkResource], [StringListNetworkResource], or
/// [BinaryNetworkResource] depending on your data type.
abstract class NetworkResource<T> {
  final String url;
  final String filename;
  final Duration maxAge;
  final String path;
  final http.Client client;
  final Map<String, String> headers;

  String __path;
  File __file;
  T _data;

  NetworkResource(
      {

      /// The data to fetch and cache.
      @required this.url,

      /// The file name to use for the cached copy.
      @required this.filename,

      /// Determines when the cached copy has expired.
      @required this.maxAge,

      /// If not defined, the application's data directory will be used.
      /// Do NOT use a trailing slash.
      this.path,

      /// Optional. The [http.Client] to use, recommended if frequently hitting
      /// the same server. If not specified, [http.get()] will be used instead.
      this.client,

      /// Optional. The HTTP headers to send with the request.
      this.headers});

  T get data => _data;

  Future<String> get _path async => __path ??=
      path != null ? path : (await getApplicationDocumentsDirectory()).path;

  Future<File> get cacheFile async =>
      __file ??= File('${await _path}/$filename');

  Future<bool> get isCached async => (await cacheFile)?.exists() ?? false;

  Future<bool> get isExpired async {
    final file = await cacheFile;
    return (await file.exists())
        ? DateTime.now().difference(await file.lastModified()) > maxAge
        : true;
  }

  Future<T> get({bool forceReload = false}) async {
    if (_data != null && !forceReload) {
      return _data;
    } else if (forceReload || await isExpired) {
      print('$filename: Fetching from $url');
      return _data = await getFromNetwork();
    } else {
      print('Loading cached copy of $filename');
      return _data = await getFromCache();
    }
  }

  Future<T> getFromNetwork({useCacheFallback = true}) async {
    final response = await (client == null
        ? http.get(url, headers: headers)
        : client.get(url, headers: headers));
    if (response.statusCode == HttpStatus.OK) {
      print('$url Fetched. Updating cache...');
      return _data = await _writeToCache(response);
    } else {
      print('$url Fetch failed (${response.statusCode}).');
      if (useCacheFallback) {
        print('$url Using a cached copy if available.');
        return getFromCache();
      } else {
        print('Not attempting to find in cache.');
        return null;
      }
    }
  }

  Future<T> getFromCache();
  Future<T> _writeToCache(http.Response response);
}

/// A class to fetch [String] data from the network, cache it in a file, and hold
/// it in memory.
class StringNetworkResource extends NetworkResource<String> {
  final Encoding encoding;
  StringNetworkResource(
      {

      /// The data to fetch and cache.
      @required String url,

      /// The file name to use for the cached copy.
      @required String filename,

      /// Determines when the cached copy has expired.
      @required Duration maxAge,

      /// The [Encoding] to use for non-binary [ContentType]s.
      this.encoding: utf8,

      /// If not defined, the application's data directory will be used.
      /// Do NOT use a trailing slash.
      String path,

      /// Optional. The [http.Client] to use, recommended if frequently hitting
      /// the same server. If not specified, [http.get()] will be used instead.
      http.Client client,

      /// Optional. The HTTP headers to send with the request.
      Map<String, String> headers})
      : super(
            url: url,
            filename: filename,
            maxAge: maxAge,
            path: path,
            client: client,
            headers: headers);

  @override
  Future<String> _writeToCache(http.Response response) async {
    (await cacheFile).writeAsString(response.body, encoding: encoding);
    return response.body;
  }

  @override
  Future<String> getFromCache() async {
    final file = await cacheFile;
    return file.existsSync() ? file.readAsStringSync(encoding: encoding) : null;
  }
}

/// A class to fetch [List<String>] data from the network, cache it in a file,
/// and hold it in memory.
class StringListNetworkResource extends NetworkResource<List<String>> {
  final Encoding encoding;
  StringListNetworkResource(
      {

      /// The data to fetch and cache.
      @required String url,

      /// The file name to use for the cached copy.
      @required String filename,

      /// Determines when the cached copy has expired.
      @required Duration maxAge,

      /// The [Encoding] to use for non-binary [ContentType]s.
      this.encoding: utf8,

      /// If not defined, the application's data directory will be used.
      /// Do NOT use a trailing slash.
      String path,

      /// Optional. The [http.Client] to use, recommended if frequently hitting
      /// the same server. If not specified, [http.get()] will be used instead.
      http.Client client,

      /// Optional. The HTTP headers to send with the request.
      Map<String, String> headers})
      : super(
            url: url,
            filename: filename,
            maxAge: maxAge,
            path: path,
            client: client,
            headers: headers);

  @override
  Future<List<String>> _writeToCache(http.Response response) async {
    (await cacheFile).writeAsString(response.body, encoding: encoding);
    return response.body.split(RegExp(r'\r?\n'));
  }

  @override
  Future<List<String>> getFromCache() async {
    final file = await cacheFile;
    return file.existsSync() ? file.readAsLinesSync(encoding: encoding) : null;
  }
}

/// A class to fetch [List<int>] data from the network (bytes), cache it in a
/// file, and hold it in memory.
class BinaryNetworkResource extends NetworkResource<List<int>> {
  BinaryNetworkResource(
      {

      /// The data to fetch and cache.
      @required String url,

      /// The file name to use for the cached copy.
      @required String filename,

      /// Determines when the cached copy has expired.
      @required Duration maxAge,

      /// If not defined, the application's data directory will be used.
      /// Do NOT use a trailing slash.
      String path,

      /// Optional. The [http.Client] to use, recommended if frequently hitting
      /// the same server. If not specified, [http.get()] will be used instead.
      http.Client client,

      /// Optional. The HTTP headers to send with the request.
      Map<String, String> headers})
      : super(
            url: url,
            filename: filename,
            maxAge: maxAge,
            path: path,
            client: client,
            headers: headers);

  @override
  Future<List<int>> _writeToCache(http.Response response) async {
    (await cacheFile).writeAsBytes(response.bodyBytes);
    return response.bodyBytes;
  }

  @override
  Future<List<int>> getFromCache() async {
    final file = await cacheFile;
    return file.existsSync() ? file.readAsBytes() : null;
  }
}
