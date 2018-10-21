class BuildResult {
  static BuildResult Unknown = new BuildResult._('Unknown');
  static BuildResult Running = new BuildResult._('Running');
  static BuildResult Pass = new BuildResult._('Pass');
  static BuildResult Fail = new BuildResult._('Fail');
  static BuildResult Flake = new BuildResult._('Flake');
  static BuildResult Skip = new BuildResult._('Skip');
  final String value;
  BuildResult._(this.value);
}

class Commit {
  final String hash;
  String get id => hash;
  final String authorName;
  final Uri authorAvatar;

  Commit(this.hash, this.authorName, this.authorAvatar);
}

class Project {
  // Flutter, Dart Code
  final String id;
  final String name;
  final Map<String, TaskGroup> taskGroups = new Map<String, TaskGroup>();
  final List<CommitResult> commitResults = new List<CommitResult>();

  Project(this.id, this.name);
}

class Task {
  // Individual task (eg. devicelab task, or an individial test)
  final String id, name;
  Task(this.id, this.name);
}

class TaskGroup {
  // Dart Code: Stable/Stable, Stable/Dev, Dev/Stable, Dev/Dev
  // Flutter: Cirrus, Chromebot, Android, etc.
  final String id, name;
  final Map<String, Task> tasks = new Map<String, Task>();

  TaskGroup(this.id, this.name);
}

class TaskResult {
  final Commit commit;
  final Task task;
  final BuildResult result;

  TaskResult(this.commit, this.task, this.result);
}

class CommitResult {
  final Commit commit;
  final BuildResult result;
  final Map<String, TaskResult> taskResults = new Map<String, TaskResult>();

  CommitResult(this.commit, this.result);
}
