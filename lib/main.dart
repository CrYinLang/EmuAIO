//main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'train_model.dart';
import 'color_theme.dart';
import 'home_page.dart';
import 'gallery_page.dart';
import 'about_page.dart';
import 'settings_page.dart';

class AppConstants {
  static const String lastUpdate = '26-02-01-12-50';
  static const String version = '2.2.0.0';
  static const String build = '2200';

  static Future<Map<String, dynamic>?> fetchVersionInfo() async {
    try {
      final response = await http.get(
          Uri.parse('https://gitee.com/CrYinLang/emu-aio/raw/master/version.json')
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint('获取版本信息失败: $e');
    }
    return null;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppSettings()..loadSettings(),
      child: const EmuAIOApp(),
    ),
  );
}

class EmuAIOApp extends StatelessWidget {
  const EmuAIOApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettings>(
      builder: (context, settings, _) {
        return MaterialApp(
          title: 'EmuAIO',
          themeMode: settings.themeMode,
          theme: ThemeData.light(useMaterial3: true),
          darkTheme: settings.midnightMode
              ? ColorThemeUtils.buildMidnightTheme()
              : ThemeData.dark(useMaterial3: true),
          home: const MainScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

// ==================== 设置管理 ====================
class IconPackInfo {
  final String name; // 唯一标识符
  final String displayName; // 显示名称
  final String path;
  final Map<String, String> manifest;
  final Map<String, dynamic> metadata;
  final bool isDefault;
  final DateTime createdTime;
  final int iconCount;
  final String? description;
  final String? author;

  IconPackInfo({
    required this.name,
    required this.displayName,
    required this.path,
    required this.manifest,
    required this.metadata,
    this.isDefault = false,
    required this.createdTime,
    required this.iconCount,
    this.description,
    this.author,
  });

  factory IconPackInfo.fromJson(Map<String, dynamic> json) {
    return IconPackInfo(
      name: json['name'] ?? 'unknown',
      displayName: json['displayName'] ?? json['name'] ?? '未命名',
      path: json['path'] ?? '',
      manifest: Map<String, String>.from(json['manifest'] ?? {}),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      isDefault: json['isDefault'] ?? false,
      createdTime: json['createdTime'] != null
          ? DateTime.parse(json['createdTime'])
          : DateTime.now(),
      iconCount: json['iconCount'] ?? 0,
      description: json['description'] ?? json['describe'],
      author: json['author'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'displayName': displayName,
      'path': path,
      'manifest': manifest,
      'metadata': metadata,
      'isDefault': isDefault,
      'createdTime': createdTime.toIso8601String(),
      'iconCount': iconCount,
      if (description != null) 'description': description,
      if (author != null) 'author': author,
    };
  }
}

enum TrainDataSource {
  railRe,
  official12306,
}

class AppSettings extends ChangeNotifier {
  // ==================== 图标文件名获取 ====================
  String getIconFileName(String iconModel) {
    if (_currentIconPack == 'default' || _currentIconPack.isEmpty) {
      return iconModel;
    }

    // 检查manifest中是否有这个车型的映射
    if (_iconPackManifest.containsKey(iconModel)) {
      final fileName = _iconPackManifest[iconModel];
      return fileName ?? iconModel;
    }

    // 特殊处理：如果车型包含CR前缀
    if (iconModel.startsWith('CR')) {
      final crType = iconModel.substring(2); // 移除CR前缀
      final possibleKeys = [
        iconModel,
        'CR$crType',
        crType,
        iconModel.toLowerCase(),
        iconModel.toUpperCase(),
      ];

      for (var key in possibleKeys) {
        if (_iconPackManifest.containsKey(key)) {
          final fileName = _iconPackManifest[key];
          return fileName ?? iconModel;
        }
      }
    }

    return iconModel;
  }

  // ==================== 主题设置 ====================
  ThemeMode _themeMode = ThemeMode.dark;
  bool _midnightMode = false;
  bool _isLoading = false;

  // ==================== 图标显示设置 ====================
  bool _showTrainIcons = false;
  bool _showBureauIcons = true;

  // ==================== 图标包设置 ====================
  String _currentIconPack = 'default';
  String _iconPackPath = '';
  Map<String, String> _iconPackManifest = {};
  Map<String, dynamic> _iconPackMetadata = {};

  // ==================== 图标包列表管理 ====================
  List<IconPackInfo> _availableIconPacks = [];

  // ==================== Getter 方法 ====================
  ThemeMode get themeMode => _themeMode;
  bool get midnightMode => _midnightMode;
  bool get showTrainIcons => _showTrainIcons;
  bool get showBureauIcons => _showBureauIcons;
  String get currentIconPack => _currentIconPack;
  String get iconPackPath => _iconPackPath;
  Map<String, String> get iconPackManifest => _iconPackManifest;
  Map<String, dynamic> get iconPackMetadata => _iconPackMetadata;
  bool get isLoading => _isLoading;
  List<IconPackInfo> get availableIconPacks => _availableIconPacks;

  // ==================== 应用常量 ====================
  static const String version = AppConstants.version;
  static const String build = AppConstants.build;
  static const String lastUpdate = AppConstants.lastUpdate;

// ==================== 初始化设置 ====================
  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      // 主题设置
      _themeMode = (prefs.getBool('isDark') ?? true) ? ThemeMode.dark : ThemeMode.light;
      _midnightMode = prefs.getBool('midnightMode') ?? false;

      // 数据源设置
      final dataSourceIndex = prefs.getInt('dataSource') ?? 0;
      _dataSource = TrainDataSource.values[dataSourceIndex.clamp(0, TrainDataSource.values.length - 1)];

      // 图标显示设置
      _showTrainIcons = prefs.getBool('showTrainIcons') ?? false;
      _showBureauIcons = prefs.getBool('showBureauIcons') ?? true;

      // 图标包设置
      _currentIconPack = prefs.getString('currentIconPack') ?? 'default';
      _iconPackPath = prefs.getString('iconPackPath') ?? '';

      // 加载图标包映射配置
      final manifestJson = prefs.getString('iconPackManifest');
      if (manifestJson != null && manifestJson.isNotEmpty) {
        try {
          final Map<String, dynamic> manifestData = json.decode(manifestJson);
          _iconPackManifest = manifestData.map((key, value) =>
              MapEntry(key, value.toString()));
        } catch (e) {
          _iconPackManifest = {};
        }
      } else {
        _iconPackManifest = {};
      }

      // 加载图标包元信息
      final metadataJson = prefs.getString('iconPackMetadata');
      if (metadataJson != null && metadataJson.isNotEmpty) {
        try {
          final Map<String, dynamic> metadata = json.decode(metadataJson);
          _iconPackMetadata = Map<String, dynamic>.from(metadata);
        } catch (e) {
          _iconPackMetadata = _createDefaultMetadata();
        }
      } else {
        _iconPackMetadata = _createDefaultMetadata();
      }

      // 加载图标包列表
      await _loadIconPacksList();

    } catch (e) {
      // 设置默认值
      _setDefaultValues();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== 图标包列表管理方法 ====================
  Future<void> _loadIconPacksList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final packsJson = prefs.getString('availableIconPacks');

      if (packsJson != null && packsJson.isNotEmpty) {
        final List<dynamic> packsList = json.decode(packsJson);
        _availableIconPacks = packsList.map((pack) {
          return IconPackInfo.fromJson(pack);
        }).toList();
      } else {
        _availableIconPacks = [];
      }

      if (!_availableIconPacks.any((pack) => pack.isDefault)) {
        _availableIconPacks.insert(0, IconPackInfo(
          name: 'default',
          displayName: '默认图标包1',
          path: '',
          manifest: {},
          metadata: {
            'name': '默认图标包1',
            'describe': '内置默认图标',
            'author': 'Cr.YinLang',
          },
          isDefault: true,
          createdTime: DateTime(2024, 1, 1),
          iconCount: 0,
        ));
      }

    } catch (e) {
      // 在生产环境中可以记录日志，但不要使用 print
      debugPrint('加载图标包列表失败: $e');
      _availableIconPacks = [];
    }
  }

  Future<void> _saveIconPacksList() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 过滤掉默认图标包
      final nonDefaultPacks = _availableIconPacks
          .where((pack) => !pack.isDefault)
          .map((pack) => pack.toJson())
          .toList();

      await prefs.setString('availableIconPacks', json.encode(nonDefaultPacks));
    } catch (e) {
      debugPrint('保存图标包列表失败: $e');
    }
  }

  // 添加图标包
  Future<void> addIconPack({
    required String name,
    required String path,
    required Map<String, String> manifest,
    required Map<String, dynamic> metadata,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 生成唯一标识符
      final String uniqueName = '${name}_${DateTime.now().millisecondsSinceEpoch}';

      // 计算实际图标数量
      final metaKeys = ['name', 'describe', 'description', 'author', 'title', 'packname'];
      final int iconCount = manifest.keys
          .where((key) => !metaKeys.contains(key))
          .length;

      final newPack = IconPackInfo(
        name: uniqueName,
        displayName: metadata['name']?.toString() ?? name,
        path: path,
        manifest: Map<String, String>.from(manifest),
        metadata: Map<String, dynamic>.from(metadata),
        isDefault: false,
        createdTime: DateTime.now(),
        iconCount: iconCount,
        description: metadata['describe']?.toString() ?? metadata['description']?.toString(),
        author: metadata['author']?.toString(),
      );

      // 添加到列表
      _availableIconPacks.add(newPack);
      await _saveIconPacksList();

      // 自动切换到新图标包
      await switchIconPack(uniqueName);

    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 删除图标包
  Future<void> deleteIconPack(String packName) async {
    if (packName == 'default' || packName.isEmpty) {
      return; // 不能删除默认图标包
    }

    _isLoading = true;
    notifyListeners();

    try {
      // 查找要删除的图标包
      final index = _availableIconPacks.indexWhere((pack) => pack.name == packName);
      if (index == -1) {
        throw Exception('图标包不存在: $packName');
      }

      final packToDelete = _availableIconPacks[index];

      // 如果要删除的是当前正在使用的，先切换回默认
      if (_currentIconPack == packName) {
        await resetToDefaultIcons();
      }

      // 从列表中移除
      _availableIconPacks.removeAt(index);
      await _saveIconPacksList();

      // 异步删除对应的文件夹
      try {
        final dir = Directory(packToDelete.path);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (e) {
        debugPrint('删除图标包文件夹失败: $e');
        // 不抛出错误，只记录日志
      }

    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 切换图标包
  Future<void> switchIconPack(String packName) async {
    if (packName == 'default') {
      await resetToDefaultIcons();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // 查找图标包
      final pack = _availableIconPacks.firstWhere(
            (p) => p.name == packName,
        orElse: () => throw Exception('图标包不存在: $packName'),
      );

      // 切换到新图标包
      await changeIconPack(
        packName,
        pack.path,
        pack.manifest,
      );

      // 更新元信息
      _iconPackMetadata = Map<String, dynamic>.from(pack.metadata);

      // 保存元信息
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('iconPackMetadata', json.encode(_iconPackMetadata));

    } catch (e) {
      // 如果切换失败，回退到默认
      await resetToDefaultIcons();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 加载所有图标包
  Future<void> loadAllIconPacks() async {
    await _loadIconPacksList();
    notifyListeners();
  }

  // 获取当前激活的图标包信息
  IconPackInfo? getCurrentPackInfo() {
    if (_currentIconPack == 'default') {
      return _availableIconPacks.firstWhere(
            (pack) => pack.isDefault,
        orElse: () => IconPackInfo(
          name: 'default',
          displayName: '默认图标包',
          path: '',
          manifest: {},
          metadata: _iconPackMetadata,
          isDefault: true,
          createdTime: DateTime.now(),
          iconCount: 0,
        ),
      );
    }

    try {
      return _availableIconPacks.firstWhere((pack) => pack.name == _currentIconPack);
    } catch (e) {
      return null;
    }
  }

  // ==================== 数据源设置 ====================
  TrainDataSource _dataSource = TrainDataSource.railRe;

  TrainDataSource get dataSource => _dataSource;

  String get dataSourceDisplayName {
    switch (_dataSource) {
      case TrainDataSource.railRe:
        return 'Rail.re';
      case TrainDataSource.official12306:
        return '12306官方';
    }
  }

  String get dataSourceDescription {
    switch (_dataSource) {
      case TrainDataSource.railRe:
        return '第三方API，提供更丰富的数据，但可能缺少部分数据';
      case TrainDataSource.official12306:
        return '官方数据源，最准确可靠，但可能城际和动集没有';
    }
  }

  Future<void> setDataSource(TrainDataSource source) async {
    if (_dataSource != source) {
      _dataSource = source;

      // 保存到本地存储
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('dataSource', source.index);

      notifyListeners();
    }
  }

  // ==================== 辅助方法 ====================
  Map<String, dynamic> _createDefaultMetadata() {
    return {
      'name': _currentIconPack == 'default' ? '默认图标包' : '未命名图标包',
      'describe': _currentIconPack == 'default' ? '使用内置图标资源' : '自定义图标包',
      'author': _currentIconPack == 'default' ? '系统' : '未知作者',
      'iconCount': _iconPackManifest.length,
      'loadTime': DateTime.now().toIso8601String(),
    };
  }

  void _setDefaultValues() {
    _themeMode = ThemeMode.dark;
    _midnightMode = false;
    _showTrainIcons = false;
    _showBureauIcons = true;
    _currentIconPack = 'default';
    _iconPackPath = '';
    _iconPackManifest = {};
    _iconPackMetadata = _createDefaultMetadata();
  }

  // ==================== 主题设置方法 ====================
  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', isDark);
    notifyListeners();
  }

  Future<void> toggleMidnightMode(bool value) async {
    _midnightMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('midnightMode', value);
    notifyListeners();
  }

  // ==================== 图标显示设置方法 ====================
  Future<void> toggleTrainIcons(bool value) async {
    _showTrainIcons = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showTrainIcons', value);
    notifyListeners();
  }

  Future<void> toggleBureauIcons(bool value) async {
    _showBureauIcons = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showBureauIcons', value);
    notifyListeners();
  }

  // ==================== 图标包管理方法 ====================
  Future<void> changeIconPack(
      String packName,
      String path,
      Map<String, String> manifest,
      ) async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentIconPack = packName;
      _iconPackPath = path;
      _iconPackManifest = Map<String, String>.from(manifest);

      // 提取元信息
      _extractMetadataFromManifest(manifest);

      // 异步保存到持久化存储
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString('currentIconPack', _currentIconPack),
        prefs.setString('iconPackPath', _iconPackPath),
        prefs.setString('iconPackManifest', json.encode(_iconPackManifest)),
        prefs.setString('iconPackMetadata', json.encode(_iconPackMetadata)),
      ]);

    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 修复：改进的元信息提取方法
  void _extractMetadataFromManifest(Map<String, String> manifest) {
    _iconPackMetadata = {};

    // 检查是否是纯图标映射（没有元信息字段）
    bool hasMetadata = false;
    final metaKeys = ['name', 'describe', 'description', 'author', 'title', 'packname'];

    for (var key in metaKeys) {
      if (manifest.containsKey(key)) {
        hasMetadata = true;
        break;
      }
    }

    if (hasMetadata) {
      // 包含元信息字段，正常提取
      _extractFromManifestWithMetadata(manifest);
    } else {
      // 纯图标映射，从其他来源获取元信息
      _handlePureIconMap(manifest);
    }
  }

  // 处理包含元信息的manifest
  void _extractFromManifestWithMetadata(Map<String, String> manifest) {

    // 字段名映射
    final Map<String, List<String>> fieldMappings = {
      'name': ['name', 'Name', 'NAME', 'title', 'Title', 'packname', 'packName'],
      'describe': ['describe', 'description', 'Description', 'desc', 'Desc'],
      'author': ['author', 'Author', 'AUTHOR', 'creator', 'Creator', 'by']
    };

    // 提取名称
    String? extractedName = _extractFieldValue(manifest, fieldMappings['name']!);
    if (extractedName != null && extractedName.isNotEmpty) {
      _iconPackMetadata['name'] = extractedName;
    } else {
      _iconPackMetadata['name'] = '未命名图标包';
    }

    // 提取描述
    String? extractedDesc = _extractFieldValue(manifest, fieldMappings['describe']!);
    _iconPackMetadata['describe'] = extractedDesc ?? '';

    // 提取作者
    String? extractedAuthor = _extractFieldValue(manifest, fieldMappings['author']!);
    _iconPackMetadata['author'] = extractedAuthor ?? '未知作者';

    // 添加统计信息
    _iconPackMetadata['iconCount'] = _getIconCount(manifest);
    _iconPackMetadata['loadTime'] = DateTime.now().toIso8601String();
  }

  // 处理纯图标映射
  void _handlePureIconMap(Map<String, String> manifest) {

    // 使用当前图标包名称作为默认名称
    _iconPackMetadata['name'] = _currentIconPack != 'default' && _currentIconPack.isNotEmpty
        ? _currentIconPack
        : '自定义图标包';

    _iconPackMetadata['describe'] = '从图标包自动生成';
    _iconPackMetadata['author'] = '用户上传';
    _iconPackMetadata['iconCount'] = manifest.length;
    _iconPackMetadata['loadTime'] = DateTime.now().toIso8601String();
    _iconPackMetadata['isPureIconMap'] = true;
  }

  // 获取图标数量（排除元信息字段）
  int _getIconCount(Map<String, String> manifest) {
    final metaKeys = ['name', 'describe', 'description', 'author', 'title', 'packname'];
    int count = 0;

    for (var key in manifest.keys) {
      if (!metaKeys.contains(key)) {
        count++;
      }
    }
    return count;
  }

  // 字段值提取方法
  String? _extractFieldValue(Map<String, String> manifest, List<String> possibleKeys) {
    for (var key in possibleKeys) {
      if (manifest.containsKey(key)) {
        final value = manifest[key];
        if (value != null && value.isNotEmpty) {
          final result = _ensureUtf8String(value);
          return result;
        }
      }
    }
    return null;
  }

  // UTF-8 字符串处理
  String _ensureUtf8String(String input) {
    try {
      if (input.isEmpty) return input;
      final bytes = utf8.encode(input);
      return utf8.decode(bytes, allowMalformed: false);
    } catch (e) {
      return input.replaceAll(RegExp(r'[^\x00-\x7F\u4e00-\u9fff]'), '');
    }
  }

  Future<void> resetToDefaultIcons() async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentIconPack = 'default';
      _iconPackPath = '';
      _iconPackManifest = {};
      _iconPackMetadata = _createDefaultMetadata();

      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString('currentIconPack', 'default'),
        prefs.setString('iconPackPath', ''),
        prefs.setString('iconPackManifest', ''),
        prefs.setString('iconPackMetadata', json.encode(_iconPackMetadata)),
      ]);

    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== 新增：状态同步方法 ====================
  Future<void> refreshSettings() async {
    await loadSettings();
  }

  // 强制同步状态
  void forceNotify() {
    notifyListeners();
  }

  // ==================== 调试和验证方法 ====================
  Map<String, dynamic> getIconPackDebugInfo() {
    return {
      'currentIconPack': _currentIconPack,
      'iconPackPath': _iconPackPath,
      'manifestCount': _iconPackManifest.length,
      'metadata': _iconPackMetadata,
      'isLoading': _isLoading,
      'availablePacksCount': _availableIconPacks.length,
      'availablePacks': _availableIconPacks.map((p) => p.displayName).toList(),
      'appVersion': version,
      'appBuild': build,
    };
  }

  // 获取显示名称（用于界面显示）
  String get displayIconPackName {
    final name = _iconPackMetadata['name'] ?? _currentIconPack;
    if (name == '未命名图标包' || name.isEmpty) {
      return _currentIconPack == 'default' ? '默认图标包' : '自定义图标包';
    }
    return name;
  }

  // ==================== 应用信息方法 ====================
  Map<String, String> getAppInfo() {
    return {
      'version': version,
      'build': build,
      'lastUpdate': lastUpdate,
      'themeMode': _themeMode.toString(),
      'midnightMode': _midnightMode.toString(),
      'iconPack': _currentIconPack,
      'availableIconPacks': _availableIconPacks.length.toString(),
    };
  }

  // ==================== 重置所有设置 ====================
  Future<void> resetAllSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      final Directory appDocDir = Directory(
          (await getApplicationDocumentsDirectory()).path
      );

      // 如果文档目录存在，删除其中的所有文件和子目录
      if (await appDocDir.exists()) {
        final files = await appDocDir.list().toList();
        for (final file in files) {
          if (file is File) {
              await file.delete();
          } else if (file is Directory) {
              await file.delete(recursive: true);
          }
        }
      }

      final Directory tempDir = Directory(
          (await getTemporaryDirectory()).path
      );

      if (await tempDir.exists()) {
        final tempFiles = await tempDir.list().toList();
        for (final file in tempFiles) {
          if (file is File) {
              await file.delete();
          } else if (file is Directory) {
              await file.delete(recursive: true);
          }
        }
      }

    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== 导出设置 ====================
  Future<Map<String, dynamic>> exportSettings() async {
    return {
      'exportTime': DateTime.now().toIso8601String(),
      'appInfo': {
        'version': version,
        'build': build,
        'lastUpdate': lastUpdate,
      },
      'themeSettings': {
        'themeMode': _themeMode.toString(),
        'isDark': _themeMode == ThemeMode.dark,
        'midnightMode': _midnightMode,
      },
      'iconSettings': {
        'showTrainIcons': _showTrainIcons,
        'showBureauIcons': _showBureauIcons,
      },
      'iconPackSettings': {
        'currentIconPack': _currentIconPack,
        'currentPackName': displayIconPackName,
        'iconPackPath': _iconPackPath,
        'manifestSize': _iconPackManifest.length,
        'metadata': _iconPackMetadata,
      },
      'iconPackList': {
        'count': _availableIconPacks.length,
        'packs': _availableIconPacks.map((p) => p.displayName).toList(),
      },
      'isLoading': _isLoading,
    };
  }
}

// ==================== 主屏幕 ====================
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _settingsTapCount = 0;
  DateTime? _lastTapTime;
  OverlayEntry? _tapCounterOverlay;

  final List<Widget> _pages = [
    const HomePage(),
    const GalleryPage(),
    const AboutPage(),
    const SettingsPage(),
  ];

  void _hideTapCounterOverlay() {
    if (_tapCounterOverlay != null) {
      _tapCounterOverlay?.remove();
      _tapCounterOverlay = null;
    }
  }

  void _handleSettingsTap() {
    final now = DateTime.now();

    // 重置计数器（如果距离上次点击超过5秒）
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) > const Duration(seconds: 5)) {
      _settingsTapCount = 0;
    }

    _lastTapTime = now;
    _settingsTapCount++;

    if (_settingsTapCount >= 10) {
      _settingsTapCount = 0;
      _hideTapCounterOverlay();

      // 直接执行重置
      _performImmediateReset();
    }

    setState(() {
      _currentIndex = 3; // 切换到设置页面
    });
  }

