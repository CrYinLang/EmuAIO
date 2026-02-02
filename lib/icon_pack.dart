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
  static const Set<String> _systemKeys = {
    'name',
    'describe',
    'description',
    'author',
    'version',
    'uuid',
    '提示',
    '如无特殊',
  };

  bool isLoading = false;

  // 版本比较
  int _compareVersion(String a, String b) {
    List<int> pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    int len = pa.length > pb.length ? pa.length : pb.length;
    while (pa.length < len) {
      pa.add(0);
    }
    while (pb.length < len) {
      pb.add(0);
    }
    for (int i = 0; i < len; i++) {
      if (pa[i] > pb[i]) return 1;
      if (pa[i] < pb[i]) return -1;
    }
    return 0;
  }

  // 选择 ZIP
  Future<void> _selectAndLoadIconPack() async {
    setState(() => isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        allowMultiple: false,
      );
      if (result?.files.single.path != null) {
        await _loadIconPack(File(result!.files.single.path!));
      }
    } catch (e) {
      _showError('加载失败: $e');
    } finally {
      await FilePicker.platform.clearTemporaryFiles();

      if (mounted) setState(() => isLoading = false);
    }
  }

  // ===== 核心安装流程（原子）=====
  Future<void> _loadIconPack(File zipFile) async {
    final archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());

    ArchiveFile? manifestFile;
    for (final f in archive) {
      if (f.name.toLowerCase() == 'manifest.json') manifestFile = f;
    }
    if (manifestFile == null) throw Exception('缺少 manifest.json');

    final parsed = await _parseManifest(manifestFile);
    final uuid = parsed.$2['uuid'];

    final tempDir = await _createTempInstallDir(uuid);
    final result = await _processArchive(archive, tempDir);

    await _validateAndAtomicInstall(result.$1, result.$2, tempDir, zipFile);
  }

  // 临时安装目录
  Future<Directory> _createTempInstallDir(String uuid) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final dir = Directory(
        '${appDocDir.path}/icon_packs/_install_${uuid}_${DateTime.now().millisecondsSinceEpoch}');
    await dir.create(recursive: true);
    return dir;
  }

  Future<void> _validateAndAtomicInstall(
      Map<String, String> manifest,
      Map<String, dynamic> metadata,
      Directory tempDir,
      File zipFile,
      ) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final finalDir = Directory('${appDocDir.path}/icon_packs/${metadata['uuid']}');

    // PNG 校验
    final trainDir = Directory('${tempDir.path}/train');
    if (!await trainDir.exists()) throw Exception('未找到PNG');

    // 版本检测
    if (!mounted) return;
    final settings = Provider.of<AppSettings>(context, listen: false);
    final existing = settings.availableIconPacks
        .where((p) => p.metadata['uuid'] == metadata['uuid'])
        .toList();

    if (existing.isNotEmpty) {
      final old = existing.first;
      int cmp = _compareVersion(metadata['version'], old.metadata['version']);
      bool ok = await _confirmVersionDialog(
          cmp, old.metadata['version'], metadata['version']);
      if (!ok) {
        await tempDir.delete(recursive: true);
        return;
      }
      await settings.deleteIconPack(old.name);
      if (await finalDir.exists()) await finalDir.delete(recursive: true);
    }

    try {
      await tempDir.rename(finalDir.path);
    } catch (e) {
      await tempDir.delete(recursive: true);
      rethrow;
    }

    await settings.addIconPack(
      name: metadata['name'],
      path: finalDir.path,
      manifest: manifest,
      metadata: metadata,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图标包 ${metadata['name']} 已安装')));
    }
  }

  Future<bool> _confirmVersionDialog(int cmp, oldV, newV) async {
    String title, content;
    if (cmp > 0) {
      title = '发现新版本';
      content = '$oldV → $newV 更新?';
    } else if (cmp == 0) {
      title = '重复版本';
      content = '版本相同，覆盖?';
    } else {
      title = '降级警告';
      content = '$oldV > $newV 确认降级?';
    }

    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确定')),
        ],
      ),
    ) ??
        false;
  }

  // 解压处理
  Future<(Map<String, String>, Map<String, dynamic>)> _processArchive(
      Archive archive,
      Directory dir,
      ) async {
    Map<String, String> manifest = {};
    Map<String, dynamic> metadata = {};
    bool hasTrain = false;

    for (final f in archive) {
      if (f.name.endsWith('/')) continue;
      final lower = f.name.toLowerCase();

      if (lower == 'manifest.json') {
        final parsed = await _parseManifest(f);
        manifest = parsed.$1;
        metadata = parsed.$2;
      } else if (lower.startsWith('train/') && lower.endsWith('.png')) {
        hasTrain = true;
        await _saveFile(f, dir);
      } else if (lower == 'icon.png') {
        await _saveFile(f, dir);
      }
    }

    if (!hasTrain) throw Exception('未找到 train PNG');

    metadata['iconCount'] = manifest.length;
    return (manifest, metadata);
  }

  Future<void> _saveFile(ArchiveFile f, Directory dir) async {
    final out = File('${dir.path}/${f.name}');
    await out.parent.create(recursive: true);
    await out.writeAsBytes(f.content);
  }

  Future<(Map<String, String>, Map<String, dynamic>)> _parseManifest(
      ArchiveFile f) async {
    final jsonMap = json.decode(utf8.decode(f.content));
    final meta = {
      'uuid': jsonMap['uuid'],
      'name': jsonMap['name'],
      'author': jsonMap['author'],
      'version': jsonMap['version'],
      'describe': jsonMap['describe'],
    };

    Map<String, String> m = {};
    for (final e in jsonMap.entries) {
      if (!_systemKeys.contains(e.key)) {
        m[e.key] = e.value.toString();
      }
    }
    return (m, meta);
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

    // 尝试 icon.png
    final iconFile = File('${pack.path}/icon.png');
    if (iconFile.existsSync()) {
      try {
        if (iconFile.statSync().size > 0) {
          return Image.file(
            iconFile,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // icon.png 加载失败，尝试 train/CR400AF-SZE.png
              final trainIcon = File('${pack.path}/train/CR400AF-SZE.png');
              if (trainIcon.existsSync()) {
                try {
                  if (trainIcon.statSync().size > 0) {
                    return Image.file(
                      trainIcon,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildFallbackIcon(),
                    );
                  }
                } catch (e) {
                  return _buildFallbackIcon();
                }
              }
              return _buildFallbackIcon();
            },
          );
        }
      } catch (e) {
        // icon.png 有问题，尝试 train/CR400AF-SZE.png
      }
    }

    // 尝试 train/CR400AF-SZE.png
    final trainIcon = File('${pack.path}/train/CR400AF-SZE.png');
    if (trainIcon.existsSync()) {
      try {
        if (trainIcon.statSync().size > 0) {
          return Image.file(
            trainIcon,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(),
          );
        }
      } catch (e) {
        return _buildFallbackIcon();
      }
    }

    return _buildFallbackIcon();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已切换到 ${pack.metadata['name'] ?? pack.displayName}'),
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() {}); // 刷新UI
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
          color: isCurrent
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
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
        if (pack.metadata['describe'] != null &&
            pack.metadata['describe']!.toString().isNotEmpty)
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
        style: TextStyle(
            fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  // 修改 _buildPackMetadata 方法
  Widget _buildPackMetadata(IconPackInfo pack) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 第一行：作者信息
        if (pack.metadata['author'] != null &&
            pack.metadata['author']!.toString().isNotEmpty)
          Text(
            '作者: ${pack.metadata['author']}',
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(128)),
          ),

        // 第二行：版本信息和图标数量
        const SizedBox(height: 4),
        Row(
          children: [
            // 版本信息
            Row(
              children: [
                Text(
                  'v${pack.metadata['version'] ?? '1.0'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),

            // 图标数量
            if (pack.iconCount > 0)
              Row(
                children: [
                  const Icon(Icons.photo_outlined, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    '${pack.iconCount}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
                    ),
                  ),
                ],
              ),
          ],
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

  Future<void> _showDeleteDialog(
      IconPackInfo pack, AppSettings settings) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
            '确定要删除图标包 "${pack.metadata['name'] ?? pack.displayName}" 吗？此操作不可恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消')),
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
              content: Text(
                  '图标包 "${pack.metadata['name'] ?? pack.displayName}" 已删除'),
              duration: const Duration(seconds: 2),
            ),
          );
          setState(() {}); // 刷新UI
        }
      } catch (e) {
        if (mounted) _showError('删除图标包失败: $e');
      }
    }
  }

  void _showError(String m) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (_) =>
            AlertDialog(title: const Text('错误'), content: Text(m)),
      );
    }
  }

  Widget _buildIconPackList(BuildContext context) {
    return Consumer<AppSettings>(
      builder: (context, settings, child) {
        final packs = settings.availableIconPacks;
        final currentPackName = settings.currentIconPack;

        if (packs.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: packs.length,
          itemBuilder: (context, index) {
            final pack = packs[index];
            final isCurrent = currentPackName == pack.name;
            return _buildPackItem(pack, isCurrent, settings);
          },
        );
      },
    );
  }

  Widget _buildImportButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : _selectAndLoadIconPack,
        icon: isLoading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : const Icon(Icons.file_upload_outlined),
        label: Text(isLoading ? '导入中...' : '导入图标包 (ZIP)'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('图标包管理'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          _buildImportButton(),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: _buildIconPackList(context),
          ),
        ],
      ),
    );
  }
}