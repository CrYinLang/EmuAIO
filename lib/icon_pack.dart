//icon_pack.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'main.dart';

class IconPackManager extends StatefulWidget {
  const IconPackManager({super.key});

  @override
  State<IconPackManager> createState() => _IconPackManagerState();
}

class _IconPackManagerState extends State<IconPackManager> {
  bool isLoading = false;

  Future<void> _selectAndLoadIconPack() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        allowMultiple: false,
      );

      if (mounted) {
        if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
          await _loadIconPack(File(result.files.single.path!));
        } else {
          setState(() => isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('加载图标包失败: $e');
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _loadIconPack(File zipFile) async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());
      final iconPackDir = await _createIconPackDirectory();

      final result = await _processArchive(archive, iconPackDir, zipFile);
      await _validateAndSaveIconPack(result.$1, result.$2, iconPackDir, zipFile);
    } catch (e) {
      _showError('加载图标包失败: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<Directory> _createIconPackDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final iconPackDir = Directory('${appDocDir.path}/icon_packs/${DateTime.now().millisecondsSinceEpoch}');
    if (!await iconPackDir.exists()) await iconPackDir.create(recursive: true);
    return iconPackDir;
  }

  Future<(Map<String, String>, Map<String, dynamic>)> _processArchive(
      Archive archive,
      Directory iconPackDir,
      File zipFile
      ) async {
    Map<String, String> manifest = {};
    Map<String, dynamic> metadata = {};
    bool hasTrainFolder = false;
    List<String> pngFiles = [];

    for (final file in archive) {
      if (file.name.isEmpty || file.name.endsWith('/')) continue;
      final lowerName = file.name.toLowerCase();

      if (lowerName == 'manifest.json') {
        final result = await _parseManifest(file);
        manifest = result.$1;
        metadata.addAll(result.$2);
      } else if (lowerName == 'icon.png') {
        await _saveArchiveFile(file, iconPackDir);
      } else if (lowerName.startsWith('train/')) {
        hasTrainFolder = true;
        if (lowerName.endsWith('.png')) pngFiles.add(file.name);
        await _saveArchiveFile(file, iconPackDir);
      }
    }

    if (!hasTrainFolder) throw Exception('ZIP文件中未找到 train 文件夹');
    if (pngFiles.isEmpty) throw Exception('train 文件夹中未找到 PNG 图标文件');

    if (manifest.isEmpty) {
      manifest = await _generateManifestFromFiles(iconPackDir);
      metadata['name'] = '自定义图标包';
      metadata['describe'] = '从ZIP文件自动生成';
      metadata['author'] = '用户上传';
    }

    metadata['iconCount'] = manifest.length;
    metadata['name'] = (metadata['name']?.toString().trim().isNotEmpty == true)
        ? metadata['name']
        : '未命名图标包';
    metadata['describe'] ??= '';
    metadata['author'] ??= '未知作者';

    return (manifest, metadata);
  }

  Future<(Map<String, String>, Map<String, dynamic>)> _parseManifest(ArchiveFile file) async {
    try {
      String manifestStr = utf8.decode(file.content, allowMalformed: false);
      final manifestJson = json.decode(manifestStr) as Map<String, dynamic>;

      final metadata = <String, dynamic>{
        'name': _safeExtractString(manifestJson['name']),
        'describe': _safeExtractString(manifestJson['describe'] ?? manifestJson['description']),
        'author': _safeExtractString(manifestJson['author']),
      };

      final manifest = <String, String>{};
      for (final entry in manifestJson.entries) {
        final key = entry.key;
        if (!['name', 'describe', 'description', 'author'].contains(key)) {
          final value = _safeExtractString(entry.value);
          if (value.isNotEmpty) manifest[key] = value;
        }
      }

      return (manifest, metadata);
    } catch (e) {
      throw Exception('解析 manifest.json 失败: $e');
    }
  }

  String _safeExtractString(dynamic value) {
    if (value == null) return '';
    final str = value.toString().trim();
    if (str.isEmpty) return '';

    try {
      final bytes = utf8.encode(str);
      return utf8.decode(bytes, allowMalformed: false);
    } catch (e) {
      return str.replaceAll(RegExp(r'[^\x00-\x7F\u4e00-\u9fff]'), '');
    }
  }

  Future<void> _saveArchiveFile(ArchiveFile file, Directory iconPackDir) async {
    final outputFile = File('${iconPackDir.path}/${file.name}');
    if (!await outputFile.parent.exists()) {
      await outputFile.parent.create(recursive: true);
    }
    if (file.isFile) await outputFile.writeAsBytes(file.content);
  }

  Future<Map<String, String>> _generateManifestFromFiles(Directory iconPackDir) async {
    final manifest = <String, String>{};
    final trainDir = Directory('${iconPackDir.path}/train');

    if (await trainDir.exists()) {
      await for (final file in trainDir.list()) {
        if (file is File && file.path.toLowerCase().endsWith('.png')) {
          final fileName = file.uri.pathSegments.last.replaceAll(RegExp(r'\.png$', caseSensitive: false), '');
          if (fileName.isNotEmpty) manifest[fileName] = fileName;
        }
      }
    }
    return manifest;
  }

  Future<void> _validateAndSaveIconPack(
      Map<String, String> manifest,
      Map<String, dynamic> metadata,
      Directory iconPackDir,
      File zipFile
      ) async {
    final trainDir = Directory('${iconPackDir.path}/train');
    if (!await trainDir.exists()) throw Exception('图标包中未找到有效的PNG图标文件');

    int pngCount = 0;
    await for (final file in trainDir.list()) {
      if (file is File && file.path.toLowerCase().endsWith('.png')) {
        pngCount++;
      }
    }

    if (pngCount == 0) throw Exception('图标包中未找到有效的PNG图标文件');

    String packName = metadata['name']?.toString().trim() ?? '未命名图标包';
    if (packName.isEmpty) {
      final zipFileName = zipFile.uri.pathSegments.last.replaceAll('.zip', '');
      packName = zipFileName.isNotEmpty ? _safeExtractString(zipFileName) : '自定义图标包_${DateTime.now().millisecondsSinceEpoch}';
    }

    metadata.addAll({
      'loadTime': DateTime.now().toIso8601String(),
      'path': iconPackDir.path,
      'zipFile': zipFile.uri.pathSegments.last,
    });

    if (!mounted) return;

    final settings = Provider.of<AppSettings>(context, listen: false);
    await settings.addIconPack(
      name: packName,
      path: iconPackDir.path,
      manifest: manifest,
      metadata: metadata,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('图标包 "$packName" 已成功导入并应用'), duration: const Duration(seconds: 2)),
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(76),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无图标包',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮导入图标包',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(102),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackIcon(IconPackInfo pack) {
    Widget iconContent = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withAlpha(76),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: _buildIconImage(pack),
      ),
    );

    return iconContent;
  }

  Widget _buildIconImage(IconPackInfo pack) {
    if (pack.isDefault) {
      return Image.asset(
        'assets/icon/app_icon.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(),
      );
    }

    final iconFile = File('${pack.path}/icon.png');
    if (!iconFile.existsSync()) return _buildFallbackIcon();

    try {
      if (iconFile.statSync().size == 0) return _buildFallbackIcon();
      return Image.file(
        iconFile,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(),
      );
    } catch (e) {
      return _buildFallbackIcon();
    }
  }

  Widget _buildFallbackIcon() {
    return Icon(
      Icons.photo_filter,
      color: Theme.of(context).colorScheme.primary,
      size: 24,
    );
  }

  Future<void> _switchToIconPack(IconPackInfo pack, AppSettings settings) async {
    if (settings.currentIconPack == pack.name) return;

    try {
      if (pack.isDefault) {
        await settings.resetToDefaultIcons();
      } else {
        await settings.switchIconPack(pack.name);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已切换到 ${pack.metadata['name'] ?? pack.displayName}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError('切换图标包失败: $e');
    }
  }

  Widget _buildPackItem(IconPackInfo pack, bool isCurrent, AppSettings settings) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isCurrent
          ? Theme.of(context).colorScheme.primary.withAlpha(25)
          : Theme.of(context).colorScheme.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCurrent ? Theme.of(context).colorScheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _switchToIconPack(pack, settings),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildPackIcon(pack),
              const SizedBox(width: 12),
              Expanded(child: _buildPackInfo(pack, isCurrent)),
              if (!pack.isDefault) _buildDeleteButton(pack, settings),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackInfo(IconPackInfo pack, bool isCurrent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                pack.metadata['name']?.toString() ?? pack.displayName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isCurrent) _buildCurrentBadge(),
          ],
        ),
        if (pack.metadata['describe'] != null && pack.metadata['describe']!.toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              pack.metadata['describe']!.toString(),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        const SizedBox(height: 6),
        _buildPackMetadata(pack),
      ],
    );
  }

  Widget _buildCurrentBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        '使用中',
        style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPackMetadata(IconPackInfo pack) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        if (pack.metadata['author'] != null && pack.metadata['author']!.toString().isNotEmpty)
          Text(
            '作者: ${pack.metadata['author']}',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(128)),
          ),
        if (pack.iconCount > 0)
          Text(
            '${pack.iconCount} 个图标',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(128)),
          ),
      ],
    );
  }

  Widget _buildDeleteButton(IconPackInfo pack, AppSettings settings) {
    return IconButton(
      onPressed: () => _showDeleteDialog(pack, settings),
      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
      tooltip: '删除此图标包',
    );
  }

  Future<void> _showDeleteDialog(IconPackInfo pack, AppSettings settings) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除图标包 "${pack.metadata['name'] ?? pack.displayName}" 吗？此操作不可恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消')
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await settings.deleteIconPack(pack.name);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('图标包 "${pack.metadata['name'] ?? pack.displayName}" 已删除'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) _showError('删除图标包失败: $e');
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('错误'),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('确定')
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      child: Container(
        width: screenWidth * 0.9,
        height: screenHeight * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: const [
                Icon(Icons.photo_library, size: 24),
                SizedBox(width: 8),
                Text('图标包管理', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: settings.availableIconPacks.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                itemCount: settings.availableIconPacks.length,
                itemBuilder: (context, index) {
                  final pack = settings.availableIconPacks[index];
                  return _buildPackItem(pack, settings.currentIconPack == pack.name, settings);
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('关闭')
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : _selectAndLoadIconPack,
                    icon: isLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add, size: 20),
                    label: const Text('导入图标包'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}