  Future<void> _performImmediateReset() async {
    final context = this.context;
    final settings = Provider.of<AppSettings>(context, listen: false);

    await settings.resetAllSettings();
    exit(0);
  }

  @override
  void dispose() {
    _hideTapCounterOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 3) { // 设置页面索引
            _handleSettingsTap();
          } else {
            _settingsTapCount = 0; // 重置计数器
            _hideTapCounterOverlay();
            setState(() => _currentIndex = index);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.photo_library), label: '图鉴'),
          BottomNavigationBarItem(icon: Icon(Icons.info), label: '关于'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}

// 图标工具类
class IconUtils {
  static String? getBureauIconFileName(String bureau) {
    return bureau;
  }
}

class TrainIconWidget extends StatelessWidget {
  final String model;
  final String number;
  final double size;
  final bool showIcon;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const TrainIconWidget({
    super.key,
    required this.model,
    required this.number,
    this.size = 32,
    this.showIcon = true,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context, listen: false);

    // 如果不显示图标，返回空容器
    if (!settings.showTrainIcons || !showIcon) {
      return SizedBox(width: size, height: size);
    }

    // 获取处理后的车型和图标文件名
    String iconModel = TrainModelUtils.getTrainIconModel(model, number);
    String iconFileName = settings.getIconFileName(iconModel);


    // 根据图标包类型选择不同的加载方式
    if (settings.currentIconPack == 'default') {
      // 默认图标包：使用assets资源
      return _buildAssetIcon(iconFileName);
    } else {
      // 自定义图标包：使用文件系统
      return _buildFileIcon(iconFileName, settings);
    }
  }

