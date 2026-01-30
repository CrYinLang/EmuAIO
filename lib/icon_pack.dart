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
  bool isLoadingIconPack = false;

  Future<void> _selectAndLoadIconPack() async {
    if (!mounted) return;

    setState(() => isLoadingIconPack = true);
    final isStillMounted = mounted;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        allowMultiple: false,
      );

      if (!isStillMounted) return;

      if (result?.files.single.path case final path?) {
        await _loadIconPack(File(path));
      } else {
        setState(() => isLoadingIconPack = false);
      }
    } catch (e) {
      if (!isStillMounted) return;
      _showErrorDialog('加载图标包失败: $e');
      setState(() => isLoadingIconPack = false);
    }
  }

  Future<void> _loadIconPack(File zipFile) async {
    if (!mounted) return;

    setState(() => isLoadingIconPack = true);

    try {
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String iconPackDir = '${appDocDir.path}/icon_packs/${DateTime
          .now()
          .millisecondsSinceEpoch}';
      final Directory iconPackDirectory = Directory(iconPackDir);

      if (!await iconPackDirectory.exists()) {
        await iconPackDirectory.create(recursive: true);
      }

      Map<String, String> manifest = {};
      Map<String, dynamic> metadata = {};
      bool hasManifest = false;
      bool hasTrainFolder = false;
      int totalFiles = 0;
      List<String> pngFiles = [];

      for (final file in archive) {
        final filename = file.name;

        if (filename.isEmpty || filename.endsWith('/')) {
          continue;
        }

        final lowerName = filename.toLowerCase();

        // manifest.json
        if (lowerName == 'manifest.json') {
          try {
            String manifestStr;
            try {
              manifestStr = utf8.decode(file.content, allowMalformed: false);
            } catch (_) {
              manifestStr = latin1.decode(file.content, allowInvalid: false);
            }

            final dynamic parsedJson = json.decode(manifestStr);
            if (parsedJson is! Map<String, dynamic>) {
              throw Exception('manifest.json 不是有效对象');
            }

            final manifestJson = parsedJson;

            metadata['name'] = _safeExtractStringValue(manifestJson['name']);

            final describeValue = manifestJson['describe'] ??
                manifestJson['description'];
            metadata['describe'] = _safeExtractStringValue(describeValue);

            metadata['author'] =
                _safeExtractStringValue(manifestJson['author']);

            final Map<String, String> iconMap = {};
            int iconCount = 0;

            for (final entry in manifestJson.entries) {
              final key = entry.key;
              if (!['name', 'describe', 'description', 'author'].contains(
                  key)) {
                final value = _safeExtractStringValue(entry.value);
                if (value.isNotEmpty) {
                  iconMap[key] = value;
                  iconCount++;
                }
              }
            }

            manifest = iconMap;
            metadata['iconCount'] = iconCount;
            hasManifest = true;
          } catch (e) {
            throw Exception('解析 manifest.json 失败: $e');
          }
        }

        // icon.png（封面）
        else if (lowerName == 'icon.png') {
          final outputFile = File('$iconPackDir/icon.png');

          if (!await outputFile.parent.exists()) {
            await outputFile.parent.create(recursive: true);
          }

          if (file.isFile) {
            await outputFile.writeAsBytes(file.content);
          }
        }

        // train/ 资源
        else if (lowerName.startsWith('train/')) {
          hasTrainFolder = true;

          if (lowerName.endsWith('.png')) {
            pngFiles.add(filename);
          }

          final outputFile = File('$iconPackDir/$filename');

          if (!await outputFile.parent.exists()) {
            await outputFile.parent.create(recursive: true);
          }

          if (file.isFile) {
            await outputFile.writeAsBytes(file.content);
            totalFiles++;
          }
        }
      }

      if (!hasTrainFolder) {
        throw Exception('ZIP文件中未找到 train 文件夹');
      }

      if (pngFiles.isEmpty) {
        throw Exception('train 文件夹中未找到 PNG 图标文件');
      }

      if (!hasManifest) {
        manifest = await _generateManifestFromFiles(iconPackDirectory);
        metadata['name'] = '自定义图标包';
        metadata['describe'] = '从ZIP文件自动生成';
        metadata['author'] = '用户上传';
        metadata['iconCount'] = manifest.length;
      } else {
        metadata['name'] = (metadata['name']
            ?.toString()
            .trim()
            .isNotEmpty == true)
            ? metadata['name']
            : '未命名图标包';

        metadata['describe'] ??= '';
        metadata['author'] ??= '未知作者';
        metadata['iconCount'] ??= manifest.length;
      }

      String packName = metadata['name']?.toString().trim() ?? '未命名图标包';
      if (packName.isEmpty) {
        final zipFileName = zipFile.uri.pathSegments.last.replaceAll(
            '.zip', '');
        packName = zipFileName.isNotEmpty
            ? _ensureUtf8String(zipFileName)
            : '自定义图标包_${DateTime
            .now()
            .millisecondsSinceEpoch}';
      }

      metadata['loadTime'] = DateTime.now().toIso8601String();
      metadata['path'] = iconPackDir;
      metadata['totalFiles'] = totalFiles;
      metadata['pngFiles'] = pngFiles.length;
      metadata['zipFile'] = zipFile.uri.pathSegments.last;

      final bool hasValidIcons = await _validateIconPack(iconPackDirectory);
      if (!hasValidIcons) {
        throw Exception('图标包中未找到有效的PNG图标文件');
      }

      if (!mounted) return;

      final settings = Provider.of<AppSettings>(context, listen: false);

      await settings.addIconPack(
        name: packName,
        path: iconPackDir,
        manifest: manifest,
        metadata: metadata,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('图标包 "$packName" 已成功导入并应用'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showErrorDialog('加载图标包失败: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => isLoadingIconPack = false);
      }
    }
  }

  String _safeExtractStringValue(dynamic value) {
    try {
      if (value == null) return '';
      final str = value.toString().trim();
      if (str.isEmpty) return '';
      return _ensureUtf8String(str);
    } catch (e) {
      return '';
    }
  }

  String _ensureUtf8String(String input) {
    try {
      if (input.isEmpty) return input;
      final bytes = utf8.encode(input);
      return utf8.decode(bytes, allowMalformed: false);
    } catch (e) {
      return input.replaceAll(RegExp(r'[^\x00-\x7F\u4e00-\u9fff]'), '');
    }
  }

  Future<bool> _validateIconPack(Directory iconPackDir) async {
    try {
      final trainDir = Directory('${iconPackDir.path}/train');
      if (!await trainDir.exists()) {
        return false;
      }

      final files = await trainDir.list().toList();
      int pngCount = 0;

      for (final file in files) {
        if (file is File && file.path.toLowerCase().endsWith('.png')) {
          pngCount++;
        }
      }

      return pngCount > 0;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, String>> _generateManifestFromFiles(
      Directory iconPackDir) async {
    final Map<String, String> manifest = {};
    final trainDir = Directory('${iconPackDir.path}/train');

    if (await trainDir.exists()) {
      final files = await trainDir.list().toList();
      for (final file in files) {
        if (file is File && file.path.toLowerCase().endsWith('.png')) {
          final fileName = file.uri.pathSegments.last
              .replaceAll('.png', '')
              .replaceAll('.PNG', '');
          if (fileName.isNotEmpty) {
            manifest[fileName] = fileName;
          }
        }
      }
    }
    return manifest;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 64,
            color: Theme
                .of(context)
                .colorScheme
                .onSurface
                .withAlpha(76),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无图标包',
            style: TextStyle(
              fontSize: 16,
              color: Theme
                  .of(context)
                  .colorScheme
                  .onSurface
                  .withAlpha(128),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮导入图标包',
            style: TextStyle(
              fontSize: 12,
              color: Theme
                  .of(context)
                  .colorScheme
                  .onSurface
                  .withAlpha(102),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackIcon(IconPackInfo pack) {
    if (pack.isDefault) {
      // 系统默认图标包 - 使用本地assets/icon/train/CR400AF-SZE.png
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Theme
              .of(context)
              .colorScheme
              .primary
              .withAlpha(25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme
                .of(context)
                .colorScheme
                .primary
                .withAlpha(76),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: pack.isDefault
              ? Image.asset(
            'assets/icon/train/CR400AF-SZE.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildFallbackPackIcon();
            },
          )
              : (() {
            final iconFile = File('${pack.path}/icon.png');
            final bool iconExists = iconFile.existsSync();

            if (iconExists) {
              try {
                final fileStat = iconFile.statSync();
                if (fileStat.size == 0) {
                  return _buildFallbackPackIcon();
                }
                return Image.file(
                  iconFile,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildFallbackPackIcon();
                  },
                );
              } catch (e) {
                return _buildFallbackPackIcon();
              }
            }
            return _buildFallbackPackIcon();
          })(),
        ),
      );
    }

    // 非默认图标包 - 保持原有逻辑
    final iconFile = File('${pack.path}/icon.png');
    final bool iconExists = iconFile.existsSync();

    if (iconExists) {
      try {
        final fileStat = iconFile.statSync();

        if (fileStat.size == 0) {
          return _buildFallbackPackIcon();
        }

        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme
                .of(context)
                .colorScheme
                .primary
                .withAlpha(25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme
                  .of(context)
                  .colorScheme
                  .primary
                  .withAlpha(76),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(
              iconFile,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildFallbackPackIcon();
              },
            ),
          ),
        );
      } catch (e) {
        return _buildFallbackPackIcon();
      }
    }

    return _buildFallbackPackIcon();
  }

  Widget _buildFallbackPackIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Theme
            .of(context)
            .colorScheme
            .primary
            .withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.photo_filter,
        color: Theme
            .of(context)
            .colorScheme
            .primary,
        size: 24,
      ),
    );
  }

  Future<void> _switchToIconPack(IconPackInfo pack, AppSettings settings,
      BuildContext context) async {
    if (settings.currentIconPack == pack.name) {
      return;
    }

    try {
      if (pack.isDefault) {
        await settings.resetToDefaultIcons();
      } else {
        await settings.switchIconPack(pack.name);
      }

      if (context.mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '已切换到 ${pack.metadata['name'] ?? pack.displayName}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorDialog('切换图标包失败: $e');
      }
    }
  }

  Widget _buildIconPackItem(IconPackInfo pack, bool isCurrent,
      AppSettings settings, BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isCurrent
          ? Theme
          .of(context)
          .colorScheme
          .primary
          .withAlpha(25)
          : Theme
          .of(context)
          .colorScheme
          .surface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCurrent
              ? Theme
              .of(context)
              .colorScheme
              .primary
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await _switchToIconPack(pack, settings, context);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildPackIcon(pack),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 名称和状态标签
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            pack.metadata['name']?.toString() ?? pack
                                .displayName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme
                                  .of(context)
                                  .colorScheme
                                  .onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme
                                  .of(context)
                                  .colorScheme
                                  .primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '使用中',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // 描述信息
                    if (pack.metadata['describe'] != null &&
                        pack.metadata['describe']
                            .toString()
                            .isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          pack.metadata['describe'].toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme
                                .of(context)
                                .colorScheme
                                .onSurface
                                .withAlpha(179),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                    const SizedBox(height: 6),

                    // 作者和图标数量信息
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (pack.metadata['author'] != null &&
                            pack.metadata['author']
                                .toString()
                                .isNotEmpty)
                          Text(
                            '作者: ${pack.metadata['author']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme
                                  .of(context)
                                  .colorScheme
                                  .onSurface
                                  .withAlpha(128),
                            ),
                          ),

                        if (pack.iconCount > 0)
                          Text(
                            '${pack.iconCount} 个图标',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme
                                  .of(context)
                                  .colorScheme
                                  .onSurface
                                  .withAlpha(128),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              if (!pack.isDefault)
                IconButton(
                  onPressed: () async {
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (context) =>
                          AlertDialog(
                            title: const Text('确认删除'),
                            content: Text(
                                '确定要删除图标包 "${pack.metadata['name'] ??
                                    pack.displayName}" 吗？此操作不可恢复。'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('取消'),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text('删除'),
                              ),
                            ],
                          ),
                    );

                    if (result == true) {
                      try {
                        await settings.deleteIconPack(pack.name);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('图标包 "${pack.metadata['name'] ??
                                  pack.displayName}" 已删除'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        _showErrorDialog('删除图标包失败: $e');
                      }
                    }
                  },
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  tooltip: '删除此图标包',
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('错误'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: const [
                Icon(Icons.photo_library, size: 24),
                SizedBox(width: 8),
                Text(
                  '图标包管理',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
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
                  final isCurrent =
                      settings.currentIconPack == pack.name;
                  return _buildIconPackItem(
                      pack, isCurrent, settings, context);
                },
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('关闭'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                    isLoadingIconPack ? null : _selectAndLoadIconPack,
                    icon: isLoadingIconPack
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child:
                      CircularProgressIndicator(strokeWidth: 2),
                    )
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