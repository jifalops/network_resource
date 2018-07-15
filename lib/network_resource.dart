/// Automatically cache network resources and use them when offline.
///
/// [NetworkResource<T>] fetches data over HTTP, caches it in a file, and holds it in memory.
/// The main method, [NetworkResource.get()], will return the value in memory, cache,
/// or fetch from the network -- in that order. If the cache file is older than [NetworkResource.maxAge],
/// the cache will be updated from the network if available. To manually refresh, use `get(forceReload: true)`
/// or [NetworkResource.getFromNetwork()]. The latter can be used to avoid cache fallback.
library network_resource;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

/// A base implementation to fetch data over HTTP, cache it in a file, and hold it
/// in memory.
///
/// Use the [StringNetworkResource], [StringListNetworkResource], or
/// [BinaryNetworkResource] depending on your data type.
abstract class NetworkResource<T> {
  /// The data to fetch and cache.
  final String url;

  /// The file name to use for the cached copy.
  final String filename;

  /// Determines when the cached copy has expired.
  final Duration maxAge;

  /// If not defined, the application's data directory will be used.
  /// Do NOT include a trailing slash.
  final String path;

  /// Optional. The [http.Client] to use, recommended if frequently hitting
  /// the same server. If not specified, [http.get()] will be used instead.
  final http.Client client;

  /// Optional. The HTTP headers to send with the request.
  final Map<String, String> headers;

  String __path;
  File __file;
  T _data;

  NetworkResource(
      {@required this.url,
      @required this.filename,
      @required this.maxAge,
      this.path,
      this.client,
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
      _writeToCache(response);
      return _data = _parseResponse(response);
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

  T _parseResponse(http.Response response);
  Future<void> _writeToCache(http.Response response);
  Future<T> getFromCache();
}

/// A class to fetch [String] data from the network, cache it in a file, and hold
/// it in memory.
class StringNetworkResource extends NetworkResource<String> {
  /// The [Encoding] to use for non-binary [ContentType]s.
  final Encoding encoding;
  StringNetworkResource(
      {@required String url,
      @required String filename,
      @required Duration maxAge,
      this.encoding: utf8,
      String path,
      http.Client client,
      Map<String, String> headers})
      : super(
            url: url,
            filename: filename,
            maxAge: maxAge,
            path: path,
            client: client,
            headers: headers);

  @override
  String _parseResponse(http.Response response) {
    return response.body;
  }

  @override
  Future _writeToCache(http.Response response) async {
    (await cacheFile).writeAsString(response.body, encoding: encoding);
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
  /// The [Encoding] to use for non-binary [ContentType]s.
  final Encoding encoding;
  StringListNetworkResource(
      {@required String url,
      @required String filename,
      @required Duration maxAge,
      this.encoding: utf8,
      String path,
      http.Client client,
      Map<String, String> headers})
      : super(
            url: url,
            filename: filename,
            maxAge: maxAge,
            path: path,
            client: client,
            headers: headers);

  @override
  List<String> _parseResponse(http.Response response) {
    return response.body.split(RegExp(r'\r?\n'));
  }

  @override
  Future _writeToCache(http.Response response) async {
    (await cacheFile).writeAsString(response.body, encoding: encoding);
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
      {@required String url,
      @required String filename,
      @required Duration maxAge,
      String path,
      http.Client client,
      Map<String, String> headers})
      : super(
            url: url,
            filename: filename,
            maxAge: maxAge,
            path: path,
            client: client,
            headers: headers);

  @override
  List<int> _parseResponse(http.Response response) {
    return response.bodyBytes;
  }

  @override
  Future _writeToCache(http.Response response) async {
    (await cacheFile).writeAsBytes(response.bodyBytes);
  }

  @override
  Future<List<int>> getFromCache() async {
    final file = await cacheFile;
    return file.existsSync() ? file.readAsBytes() : null;
  }
}
