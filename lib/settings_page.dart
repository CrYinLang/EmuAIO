import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'main.dart';
import 'color_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool isCheckingUpdate = false;
  bool isLoadingIconPack = false;

  Future<Map<String, dynamic>?> _checkForUpdate() async {
    try {
      final response = await http.get(Uri.parse(
          'https://gitee.com/CrYinLang/emu-aio/raw/master/version.txt'
      )).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'error': '网络错误 ${response.statusCode}'};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<void> _selectAndLoadIconPack() async {
    if (!mounted) return;

    setState(() {
      isLoadingIconPack = true;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        await _loadIconPack(File(result.files.single.path!));
      } else {
        if (mounted) {
          setState(() {
            isLoadingIconPack = false;
          });
        }
      }
    } catch (e) {
      _showErrorDialog('加载图标包失败: $e');
      if (mounted) {
        setState(() {
          isLoadingIconPack = false;
        });
      }
    }
  }

  Future<void> _loadIconPack(File zipFile) async {
    if (!mounted) return;

    setState(() {
      isLoadingIconPack = true;
    });

    try {
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String iconPackDir = '${appDocDir.path}/icon_packs/${DateTime.now().millisecondsSinceEpoch}';
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

            final describeValue = manifestJson['describe'] ?? manifestJson['description'];
            metadata['describe'] = _safeExtractStringValue(describeValue);

            metadata['author'] = _safeExtractStringValue(manifestJson['author']);

            final Map<String, String> iconMap = {};
            int iconCount = 0;

            for (final entry in manifestJson.entries) {
              final key = entry.key;
              if (!['name', 'describe', 'description', 'author'].contains(key)) {
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

        else if (lowerName == 'icon.png') {
          final outputFile = File('$iconPackDir/icon.png');

          if (!await outputFile.parent.exists()) {
            await outputFile.parent.create(recursive: true);
          }

          if (file.isFile) {
            await outputFile.writeAsBytes(file.content);
          }
        }

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
        if (!metadata.containsKey('name') || metadata['name'] == null || metadata['name'].toString().isEmpty) {
          metadata['name'] = '未命名图标包';
        }
        if (!metadata.containsKey('describe') || metadata['describe'] == null) {
          metadata['describe'] = '';
        }
        if (!metadata.containsKey('author') || metadata['author'] == null) {
          metadata['author'] = '未知作者';
        }
        if (!metadata.containsKey('iconCount')) {
          metadata['iconCount'] = manifest.length;
        }
      }

      String packName = metadata['name']?.toString().trim() ?? '未命名图标包';
      if (packName.isEmpty) {
        final zipFileName = zipFile.uri.pathSegments.last.replaceAll('.zip', '');
        if (zipFileName.isNotEmpty) {
          packName = _ensureUtf8String(zipFileName);
        } else {
          packName = '自定义图标包_${DateTime.now().millisecondsSinceEpoch}';
        }
      }

      packName = packName.trim();
      if (packName.isEmpty) {
        packName = '未命名图标包';
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

      try {
        await _cleanupFailedFiles();
      } catch (cleanupError) {
        debugPrint('清理失败文件时出错: $cleanupError');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoadingIconPack = false;
        });
      }
    }
  }

  Future<void> _cleanupFailedFiles() async {
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

  Future<Map<String, String>> _generateManifestFromFiles(Directory iconPackDir) async {
    final Map<String, String> manifest = {};
    final trainDir = Directory('${iconPackDir.path}/train');

    if (await trainDir.exists()) {
      final files = await trainDir.list().toList();
      for (final file in files) {
        if (file is File && file.path.toLowerCase().endsWith('.png')) {
          final fileName = file.uri.pathSegments.last.replaceAll('.png', '').replaceAll('.PNG', '');
          if (fileName.isNotEmpty) {
            manifest[fileName] = fileName;
          }
        }
      }
    }
    return manifest;
  }

  void _showIconPackManagement() async {
    final settings = Provider.of<AppSettings>(context, listen: false);
    await settings.loadAllIconPacks();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.photo_library, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      '图标包管理',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
                      final isCurrent = settings.currentIconPack == pack.name;
                      return _buildIconPackItem(pack, isCurrent, settings, context);
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
                        onPressed: isLoadingIconPack ? null : () {
                          Navigator.of(context).pop();
                          _selectAndLoadIconPack();
                        },
                        icon: isLoadingIconPack
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
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
      },
    );
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
    if (pack.isDefault) {
      // 系统默认图标包 - 使用本地assets/icon/train/CR400AF-SZE.png
      return Container(
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
            color: Theme.of(context).colorScheme.primary.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withAlpha(76),
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
        color: Theme.of(context).colorScheme.primary.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.photo_filter,
        color: Theme.of(context).colorScheme.primary,
        size: 24,
      ),
    );
  }

  Future<void> _switchToIconPack(IconPackInfo pack, AppSettings settings, BuildContext context) async {
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
            content: Text('已切换到 ${pack.metadata['name'] ?? pack.displayName}'),
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

  Widget _buildIconPackItem(IconPackInfo pack, bool isCurrent, AppSettings settings, BuildContext context) {
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
                            pack.metadata['name']?.toString() ?? pack.displayName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 20,  // 修改：从1行改为2行
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
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
                        pack.metadata['describe'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),  // 增加上边距
                        child: Text(
                          pack.metadata['describe'].toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
                          ),
                          maxLines: 20,  // 修改：从1行改为2行
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                    const SizedBox(height: 6),  // 增加间距

                    // 作者和图标数量信息
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (pack.metadata['author'] != null &&
                            pack.metadata['author'].toString().isNotEmpty)
                          Text(
                            '作者: ${pack.metadata['author']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
                            ),
                          ),

                        if (pack.iconCount > 0)
                          Text(
                            '${pack.iconCount} 个图标',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
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
                      builder: (context) => AlertDialog(
                        title: const Text('确认删除'),
                        content: Text('确定要删除图标包 "${pack.metadata['name'] ?? pack.displayName}" 吗？此操作不可恢复。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('取消'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
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
                              content: Text('图标包 "${pack.metadata['name'] ?? pack.displayName}" 已删除'),
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
      builder: (context) => AlertDialog(
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

  void _showUpdateCheckDialog() {
    if (!mounted) return;

    setState(() {
      isCheckingUpdate = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '正在检测更新...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    _performUpdateCheck();
  }

  Future<void> _performUpdateCheck() async {
    try {
      final versionInfo = await _checkForUpdate();

      if (!mounted) return;

      setState(() {
        isCheckingUpdate = false;
      });
      Navigator.of(context, rootNavigator: true).pop();
      _showUpdateResultDialog(versionInfo);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isCheckingUpdate = false;
      });
      Navigator.of(context, rootNavigator: true).pop();
      _showUpdateResultDialog({'error': e.toString()});
    }
  }

  void _showUpdateResultDialog(Map<String, dynamic>? versionInfo) {
    final currentBuild = int.tryParse(AppConstants.build) ?? 0;
    bool hasUpdate = false;
    String resultMessage = '';
    Color resultColor = AppColors.matchHigh;
    IconData resultIcon = Icons.check_circle;
    String? downloadUrl;
    String? downloadUrl1;
    String? newVersion;
    String? updateTime;

    if (versionInfo != null && versionInfo.containsKey('error')) {
      resultMessage = '检查更新失败: ${versionInfo['error']}';
      resultColor = AppColors.matchLow;
      resultIcon = Icons.error;
    } else if (versionInfo != null) {
      final remoteBuild = int.tryParse(versionInfo['Build'].toString()) ?? 0;
      newVersion = versionInfo['Version'];
      updateTime = versionInfo['LastUpdate'];
      downloadUrl = versionInfo['download'];
      downloadUrl1 = versionInfo['download1'];

      if (remoteBuild > currentBuild) {
        hasUpdate = true;
        resultMessage = '发现新版本 $newVersion\n更新时间: $updateTime\n\n请选择下载链接：';
        resultColor = AppColors.matchMedium;
        resultIcon = Icons.system_update;
      } else {
        resultMessage = '已是最新版本\n当前版本: ${AppConstants.version} | ${AppConstants.build}';
        resultColor = AppColors.matchHigh;
        resultIcon = Icons.check_circle;
      }
    } else {
      resultMessage = '检查更新失败: 未知错误';
      resultColor = AppColors.matchLow;
      resultIcon = Icons.error;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  resultIcon,
                  size: 60,
                  color: resultColor,
                ),
                const SizedBox(height: 20),
                Text(
                  hasUpdate ? '发现新版本' : '检查完成',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  resultMessage,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(204),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                if (hasUpdate) ...[
                  // 第一行：两个下载按钮并排
                  Row(
                    children: [
                      // 蓝色按钮 - 链接1
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _launchBrowserDownload(downloadUrl!);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.download, size: 20),
                              SizedBox(width: 8),
                              Text('Github (较慢)'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 绿色按钮 - 链接2
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _launchBrowserDownload(downloadUrl1!);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.download, size: 20),
                              SizedBox(width: 8),
                              Text('QQ群下载'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // 第二行：关闭按钮（单独一行，占满宽度）
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(hasUpdate ? '取消下载' : '关闭'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

// 修改方法定义，移除第二个参数
  Future<void> _launchBrowserDownload(String url) async {
    try {
      if (url.isEmpty || !url.startsWith('http')) {
        _showDownloadError('下载链接格式错误: $url');
        return;
      }

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('正在下载新版本'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        _showManualDownloadOptions(url);
      }
    } catch (e) {
      _showManualDownloadOptions(url);
    }
  }

  void _showManualDownloadOptions(String url) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('手动下载'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('由于无法自动打开链接，请手动复制以下链接到浏览器下载：'),
            const SizedBox(height: 10),
            SelectableText(url),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              if (!mounted) return;
              await Clipboard.setData(ClipboardData(text: url));

              if (!context.mounted) return;
              Navigator.of(context).pop();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('链接已复制到剪贴板')),
                );
              }
            },
            child: const Text('复制链接'),
          ),
        ],
      ),
    );
  }

  void _showDownloadError(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('跳转失败'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _launchSocialLink(String url) async {
    try {
      if (url.isEmpty || !url.startsWith('http')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('链接格式错误')),
          );
        }
        return;
      }

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('正在打开链接...'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        _showSocialLinkCopyDialog(url);
      }
    } catch (e) {
      _showSocialLinkCopyDialog(url);
    }
  }

  void _showSocialLinkCopyDialog(String url) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('无法打开链接'),
        content: const Text('请手动复制以下链接到浏览器中打开：'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('链接已复制到剪贴板')),
                );
              }
            },
            child: const Text('复制链接'),
          ),
        ],
      ),
    );
  }

  void _showDeveloperLinksDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 头像区域 - 使用本地图片
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withAlpha(76),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/icon/CrYinLang.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // 如果图片加载失败，显示备用图标
                        return Container(
                          color: Theme.of(context).colorScheme.primary.withAlpha(25),
                          child: Icon(
                            Icons.person,
                            size: 40,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  '开发者',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),

                Text(
                  'Cr.YinLang',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
                  ),
                ),
                const SizedBox(height: 4),

                Text(
                  'EmuAIO',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 24),

                // 描述文本
                Text(
                  '欢迎关注我的社交账号获取更多信息',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // 第一行：两个社交按钮
                Row(
                  children: [
                    // GitHub 按钮
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _launchSocialLink('https://github.com/CrYinLang');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.code, size: 20),
                        label: const Text('GitHub'),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // 抖音按钮
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _launchSocialLink('https://www.douyin.com/user/MS4wLjABAAAA-bZxFhm96BhUle209c1gQ5HskPw4y-olT2PwOYevJ6fSkkHmIV23EuGfjaq1xHCx');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF000000),
                          foregroundColor: const Color(0xFF00FF9D),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.video_library, size: 20),
                        label: const Text('抖音'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 第二行：关闭按钮
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('关闭'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingsCard(
            context: context,
            icon: Icons.color_lens,
            title: '主题设置',
            children: [
              SwitchListTile(
                title: const Text('深色主题'),
                subtitle: const Text('启用深色模式'),
                value: settings.themeMode == ThemeMode.dark,
                onChanged: settings.toggleTheme,
                secondary: Icon(
                  settings.themeMode == ThemeMode.dark
                      ? Icons.dark_mode
                      : Icons.light_mode,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              if (settings.themeMode == ThemeMode.dark) ...[
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('深夜模式'),
                  subtitle: const Text('纯黑背景，更护眼的配色'),
                  value: settings.midnightMode,
                  onChanged: settings.toggleMidnightMode,
                  secondary: Icon(
                    settings.midnightMode
                        ? Icons.nightlight_round
                        : Icons.nightlight_outlined,
                    color: settings.midnightMode
                        ? const Color(0xFF4DB6AC)
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          _buildSettingsCard(
            context: context,
            icon: Icons.photo_library,
            title: '图标显示设置',
            children: [
              SwitchListTile(
                title: const Text('显示列车图标'),
                subtitle: const Text('在查询结果中显示动车组图标'),
                value: settings.showTrainIcons,
                onChanged: settings.toggleTrainIcons,
                secondary: Icon(
                  Icons.train,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SwitchListTile(
                title: const Text('显示路局图标'),
                subtitle: const Text('在查询结果中显示路局图标'),
                value: settings.showBureauIcons,
                onChanged: settings.toggleBureauIcons,
                secondary: Icon(
                  Icons.account_balance,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.photo_library_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('图标包管理'),
                subtitle: Text(
                  settings.currentIconPack == 'default'
                      ? '使用默认图标包'
                      : '当前: ${settings.displayIconPackName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: isLoadingIconPack
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${settings.availableIconPacks.length} 个',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                onTap: isLoadingIconPack ? null : _showIconPackManagement,
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildSettingsCard(
            context: context,
            icon: Icons.info,
            title: '应用信息',
            children: [
              ListTile(
                title: const Text('版本'),
                subtitle: const Text('${AppConstants.version} | ${AppConstants.build}'),
                trailing: isCheckingUpdate
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onTap: isCheckingUpdate ? null : _showUpdateCheckDialog,
              ),
              ListTile(
                title: const Text('开发者'),
                subtitle: const Text('Cr.YinLang'),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onTap: () {
                  _showDeveloperLinksDialog(context);
                },
              ),
            ],
          ),

          if (settings.midnightMode) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              color: Colors.grey[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.nightlight_round,
                      color: const Color(0xFF4DB6AC),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '深夜模式已启用',
                            style: TextStyle(
                              color: const Color(0xFF4DB6AC),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '背景已调整为纯黑色，使用护眼配色方案',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsCard({
    required BuildContext context,
    required IconData? icon,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: icon != null
                ? Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
            )
                : null,
            title: DefaultTextStyle.merge(
              style: const TextStyle(fontWeight: FontWeight.w600),
              child: Text(title),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}