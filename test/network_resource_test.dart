import 'dart:io';
import 'dart:async';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:network_resource/network_resource.dart';
import 'package:http/http.dart' as http;

class MockClient extends Mock implements http.Client {}

final errorUrl = 'https://example.com/error';
final stringFile = 'test/string.txt';
final stringListFile = 'test/string-list.txt';
final binaryFile = 'test/binary.bin';

final stringData = 'some data';
final stringListData = 'some\nmore\r\ndata';
final stringListDataList = ['some', 'more', 'data'];
final binaryData = [0, 1, 2];

void main() {
  final client = new MockClient();
  when(client.get(errorUrl, headers: null))
      .thenAnswer((_) async => new http.Response('', 404));
  when(client.get(stringFile, headers: null))
      .thenAnswer((_) async => new http.Response(stringData, 200));
  when(client.get(stringListFile, headers: null))
      .thenAnswer((_) async => new http.Response(stringListData, 200));
  when(client.get(binaryFile, headers: null))
      .thenAnswer((_) async => new http.Response.bytes(binaryData, 200));

  final stringRes = new StringNetworkResource(
      client: client, url: stringFile, cacheFile: new File(stringFile));
  final stringListRes = new StringListNetworkResource(
      client: client, url: stringListFile, cacheFile: new File(stringListFile));
  final binaryRes = new BinaryNetworkResource(
      client: client, url: binaryFile, cacheFile: new File(binaryFile));

  final expiredRes = new StringNetworkResource(
      client: client,
      url: stringFile,
      cacheFile: new File(stringFile),
      maxAge: new Duration(microseconds: 1));
  final errorRes = new StringNetworkResource(
      client: client,
      url: errorUrl,
      cacheFile: new File(stringFile),
      maxAge: new Duration(microseconds: 1));

  test('Data is null if fetch fails and there is no cache file.', () async {
    expect(await errorRes.get(), isNull);
  });

  group('Correct data fetched and written to cache.', () {
    test('String data.', () async {
      expect(await stringRes.get(), stringData);
    });
    test('String list data.', () async {
      expect(await stringListRes.get(), stringListDataList);
    });
    test('Binary data.', () async {
      expect(await binaryRes.get(), binaryData);
    });

    // Data returns without waiting for the file write to complete.
    // These might fail if the write hasn't completed, but [File] might
    // handle the write-then-read situation internally.
    test('String file.', () async {
      expect(await stringRes.getFromCache(), stringData);
    });
    test('String list file.', () async {
      expect(await stringListRes.getFromCache(), stringListDataList);
    });
    test('Binary file.', () async {
      expect(await binaryRes.getFromCache(), binaryData);
    });
  });

  test(
      'Data is returned if the fetch fails but the cache file exists, even if it is expired.',
      () async {
    expect(await errorRes.get(forceReload: true), stringData);
  });

  // This usually fails because the modified times are usually equal even
  // when the file is overwritten.
  test('Getting expired data automatically refreshes from the network.',
      () async {
    final oldTime = await expiredRes.cacheFile.lastModified();
    await expiredRes.get(flush: true);
    await new Future.delayed(new Duration(seconds: 2));
    final newTime = new File(expiredRes.cacheFile.path).lastModifiedSync();
    expect(oldTime.isBefore(newTime), true);
  });

  test('Cleanup created files', () async {
    expect((await stringRes.cacheFile.delete()).existsSync(), false);
    expect((await stringListRes.cacheFile.delete()).existsSync(), false);
    expect((await binaryRes.cacheFile.delete()).existsSync(), false);
  });
}
