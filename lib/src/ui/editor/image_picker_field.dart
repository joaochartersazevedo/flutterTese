import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../data/renpy_asset_resolver.dart';
import '../app_theme.dart';

const _imageExts = {'.jpg', '.jpeg', '.png', '.webp', '.bmp'};
bool _isImage(String name) => _imageExts.contains(p.extension(name).toLowerCase());

// ---------- Public widget ----------

class ImagePickerField extends StatefulWidget {
  const ImagePickerField({
    super.key,
    required this.label,
    required this.subdirectory,
    this.initialPath = '',
    required this.onChanged,
  });

  final String label;

  /// Relative path inside imagesRoot, e.g. 'editor/portraits' or 'editor/bodies'.
  /// Only top-level image files in this directory are shown (no recursion).
  final String subdirectory;

  final String initialPath;
  final void Function(String path) onChanged;

  @override
  State<ImagePickerField> createState() => _ImagePickerFieldState();
}

class _ImagePickerFieldState extends State<ImagePickerField> {
  late String _path;
  final _resolver = RenpyAssetResolver.auto();

  @override
  void initState() {
    super.initState();
    _path = widget.initialPath;
  }

  Future<void> _browse() async {
    final root = _resolver.imagesRoot;
    if (root == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pasta de imagens Renpy nao encontrada.')),
      );
      return;
    }
    final scanDir = p.normalize(p.join(root, widget.subdirectory));
    if (!Directory(scanDir).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pasta nao encontrada: ${widget.subdirectory}')),
      );
      return;
    }
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => _FlatImagePickerDialog(
        title: widget.label,
        scanDir: scanDir,
        imagesRoot: root,
        initialPath: _path,
      ),
    );
    if (picked == null) return;
    setState(() => _path = picked);
    widget.onChanged(picked);
  }

  void _clear() {
    setState(() => _path = '');
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final absPath = _resolver.resolve(_path);
    final fileExists = _path.isNotEmpty && File(absPath).existsSync();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.label,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const Spacer(),
            if (_path.isNotEmpty)
              TextButton(
                onPressed: _clear,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Limpar', style: TextStyle(fontSize: 11)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed-size thumbnail — never stretches full width
            InkWell(
              onTap: _browse,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 160,
                height: 110,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHighlight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: fileExists ? AppColors.primary : AppColors.border,
                    width: fileExists ? 1.5 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: fileExists
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(File(absPath), fit: BoxFit.cover),
                          Positioned(
                            top: 4, right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(Icons.edit_outlined, size: 12, color: Colors.white),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _path.isNotEmpty
                                ? Icons.broken_image_outlined
                                : Icons.add_photo_alternate_outlined,
                            size: 28,
                            color: _path.isNotEmpty ? AppColors.error : AppColors.textMuted,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Escolher',
                            style: TextStyle(
                              color: _path.isNotEmpty ? AppColors.error : AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Info column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (fileExists) ...[
                    Text(
                      p.basename(_path),
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _path,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _browse,
                          icon: const Icon(Icons.swap_horiz, size: 14),
                          label: const Text('Trocar', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _clear,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Remover',
                              style: TextStyle(fontSize: 12, color: AppColors.error)),
                        ),
                      ],
                    ),
                  ] else ...[
                    Text(
                      _path.isNotEmpty ? 'Ficheiro nao encontrado' : 'Sem imagem selecionada',
                      style: TextStyle(
                        color: _path.isNotEmpty ? AppColors.error : AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _browse,
                      icon: const Icon(Icons.photo_library_outlined, size: 14),
                      label: const Text('Escolher imagem', style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------- Flat grid dialog ----------

class _FlatImagePickerDialog extends StatefulWidget {
  const _FlatImagePickerDialog({
    required this.title,
    required this.scanDir,
    required this.imagesRoot,
    this.initialPath,
  });

  final String title;
  final String scanDir;
  final String imagesRoot;
  final String? initialPath;

  @override
  State<_FlatImagePickerDialog> createState() => _FlatImagePickerDialogState();
}

class _FlatImagePickerDialogState extends State<_FlatImagePickerDialog> {
  String? _selected;
  late final List<File> _images;

  @override
  void initState() {
    super.initState();
    _images = _loadImages();

    // Resolve initial selection to absolute path
    final ip = widget.initialPath;
    if (ip != null && ip.isNotEmpty) {
      final abs = p.isAbsolute(ip)
          ? ip
          : p.normalize(p.join(widget.imagesRoot, ip));
      if (_images.any((f) => f.path == abs)) _selected = abs;
    }
  }

  List<File> _loadImages() {
    try {
      return Directory(widget.scanDir)
          .listSync()
          .whereType<File>()
          .where((f) => _isImage(p.basename(f.path)))
          .toList()
        ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    } catch (_) {
      return [];
    }
  }

  String _relPath(String absPath) => p.relative(absPath, from: widget.imagesRoot);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(40),
      child: SizedBox(
        width: 680,
        height: 500,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.photo_library_outlined, size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(widget.title,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('${_images.length} imagens',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            // Grid
            Expanded(
              child: _images.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.image_not_supported_outlined,
                              size: 48, color: AppColors.textMuted),
                          SizedBox(height: 12),
                          Text('Sem imagens nesta pasta',
                              style: TextStyle(color: AppColors.textMuted)),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 140,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: _images.length,
                      itemBuilder: (context, index) {
                        final file = _images[index];
                        final isSelected = _selected == file.path;
                        return _ImageTile(
                          file: file,
                          selected: isSelected,
                          onTap: () => setState(() => _selected = file.path),
                          onDoubleTap: () =>
                              Navigator.pop(context, _relPath(file.path)),
                        );
                      },
                    ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _selected != null
                        ? Text(
                            _relPath(_selected!),
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          )
                        : const Text('Nenhuma imagem selecionada',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _selected != null
                        ? () => Navigator.pop(context, _relPath(_selected!))
                        : null,
                    child: const Text('Escolher'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Image tile ----------

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.file,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
  });

  final File file;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 8)]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(file, fit: BoxFit.cover),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  p.basename(file.path),
                  style: const TextStyle(color: Colors.white, fontSize: 9),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            if (selected)
              Positioned(
                top: 4, right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 10, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
