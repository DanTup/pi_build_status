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
    return resp.transform(utf8.decoder).join();
  } finally {
    client.close();
  }
}
