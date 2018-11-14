import 'dart:async';
import 'dart:convert';

import 'package:pi_build_status/src/build_results.dart';
import 'package:pi_build_status/src/utils.dart';

final _buildStatusUrl =
    Uri.parse('https://flutter-dashboard.appspot.com/api/public/get-status');

Future<Project> getBuildResults() async {
  final proj = new Project('flutter', 'Flutter');
  final res = json.decode(await fetch(_buildStatusUrl));
  List statuses = res['Statuses'];
  if (statuses != null && statuses.isNotEmpty) {
    List stages = statuses.first['Stages'];
    if (stages != null && stages.isNotEmpty) {
      stages.forEach((stage) {
        final group = new TaskGroup(stage['Name'], stage['Name']);
        proj.taskGroups[group.name] = group;

        List tasks = stage['Tasks'];
        if (tasks != null && tasks.isNotEmpty) {
          tasks.forEach((task) {
            group.tasks[task['Name']] =
                new Task(task['Key'], task['Task']['Name']);
          });
        }
      });
    }
  }
  statuses.forEach((s) {
    final sha = s['Checklist']['Checklist']['Commit']['Sha'];
    final author = s['Checklist']['Checklist']['Commit']['Author']['Login'];
    final avatar = Uri.parse(
        s['Checklist']['Checklist']['Commit']['Author']['avatar_url']);

    final commit = new Commit(sha, author, avatar);
    final overallResult = buildResultFor(s['Result']);
    final commitResult = new CommitResult(commit, overallResult);

    List stages = s['Stages'];
    stages.forEach((stage) {
      List tasks = stage['Tasks'];
      tasks.forEach((t) {
        final task = t['Task'];
        commitResult.taskResults[task['Name']] = new TaskResult(
            commit,
            proj.taskGroups[stage['Name']].tasks[task['Name']],
            buildResultFor(task['Status'], task['Attempts']));
      });
    });

    proj.commitResults.add(commitResult);
  });
  return proj;
}

BuildResult buildResultFor(String result, [int attempts = 1]) {
  switch (result) {
    case 'Succeeded':
      return attempts <= 1 ? BuildResult.Pass : BuildResult.Flake;
    case 'Failed':
      return BuildResult.Fail;
    case 'In Progress':
      return BuildResult.Running;
    case 'New':
    case 'Stuck':
    case 'Skip':
      return BuildResult.Unknown;
    default:
      throw 'Unknown build status: $result';
  }
}