  // 构建资源图标（默认图标包）
  Widget _buildAssetIcon(String fileName) {
    // 移除可能的.png扩展名
    String cleanFileName = _removePngExtension(fileName);
    String assetPath = 'assets/icon/train/$cleanFileName.png';

    return FutureBuilder<bool>(
      future: _checkAssetExists(assetPath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.data == true) {
            return _buildImageAsset(assetPath);
          } else {
            return _buildFallbackIcon('资源图标不存在');
          }
        }
        return _buildLoadingIndicator();
      },
    );
  }

  // 构建文件图标（自定义图标包）
  Widget _buildFileIcon(String fileName, AppSettings settings) {
    // 移除可能的.png扩展名
    String cleanFileName = _removePngExtension(fileName);
    String filePath = '${settings.iconPackPath}/train/$cleanFileName.png';

    return FutureBuilder<File?>(
      future: _getImageFile(filePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return _buildFallbackIcon('文件访问错误');
          } else if (snapshot.hasData && snapshot.data != null) {
            return _buildImageFile(snapshot.data!);
          } else {
            return _buildFallbackIcon('文件不存在');
          }
        }
        return _buildLoadingIndicator();
      },
    );
  }

  // 构建资源图片
  Widget _buildImageAsset(String assetPath) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(size / 8),
        color: backgroundColor,
      ),
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackIcon('加载失败');
        },
      ),
    );
  }

  // 构建文件图片
  Widget _buildImageFile(File imageFile) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(size / 8),
        color: backgroundColor,
      ),
      child: Image.file(
        imageFile,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackIcon('文件加载失败');
        },
      ),
    );
  }

  // 检查资源是否存在
  Future<bool> _checkAssetExists(String path) async {
    await rootBundle.load(path);
    return true;
  }

  // 获取图片文件
  Future<File?> _getImageFile(String path) async {
    try {
      File file = File(path);

      // 检查文件是否存在
      bool exists = await file.exists();
      if (!exists) {
        return null;
      }

      // 获取文件信息
      final stat = await file.stat();

      // 验证文件类型
      if (stat.type == FileSystemEntityType.directory) {
        return null;
      }

      // 验证文件可读
      try {
        final canRead = await file.readAsBytes();
        if (canRead.isEmpty) {
          return null;
        }
      } catch (e) {
        return null;
      }

      return file;
    } catch (e) {
      return null;
    }
  }

  // 移除.png扩展名
  String _removePngExtension(String fileName) {
    if (fileName.toLowerCase().endsWith('.png')) {
      return fileName.substring(0, fileName.length - 4);
    }
    return fileName;
  }

  // 备用图标
  Widget _buildFallbackIcon(String reason) {

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(size / 8),
        color: backgroundColor ?? Colors.grey[200],
        border: Border.all(
          color: Colors.grey[400]!,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.train,
            size: size * 0.4,
            color: Colors.grey[600],
          ),
          if (size > 40)
            Text(
              model,
              style: TextStyle(
                fontSize: size * 0.2,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  // 加载指示器
  Widget _buildLoadingIndicator() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(size / 8),
        color: backgroundColor ?? Colors.grey[200],
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
      ),
    );
  }

  // 验证图标包文件（可以在设置页面调用）
  static Future<Map<String, dynamic>> validateIconPack(String iconPackPath) async {
    try {
      final trainDir = Directory('$iconPackPath/train');

      if (!await trainDir.exists()) {
        return {
          'valid': false,
          'error': 'train目录不存在: $iconPackPath/train',
          'files': [],
        };
      }

      final files = await trainDir.list().toList();
      final pngFiles = <File>[];
      final otherFiles = <FileSystemEntity>[];

      for (final file in files) {
        if (file is File) {
          if (file.path.toLowerCase().endsWith('.png')) {
            pngFiles.add(file);
          } else {
            otherFiles.add(file);
          }
        }
      }

      // 检查文件详细信息
      final fileDetails = <Map<String, dynamic>>[];
      for (final file in pngFiles.take(10)) { // 只检查前10个文件
        try {
          final stat = await file.stat();
          fileDetails.add({
            'name': file.uri.pathSegments.last,
            'size': stat.size,
            'modified': stat.modified.toIso8601String(),
            'path': file.path,
          });
        } catch (e) {
          fileDetails.add({
            'name': file.uri.pathSegments.last,
            'error': e.toString(),
            'path': file.path,
          });
        }
      }

      return {
        'valid': pngFiles.isNotEmpty,
        'trainDir': trainDir.path,
        'totalFiles': files.length,
        'pngFiles': pngFiles.length,
        'otherFiles': otherFiles.length,
        'sampleFiles': fileDetails,
        'hasTrainDir': true,
        'allFiles': files.map((f) => f is File ? f.uri.pathSegments.last : f.path).toList(),
      };
    } catch (e) {
      return {
        'valid': false,
        'error': e.toString(),
        'files': [],
      };
    }
  }
}

