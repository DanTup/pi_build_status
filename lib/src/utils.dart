import 'dart:async';
import 'dart:convert';
import 'dart:io';

var numHttpRequests = 0;

Future<String> fetch(Uri uri) async {
  numHttpRequests++;
  final client = new HttpClient();
  try {
    final req = await client.getUrl(uri);
    final resp = await req.close();
    // If we don't ready the body and just return null, it seems to hang
    // and never exit, so we read even if we'll return null.
    final body = resp.transform(utf8.decoder).join();
    return resp.statusCode != HttpStatus.ok ? null : body;
  } finally {
    client.close();
  }
}
