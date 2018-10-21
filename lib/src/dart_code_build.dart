import 'dart:async';
import 'dart:convert';
import 'package:pi_build_status/src/utils.dart';

import 'package:pi_build_status/src/build_results.dart';

final _gitHubMasterBrancheUrl = Uri.parse(
    'https://api.github.com/repos/Dart-Code/Dart-Code/branches/master');
final _s3BucketRoot = Uri.parse('https://test-results.dartcode.org/');

final failurePattern = new RegExp(r'<failure');
final skippedPattern = new RegExp(r'<skipped');
final testCasePattern = new RegExp(r'<testcase');

// TODO: This makes a lot of HTTP requests; make it better (this will require
// changing the file we write during builds).
Future<Project> getBuildResults() async {
  final proj = new Project('dart-code', 'Dart Code');
  final masterBranch = json.decode(await fetch(_gitHubMasterBrancheUrl));
  final commit = new Commit(
      masterBranch['commit']['sha'],
      masterBranch['commit']['author']['login'],
      Uri.parse(masterBranch['commit']['author']['avatar_url']));

  final commitResult = new CommitResult(commit, BuildResult.Unknown);
  proj.commitResults.add(commitResult);

  final fileResultsXml = await fetch(_s3BucketRoot
      .replace(queryParameters: {'prefix': 'master/${commit.hash}'}));
  // Shhhhhhhh!
  final filenamePattern =
      new RegExp('<Key>(master\\/${commit.hash}[_\\w\/]+\\.xml)<\\/Key>');
  final List<String> files = filenamePattern
      .allMatches(fileResultsXml)
      .map((m) => m.group(1))
      .toList();

  await Future.wait(
      files.map((file) => readResults(file, commit, commitResult)));

  return proj;
}

Future readResults(
    String filePath, Commit commit, CommitResult commitResult) async {
  final resultsXml = await fetch(_s3BucketRoot.replace(path: filePath));
  final numFailed = failurePattern.allMatches(resultsXml).length;
  final numSkipped = skippedPattern.allMatches(resultsXml).length;
  // final numPassed =
  //     testCasePattern.allMatches(resultsXml).length - numFailed - numSkipped;

  final pathParts = filePath.split('/');
  final platform = pathParts[2];
  final filename = pathParts[3].split('.').first;
  final nameParts = filename.split('_');
  final dartVersion = nameParts[nameParts.length - 2];
  final vsCodeVersion = nameParts[nameParts.length - 1];
  final suiteName = nameParts.sublist(0, nameParts.length - 2).join(' ');

  final task = new Task('${platform}_$filename',
      '$suiteName ($platform, $dartVersion Dart, $vsCodeVersion VS Code)');
  final taskResult = new TaskResult(
      commit,
      task,
      numFailed > 0
          ? BuildResult.Fail
          : numSkipped > 0 ? BuildResult.Skip : BuildResult.Pass);
  commitResult.taskResults[task.name] = taskResult;
}
