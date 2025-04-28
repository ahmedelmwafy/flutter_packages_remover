import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Finds unused packages in the 'dependencies' section of pubspec.yaml.
///
/// Analyzes Dart files in the project to determine which packages are actually
/// imported and used.
Future<List<String>> findUnusedPackages(String projectPath) async {
  final pubspecPath = p.join(projectPath, 'pubspec.yaml');
  final pubspecFile = File(pubspecPath);
  if (!pubspecFile.existsSync()) {
    throw FileSystemException('pubspec.yaml not found', pubspecPath);
  }

  final pubspecContent = await pubspecFile.readAsString();
  final pubspecYaml = loadYaml(pubspecContent);

  // Get the list of declared dependencies
  final declaredDependencies = <String>{};
  final dependencies = pubspecYaml['dependencies'];
  if (dependencies is YamlMap) {
    declaredDependencies.addAll(dependencies.keys.cast<String>());
  }

  if (declaredDependencies.isEmpty) {
    print('No dependencies found in pubspec.yaml.');
    return [];
  }

  // Find all Dart files in the project (lib, bin, test, etc.)
  final dartFilePaths = <String>[];
  final directoriesToScan = ['lib', 'bin', 'test', 'example', 'web']
      .map((dir) => p.join(projectPath, dir))
      .where((dir) => Directory(dir).existsSync());

  for (final dirPath in directoriesToScan) {
    final directory = Directory(dirPath);
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        dartFilePaths.add(entity.path);
      }
    }
  }

  if (dartFilePaths.isEmpty) {
    print('No Dart files found in the project directories to analyze.');
    return declaredDependencies.toList(); // Assume all are unused if no code
  }

  // Convert relative paths to absolute and normalized paths for the analyzer
  final absoluteDartFilePaths = dartFilePaths.map((path) => p.normalize(p.absolute(path))).toList();


  // Analyze Dart files to find used imports
  // Use the absolute and normalized paths for the AnalysisContextCollection
  final collection = AnalysisContextCollection(includedPaths: absoluteDartFilePaths);

  // Initialize usedPackages here within the function scope
  final usedPackages = <String>{};

  for (final context in collection.contexts) {
    for (final filePath in context.contextRoot.includedPaths) {
      final result = await context.currentSession.getResolvedUnit(filePath);
      if (result is ResolvedUnitResult && result.errors.isEmpty) {
        // Traverse the AST to find import directives
        result.unit.directives.forEach((directive) {
          if (directive is ImportDirective) {
            final uri = directive.uri.stringValue;
            if (uri != null && uri.startsWith('package:')) {
              // Extract package name from 'package:package_name/...'
              final parts = uri.substring('package:'.length).split('/');
              if (parts.isNotEmpty) {
                usedPackages.add(parts.first);
              }
            }
          }
        });
      }
    }
  }

  // Find which declared dependencies are NOT in the used imports
  final unusedPackages = declaredDependencies.difference(usedPackages).toList();

  // Filter out 'flutter' if it's a Flutter project, as it's implicitly used
  // This is a heuristic, a more robust check might be needed for edge cases.
  if (pubspecYaml['dependencies'] is YamlMap && pubspecYaml['dependencies']['flutter'] != null) {
      unusedPackages.remove('flutter');
  }


  return unusedPackages;
}

/// Removes the specified packages from the 'dependencies' section of pubspec.yaml.
///
/// Creates a backup of the original pubspec.yaml before modifying.
Future<void> removePackages(String pubspecPath, List<String> packagesToRemove) async {
  final pubspecFile = File(pubspecPath);
  final pubspecContent = await pubspecFile.readAsString();

  // Create a backup
  await pubspecFile.copy('$pubspecPath.bak');

  try {
    final editor = YamlEditor(pubspecContent);

    // Remove each package individually instead of replacing the entire dependencies section
    for (final package in packagesToRemove) {
      try {
        editor.remove(['dependencies', package]);
        print('Removed package: $package');
      } catch (e) {
        print('Could not remove package $package: ${e.toString()}');
      }
    }

    // Write the modified content back to pubspec.yaml
    await pubspecFile.writeAsString(editor.toString());
    print('Successfully updated pubspec.yaml');
  } catch (e) {
    // If there was an error, restore the backup
    final backupFile = File('$pubspecPath.bak');
    if (await backupFile.exists()) {
      await backupFile.copy(pubspecPath);
      print('Error occurred: ${e.toString()}');
      print('Restored pubspec.yaml from backup');
    }
    rethrow;
  }
}