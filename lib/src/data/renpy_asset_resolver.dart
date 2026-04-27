import 'dart:io';

import 'package:path/path.dart' as p;

class RenpyAssetResolver {
  RenpyAssetResolver._(this.imagesRoot);

  final String? imagesRoot;

  factory RenpyAssetResolver.auto() {
    final cwd = Directory.current.path;
    final candidates = <String>{
      p.normalize(p.join(cwd, 'Tese', 'game', 'images')),
      p.normalize(p.join(cwd, '..', 'Tese', 'game', 'images')),
      p.normalize(p.join(cwd, '..', '..', 'Tese', 'game', 'images')),
      p.normalize(p.join(cwd, '..', '..', '..', 'Tese', 'game', 'images')),
      p.normalize(p.join(cwd, 'game', 'images')),
    };

    for (final candidate in candidates) {
      if (Directory(candidate).existsSync()) {
        return RenpyAssetResolver._(candidate);
      }
    }

    return RenpyAssetResolver._(null);
  }

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
