import 'dart:io';

/// Optional convenience for the full workspace; a standalone clone uses its
/// configured external API and does not require the backend repository.
Future<void> main() async {
  final backend = Directory('../backend').absolute;
  final launcher = File('${backend.path}/tools/dev_backend.dart');
  if (!launcher.existsSync()) {
    stdout.writeln('No sibling backend checkout. Using the configured API.');
    return;
  }
  final process = await Process.start(
    Platform.resolvedExecutable,
    [launcher.path],
    workingDirectory: backend.path,
    mode: ProcessStartMode.inheritStdio,
  );
  exitCode = await process.exitCode;
}
