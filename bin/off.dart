import 'dart:async';

import 'package:json_rpc_2/json_rpc_2.dart' as json_rpc;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;

Future main() async {
  var socket = IOWebSocketChannel.connect('ws://192.168.0.115:8050');
  var client = new json_rpc.Client(socket.cast<String>());
  client.listen();
  await client.sendRequest('off');
  await socket.sink.close(status.normalClosure);
}
