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
import 'package:path/path.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

/// A base implementation to fetch data over HTTP, cache it in a file, and hold it
/// in memory.
///
/// Use the [StringNetworkResource], [StringListNetworkResource], or
/// [BinaryNetworkResource] depending on your data type; or extend and create
/// your own.
abstract class NetworkResource<T> {
  /// The location of the data to fetch and cache.
  final String url;

  /// The cached copy of the data fetched from [url]. Its parent directory must
  /// exist. If you are using Flutter, try the
  /// [path provider](https://pub.dartlang.org/packages/path_provider) package
  /// to help specify where the cache file should be located.
  final File cacheFile;

  /// Determines when the cached copy has expired.
  final Duration maxAge;

  /// Optional. The [http.Client] to use, recommended if frequently hitting
  /// the same server. If not specified, [http.get()] will be used instead.
  final http.Client client;

  /// Optional. The HTTP headers to send with the request.
  final Map<String, String> headers;

  /// Whether the raw data being fetched is binary or encoded as a string.
  final bool isBinary;

  /// The string encoding to use when the raw data fetched is non-binary.
  final Encoding encoding;

  T _data;
  String _filename;

  /// If [path] is not defined, the application's data directory will be used.
  /// Do NOT include a trailing slash.
  NetworkResource(
      {@required this.url,
      @required this.cacheFile,
      @required this.isBinary,
      this.maxAge,
      this.encoding: utf8,
      String path,
      this.client,
      this.headers});

  T get data => _data;

  String get filename => _filename ??= basename(cacheFile.path);

  /// Returns `true` if the file does not exist, `false` if the file exists but
  /// [maxAge] is null; otherwise compares the [cacheFile]'s age to [maxAge].
  Future<bool> get isExpired async {
    final file = await cacheFile;
    return file.existsSync()
        ? (maxAge != null
            ? new DateTime.now().difference(file.lastModifiedSync()) > maxAge
            : false)
        : true;
  }

  /// Retrieve the most readily available data in the order of RAM, cache,
  /// then network. If [forceReload] is `true` then [getFromNetwork()] will be
  /// called, using the cache as a fallback if the network request fails.
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
    if (response != null && response.statusCode == HttpStatus.ok) {
      print('$url Fetched. Updating cache...');
      var contents = isBinary ? response.bodyBytes : response.body;
      _writeToCache(contents);
      return _data = parseContents(contents);
    } else {
      print('$url Fetch failed (${response?.statusCode ?? -1}).');
      if (useCacheFallback) {
        print('$url Using a cached copy if available.');
        return getFromCache();
      } else {
        print('Not attempting to find in cache.');
        return null;
      }
    }
  }

  void _writeToCache(dynamic contents) async {
    final file = await cacheFile;
    if (isBinary) {
      file.writeAsBytesSync(contents);
    } else {
      file.writeAsStringSync(contents, encoding: encoding);
    }
  }

  Future<T> getFromCache() async {
    final file = await cacheFile;
    return file.existsSync()
        ? (isBinary
            ? _data = parseContents(file.readAsBytesSync())
            : _data = parseContents(file.readAsStringSync(encoding: encoding)))
        : null;
  }

  /// Parse the [String] or [List<int>] into the desired type.
  T parseContents(dynamic contents);
}

/// A class to fetch [String] data from the network, cache it in a file, and hold
/// it in memory.
class StringNetworkResource extends NetworkResource<String> {
  StringNetworkResource(
      {@required String url,
      @required File cacheFile,
      Duration maxAge,
      Encoding encoding: utf8,
      String path,
      http.Client client,
      Map<String, String> headers})
      : super(
            url: url,
            cacheFile: cacheFile,
            isBinary: false,
            maxAge: maxAge,
            encoding: encoding,
            path: path,
            client: client,
            headers: headers);
  @override
  String parseContents(contents) => contents;
}

/// A class to fetch [List<String>] data from the network, cache it in a file,
/// and hold it in memory.
class StringListNetworkResource extends NetworkResource<List<String>> {
  StringListNetworkResource(
      {@required String url,
      @required File cacheFile,
      Duration maxAge,
      Encoding encoding: utf8,
      String path,
      http.Client client,
      Map<String, String> headers})
      : super(
            url: url,
            cacheFile: cacheFile,
            isBinary: false,
            maxAge: maxAge,
            encoding: encoding,
            path: path,
            client: client,
            headers: headers);
  @override
  List<String> parseContents(contents) => contents.split(new RegExp(r'\r?\n'));
}

/// A class to fetch [List<int>] data from the network (bytes), cache it in a
/// file, and hold it in memory.
class BinaryNetworkResource extends NetworkResource<List<int>> {
  BinaryNetworkResource(
      {@required String url,
      @required File cacheFile,
      Duration maxAge,
      String path,
      http.Client client,
      Map<String, String> headers})
      : super(
            url: url,
            cacheFile: cacheFile,
            isBinary: true,
            maxAge: maxAge,
            path: path,
            client: client,
            headers: headers);
  @override
  List<int> parseContents(contents) => contents;
}
