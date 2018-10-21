import 'dart:async';
import 'dart:math';

import 'package:pi_build_status/src/build_results.dart';
import 'package:pi_build_status/src/flutter_build.dart' as flutter;
import 'package:pi_build_status/src/dart_code_build.dart' as dartCode;
import 'package:collection/collection.dart';
import 'package:json_rpc_2/json_rpc_2.dart' as json_rpc;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;

const gridSize = 16;
const sendToDisplay = true;

Future main() async {
  final List<List<String>> statuses = new List.generate(
      gridSize, (_) => List.generate(gridSize, (_) => ' ', growable: false),
      growable: false);

  final flutterBuilds = await flutter.getBuildResults();
  populateFlutterColumns(flutterBuilds, statuses, startColumn: 8);

  final dartCodeBuilds = await dartCode.getBuildResults();
  populateDartCodeColumns(dartCodeBuilds, statuses, endColumn: 7);

  if (sendToDisplay) {
    await sendStatuses(statuses);
  } else {
    statuses.forEach(print);
  }
}

void populateFlutterColumns(Project proj, List<List<String>> statuses,
    {int startColumn = 0, int endColumn = gridSize - 1}) {
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
    for (var x = startColumn; x < endColumn + 1; x++) {
      statuses[y][x] = output[x - startColumn];
    }
  }
}

void populateDartCodeColumns(Project proj, List<List<String>> statuses,
    {int startColumn = 0, int endColumn = gridSize - 1}) {
  final winResults = proj.commitResults.first.taskResults.values
      .where((tr) => tr.task.id.startsWith('win_'))
      .toList();
  final macResults = proj.commitResults.first.taskResults.values
      .where((tr) => tr.task.id.startsWith('osx_'))
      .toList();
  final linuxResults = proj.commitResults.first.taskResults.values
      .where((tr) => tr.task.id.startsWith('linux_'))
      .toList();
  // We'll render a column for each platform, stable first, then a space, then
  // all unstables merged together.
  final List<List<TaskResult>> cols = [
    winResults.where((tr) => tr.task.id.endsWith('_stable_stable')).toList(),
    macResults.where((tr) => tr.task.id.endsWith('_stable_stable')).toList(),
    linuxResults.where((tr) => tr.task.id.endsWith('_stable_stable')).toList(),
    [],
    winResults.where((tr) => !tr.task.id.endsWith('_stable_stable')).toList(),
    macResults.where((tr) => !tr.task.id.endsWith('_stable_stable')).toList(),
    linuxResults.where((tr) => !tr.task.id.endsWith('_stable_stable')).toList(),
  ];
  for (var x = 0; x < min(cols.length, endColumn - startColumn); x++) {
    final results = cols[x];
    final res = groupBy(results, (TaskResult v) => v.result);
    final totalUnknown = res[BuildResult.Unknown]?.length ?? 0;
    final totalRunning = res[BuildResult.Running]?.length ?? 0;
    final totalFail = res[BuildResult.Fail]?.length ?? 0;
    final totalSkip = res[BuildResult.Skip]?.length ?? 0;
    final totalPass = res[BuildResult.Pass]?.length ?? 0;
    final output = 'F' * totalFail +
        '!' * totalSkip +
        '?' * totalUnknown +
        'R' * totalRunning +
        'P' * totalPass +
        ' ' * gridSize;
    for (var y = 0; y < gridSize; y++) {
      statuses[y][x + startColumn] = output[y];
    }
  }
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
    case ' ':
      return [0, 0, 0];
    default:
      throw 'Unknown status code: $status';
  }
}

Future sendPixels(List<List<List<int>>> pixels) async {
  var socket = IOWebSocketChannel.connect('ws://officepi:8050');
  var client = new json_rpc.Client(socket.cast<String>());
  client.listen();

  // TODO: Add an API call to do the whole screen in one API call.
  for (var y = 0; y < gridSize; y++) {
    final row = pixels[y];
    for (var x = 0; x < row.length; x++) {
      final pixel = row[x];
      await client.sendRequest(
          'set_pixel', [x, gridSize - y - 1].followedBy(pixel).toList());
    }
  }
  await client.sendRequest('show');
  await socket.sink.close(status.normalClosure);
}