// 路局图标Widget
class BureauIconWidget extends StatelessWidget {
  final String bureau;
  final double size;
  final bool showIcon;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const BureauIconWidget({
    super.key,
    required this.bureau,
    this.size = 32,
    this.showIcon = true,
    this.backgroundColor,
    this.borderRadius,
  });

  // 检查图标是否存在
  Future<bool> _checkImageExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    if (!settings.showBureauIcons || !showIcon || bureau.isEmpty) {
      return SizedBox(width: size, height: size);
    }

    String? fileName = IconUtils.getBureauIconFileName(bureau);
    if (fileName == null) {
      return SizedBox(width: size, height: size);
    }

    String iconPath = 'assets/icon/bureau/$fileName.png';

    return FutureBuilder<bool>(
      future: _checkImageExists(iconPath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.data == true) {
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: borderRadius ?? BorderRadius.circular(size / 8),
                color: backgroundColor ?? Colors.transparent,
              ),
              child: Image.asset(
                iconPath,
                width: size,
                height: size,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return _buildFallbackIcon();
                },
              ),
            );
          } else {
            return _buildFallbackIcon();
          }
        }
        return _buildLoadingIndicator();
      },
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(size / 8),
        color: Colors.grey[200],
      ),
      child: Icon(
        Icons.account_balance,
        size: size * 0.6,
        color: Colors.grey[600],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(size / 8),
        color: Colors.grey[200],
      ),
      child: const CircularProgressIndicator(strokeWidth: 2),
    );
  }
}