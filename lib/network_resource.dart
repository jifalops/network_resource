library network_resource;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

enum ContentType { string, stringList, binary }

class ResourceData<T> {
  final T data;
  final bool fromCache;
  final bool cacheExpired;
  ResourceData(this.data, {this.fromCache: false, this.cacheExpired: false});
}

class NetworkResource {
  final ContentType contentType;
  final Encoding encoding;
  final String url;
  final String filename;
  final Duration maxAge;
  final String path;
  final http.Client client;
  final Map<String, String> headers;

  String __path;
  File __file;

  NetworkResource(
      {

      /// The data to fetch and cache.
      this.url,

      /// The file name to use for the cached copy.
      this.filename,

      /// Determines when the cached copy has expired.
      this.maxAge,
      this.contentType: ContentType.string,

      /// The [Encoding] to use for non-binary [ContentType]s.
      this.encoding: utf8,

      /// If not defined, the `application-data-directory/cache` will be used.
      this.path,

      /// Optional. The [http.Client] to use, recommended if frequently hitting
      /// the same server. If not specified, [http.get()] will be used instead.
      this.client,

      /// Optional. The HTTP headers to send with the request.
      this.headers});

  Future<ResourceData> get({bool forceReload = false}) async {
    if (forceReload || await expired) {
      print('$filename: Fetching from $url');
      return getFromNetwork();
    } else {
      print('Loading cached copy of $filename');
      return getFromCache();
    }
  }

  /// Attempts to fetch this resource from the network.
  /// Upon failure it will return the cached copy if it exists.
  Future<ResourceData> getFromNetwork() async {
    final response = await (client == null
        ? http.get(url, headers: headers)
        : client.get(url, headers: headers));
    if (response.statusCode == HttpStatus.OK) {
      print('$url Fetched. Updating cache...');
      final contents = contentType == ContentType.binary
          ? response.bodyBytes
          : response.body;
      await _write(contents);
      return ResourceData(contents);
    } else {
      print('$url Fetch failed (${response.statusCode}).');
      final file = await cacheFile;
      if (await file.exists()) {
        print('$url Using a cached copy.');
        return getFromCache();
      } else {
        print('$url No cached copy available. Bailing.');
        return ResourceData(null);
      }
    }
  }

  Future<ResourceData> getFromCache() async {
    return ResourceData(await _contents,
        fromCache: true, cacheExpired: await expired);
  }

  Future<bool> get expired async {
    final file = await cacheFile;
    return (await file.exists())
        ? DateTime.now().difference(await file.lastModified()) > maxAge
        : true;
  }

  Future<String> get _path async => __path ??=
      path != null ? path : (await getApplicationDocumentsDirectory()).path;

  Future<File> get cacheFile async =>
      __file ??= File('${await _path}/$filename');

  Future<dynamic> get _contents async {
    try {
      final file = await cacheFile;
      switch (contentType) {
        case ContentType.string:
          return file.readAsString(encoding: encoding);
        case ContentType.stringList:
          return file.readAsLines(encoding: encoding);
        case ContentType.binary:
          return file.readAsBytes();
      }
    } catch (e) {
      print('Exception while reading file $filename: $e');
      return null;
    }
  }

  Future<File> _write(dynamic contents) async {
    try {
      final file = await cacheFile;
      switch (contentType) {
        case ContentType.binary:
          return file.writeAsBytes(contents);
        default:
          return file.writeAsString(contents, encoding: encoding);
      }
    } catch (e) {
      print('Exception while writing file $filename: $e');
      return null;
    }
  }
}
