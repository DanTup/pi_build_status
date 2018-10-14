import 'dart:async';

import 'package:pi_build_status/src/build_results.dart';
import 'package:pi_build_status/src/flutter_build.dart' as flutter;
import 'package:collection/collection.dart';
import "package:json_rpc_2/json_rpc_2.dart" as json_rpc;
import "package:web_socket_channel/io.dart";
import 'package:web_socket_channel/status.dart' as status;

const gridSize = 16;

Future main() async {
  final proj = await flutter.getBuildResults();
  List<List<String>> statuses = new List.generate(
      gridSize, (_) => List.generate(gridSize, (_) => ' ', growable: false),
      growable: false);
  for (var y = 0; y < gridSize; y++) {
    final commit = proj.commitResults[y];
    final res = groupBy(commit.taskResults.values, (TaskResult v) => v.result);
    final totalUnknown = res[BuildResult.Unknown]?.length ?? 0;
    final totalRunning = res[BuildResult.Running]?.length ?? 0;
    final totalFail = res[BuildResult.Fail]?.length ?? 0;
    final totalFlake = res[BuildResult.Flake]?.length ?? 0;
    final totalPass = res[BuildResult.Pass]?.length ?? 0;
    final output = 'F' * totalFail +
        '!' * totalFlake +
        '?' * totalUnknown +
        'R' * totalRunning +
        'P' * totalPass;
    print(output.substring(0, gridSize));
    for (var x = 0; x < gridSize; x++) {
      statuses[gridSize - 1 - y][x] = output[x];
    }
  }
  await sendStatuses(statuses);
}

Future sendStatuses(List<List<String>> statuses) async {
  final pixels = statuses.map((row) => row.map(charToColour).toList()).toList();
  await sendPixels(pixels);
}

List<int> charToColour(String status) {
  switch (status) {
    case '?':
    case 'R':
      return [150, 150, 255];
    case 'F':
      return [255, 0, 0];
    case '!':
      return [255, 255, 0];
    case 'P':
      return [0, 255, 0];
    default:
      throw 'Unknown status code: $status';
  }
}

Future sendPixels(List<List<List<int>>> pixels) async {
  var socket = IOWebSocketChannel.connect('ws://officepi:8050');
  var client = new json_rpc.Client(socket.cast<String>());
  client.listen();

  // TODO: Add an API call to do the whole screen in one API call.
  for (var y = 0; y < pixels.length; y++) {
    final row = pixels[y];
    for (var x = 0; x < row.length; x++) {
      final pixel = row[x];
      await client.sendRequest("set_pixel", [x, y].followedBy(pixel).toList());
    }
  }
  await client.sendRequest("show");
  await socket.sink.close(status.normalClosure);
}
