import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_packages_remover/flutter_packages_remover.dart'; // Corrected import path

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('list',
        abbr: 'l',
        negatable: false,
        help: 'List unused packages without removing them (default).')
    ..addFlag('remove',
        abbr: 'r',
        negatable: false,
        help: 'Enable interactive removal of unused packages from pubspec.yaml.')
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
    print('Usage: dart run flutter_packages_remover [options] [<project_path>]'); // Corrected usage string
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
    final unusedPackages = await findUnusedPackages(projectPath);

    if (unusedPackages.isEmpty) {
      print('\nNo unused packages found in dependencies.');
    } else {
      print('\nUnused packages in dependencies:');
      // List packages with numbers for selection
      for (int i = 0; i < unusedPackages.length; i++) {
        print('${i + 1}. ${unusedPackages[i]}');
      }

      if (remove) {
        // --- Modified Logic for Selecting Packages to Keep ---
        print('\nEnter the numbers of packages to KEEP, separated by commas or spaces.');
        print('Enter "none" to remove all listed packages, or "cancel" to abort.');
        stdout.write('Packages to keep: ');

        final input = stdin.readLineSync()?.trim().toLowerCase();
        List<String> packagesToKeep = [];
        List<String> packagesToRemove = List.from(unusedPackages); // Start with all unused

        if (input == 'cancel') {
          print('\nRemoval cancelled.');
          exit(0);
        } else if (input == 'none') {
          // packagesToRemove already contains all unusedPackages
          print('No packages selected to keep. All listed unused packages will be removed.');
        } else {
          // Parse selected numbers for packages to KEEP
          final selectedIndicesToKeep = input
              ?.split(RegExp(r'[,\s]+')) // Split by commas or spaces
              .where((s) => s.isNotEmpty)
              .map((s) => int.tryParse(s))
              .where((n) => n != null && n! > 0 && n! <= unusedPackages.length)
              .map((n) => n! - 1) // Convert to 0-based index
              .toSet(); // Use a Set to handle duplicates

          if (selectedIndicesToKeep != null && selectedIndicesToKeep.isNotEmpty) {
            packagesToKeep = selectedIndicesToKeep.map((index) => unusedPackages[index]).toList();
            // Remove packagesToKeep from the packagesToRemove list
            packagesToRemove.removeWhere((package) => packagesToKeep.contains(package));

            print('\nSelected packages to keep:');
            for (final package in packagesToKeep) {
              print('- $package');
            }

          } else if (input != null && input.isNotEmpty) {
             print('Invalid input. Please enter valid numbers from the list, "none", or "cancel".');
             exit(1);
          } else {
             print('No valid packages selected to keep. All listed unused packages will be removed.');
          }
        }
        // --- End Modified Logic ---


        if (packagesToRemove.isNotEmpty) {
           print('\nPackages that will be removed:');
           for (final package in packagesToRemove) {
             print('- $package');
           }
           stdout.write('\nConfirm removal of these ${packagesToRemove.length} packages? (y/N): ');
           final confirmation = stdin.readLineSync()?.trim().toLowerCase();

           if (confirmation == 'y') {
             await removePackages(pubspecPath, packagesToRemove);
             print('\nSuccessfully removed ${packagesToRemove.length} packages from pubspec.yaml.');
             print('A backup of the original pubspec.yaml was created: ${pubspecPath}.bak');
             print('Run `dart pub get` to update your project.');
           } else {
             print('\nRemoval cancelled.');
           }
        } else {
           print('\nNo packages will be removed based on your selection.');
           exit(0);
        }

      } else {
        print('\nRun with --remove to enable interactive removal of these packages from pubspec.yaml.');
      }
    }
  } catch (e) {
    print('\nAn error occurred: $e');
    exit(1);
  }
}
