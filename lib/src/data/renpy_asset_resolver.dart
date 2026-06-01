import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_preferences.dart';

class RenpyAssetResolver {
  RenpyAssetResolver._(this.imagesRoot);

  final String? imagesRoot;

  factory RenpyAssetResolver.auto() {
    // User-configured root takes priority.
    final saved = AppPreferences.assetsRoot;
    if (saved.isNotEmpty && Directory(saved).existsSync()) {
      return RenpyAssetResolver._(saved);
    }

    final cwd = Directory.current.path;
    // Look for tese_assets folder relative to the app executable/cwd
    final candidates = <String>[
      p.normalize(p.join(cwd, 'tese_assets')),
      p.normalize(p.join(cwd, '..', 'tese_assets')),
      p.normalize(p.join(cwd, '..', '..', 'tese_assets')),
    ];

    for (final candidate in candidates) {
      if (Directory(candidate).existsSync() &&
          Directory(p.join(candidate, 'areas')).existsSync()) {
        return RenpyAssetResolver._(candidate);
      }
    }

    return RenpyAssetResolver._(null);
  }

  /// Default candidate path shown in settings as a suggestion.
  static String defaultCandidate() {
    final cwd = Directory.current.path;
    return p.normalize(p.join(cwd, '..', 'tese_assets'));
  }

  /// Create a resolver pointing at [root] directly (used after user picks a folder).
  factory RenpyAssetResolver.withRoot(String root) =>
      RenpyAssetResolver._(root.isEmpty ? null : root);

  String resolve(String renpyPath) {
    if (renpyPath.isEmpty) {
      return renpyPath;
    }

    if (p.isAbsolute(renpyPath)) {
      return renpyPath;
    }

    if (imagesRoot == null) {
      return renpyPath;
    }

    final normalized = renpyPath.replaceAll('\\', '/');
    return p.normalize(p.join(imagesRoot!, normalized));
  }

  bool exists(String renpyPath) {
    final resolved = resolve(renpyPath);
    return File(resolved).existsSync();
  }
}
