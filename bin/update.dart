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
  final win = proj.commitResults.first.taskResults.values
      .where((tr) => tr.task.id.startsWith('win_'))
      .toList();
  final mac = proj.commitResults.first.taskResults.values
      .where((tr) => tr.task.id.startsWith('osx_'))
      .toList();
  final linux = proj.commitResults.first.taskResults.values
      .where((tr) => tr.task.id.startsWith('linux_'))
      .toList();
  // We'll render in 4 seconds to fit into the first 8 cols
  // each section is Win/Mac/Linux
  //
  // Stable Dart / Stable Code    |     Stable Dart / Insiders Code
  // --------------------------------------------------------------
  // Dev Dart / Stable Code       |     Dev Dart / Insiders Code
  int startRow = 0;
  startRow = renderGroups(stableDartStableCode, stableDartInsidersCode, win,
      mac, linux, endColumn, startColumn, startRow, statuses);
  startRow++; // Leave a gap
  startRow = renderGroups(devDartStableCode, devDartInsidersCode, win, mac,
      linux, endColumn, startColumn, startRow, statuses);
}

int renderGroups(
    bool col1(TaskResult tr),
    bool col2(TaskResult tr),
    List<TaskResult> win,
    List<TaskResult> mac,
    List<TaskResult> linux,
    int endColumn,
    int startColumn,
    int startRow,
    List<List<String>> statuses) {
  final List<Iterable<TaskResult>> cols = [
    win.where(col1),
    mac.where(col1),
    linux.where(col1),
    [],
    win.where(col2),
    mac.where(col2),
    linux.where(col2),
  ];
  var renderedRows = 0;
  for (var x = 0; x < min(cols.length, endColumn - startColumn); x++) {
    final results = cols[x].toList();
    renderedRows = max(renderedRows, results.length);
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
    for (var y = 0; y < gridSize - startRow; y++) {
      statuses[y + startRow][x + startColumn] = output[y];
    }
  }
  return startRow + renderedRows;
}

bool stableDartStableCode(TaskResult tr) =>
    tr.task.id.endsWith('_stable_stable');
bool stableDartInsidersCode(TaskResult tr) =>
    tr.task.id.endsWith('_stable_insiders');
bool devDartStableCode(TaskResult tr) => tr.task.id.endsWith('_dev_stable');
bool devDartInsidersCode(TaskResult tr) => tr.task.id.endsWith('_dev_insiders');

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
