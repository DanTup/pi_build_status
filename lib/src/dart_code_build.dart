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

const platforms = ['win', 'osx', 'linux'];
const dartVersions = ['stable', 'dev'];
const codeVersions = ['stable', 'insiders'];

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

  for (final platform in platforms) {
    for (final dartVersion in dartVersions) {
      for (final codeVersion in codeVersions) {
        // Fetch and parse the CSV summary.
        await readResults(
            platform, dartVersion, codeVersion, commit, commitResult);
      }
    }
  }

  return proj;
}

Future readResults(String platform, String dartVersion, String codeVersion,
    Commit commit, CommitResult commitResult) async {
  final resultSummary = await fetch(_s3BucketRoot.replace(
      path:
          'master/${commit.hash}/${platform}/${dartVersion}_${codeVersion}_summary.csv'));
  if (resultSummary == null) {
    return;
  }
  for (final suiteResults
      in resultSummary.split('\n').where((l) => l.isNotEmpty)) {
    final resultParts = suiteResults.split(',');
    final suiteName = resultParts[0];
    final numFailed = int.parse(resultParts[3]);
    final numSkipped = int.parse(resultParts[2]);
    // final numPassed = int.parse(resultParts[1]);

    final task = new Task('${platform}_$suiteName',
        '$suiteName ($platform, $dartVersion Dart, $codeVersion VS Code)');
    final taskResult = new TaskResult(
        commit,
        task,
        numFailed > 0
            ? BuildResult.Fail
            : numSkipped > 0 ? BuildResult.Skip : BuildResult.Pass);
    commitResult.taskResults[task.name] = taskResult;
  }
}
