// Corrected import path to use the new package name
import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;
// Corrected import path to use the new package name
import 'package:flutter_packages_remover/unused_package_remover.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('list',
        abbr: 'l',
        negatable: false,
        help: 'List unused packages without removing them (default).')
    ..addFlag('remove',
        abbr: 'r',
        negatable: false,
        help: 'Remove unused packages from pubspec.yaml.')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Print this usage information.');

  ArgResults argResults;
  try {
    argResults = parser.parse(arguments);
  } on FormatException catch (e) {
    print('Error: ${e.message}');
    print('');
    print(parser.usage);
    exit(1);
  }

  if (argResults['help']) {
    print('Find and remove unused packages from your project\'s pubspec.yaml.');
    print('');
    // Corrected usage string
    print('Usage: dart run flutter_packages_remover [options] [<project_path>]');
    print('');
    print(parser.usage);
    exit(0);
  }

  final bool listOnly = argResults['list'] || !argResults['remove'];
  final bool remove = argResults['remove'];

  String projectPath = '.'; // Default to current directory
  if (argResults.rest.isNotEmpty) {
    projectPath = argResults.rest.first;
  }

  final pubspecPath = p.join(projectPath, 'pubspec.yaml');
  if (!File(pubspecPath).existsSync()) {
    print('Error: pubspec.yaml not found in $projectPath');
    exit(1);
  }

  print('Analyzing project in: ${p.absolute(projectPath)}');

  try {
    // Function calls remain the same, as they are now correctly imported
    final unusedPackages = await findUnusedPackages(projectPath);

    if (unusedPackages.isEmpty) {
      print('\nNo unused packages found in dependencies.');
    } else {
      print('\nUnused packages in dependencies:');
      for (final package in unusedPackages) {
        print('- $package');
      }

      if (remove) {
        stdout.write('\nAre you sure you want to remove these ${unusedPackages.length} packages from pubspec.yaml? (y/N): ');
        final confirmation = stdin.readLineSync()?.trim().toLowerCase();

        if (confirmation == 'y') {
          await removePackages(pubspecPath, unusedPackages);
          print('\nSuccessfully removed ${unusedPackages.length} packages from pubspec.yaml.');
          print('A backup of the original pubspec.yaml was created: ${pubspecPath}.bak');
          print('Run `dart pub get` to update your project.');
        } else {
          print('\nRemoval cancelled.');
        }
      } else {
        print('\nRun with --remove to remove these packages from pubspec.yaml.');
      }
    }
  } catch (e) {
    print('\nAn error occurred: $e');
    exit(1);
  }
}
