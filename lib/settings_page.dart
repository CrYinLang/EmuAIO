// settings_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'main.dart';
import 'icon_pack.dart';
import 'update.dart';

Future<void> launchSocialLink(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('正在打开链接...'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool isLoadingIconPack = false;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionCard(
            context,
            icon: Icons.color_lens,
            title: '主题设置',
            children: [
              _settingsSwitch(
                context,
                title: '深色主题',
                subtitle: '启用深色模式',
                icon: settings.themeMode == ThemeMode.dark
                    ? Icons.dark_mode
                    : Icons.light_mode,
                value: settings.themeMode == ThemeMode.dark,
                onChanged: settings.toggleTheme,
              ),
              if (settings.themeMode == ThemeMode.dark)
                _settingsSwitch(
                  context,
                  title: '深夜模式',
                  subtitle: '纯黑背景，更护眼的配色',
                  icon: settings.midnightMode
                      ? Icons.nightlight_round
                      : Icons.nightlight_outlined,
                  value: settings.midnightMode,
                  onChanged: settings.toggleMidnightMode,
                ),
            ],
          ),

          const SizedBox(height: 16),

          _sectionCard(
            context,
            icon: Icons.photo_library,
            title: '图标显示设置',
            children: [
              _settingsSwitch(
                context,
                title: '显示列车图标',
                subtitle: '在查询结果中显示动车组图标',
                icon: Icons.train,
                value: settings.showTrainIcons,
                onChanged: settings.toggleTrainIcons,
              ),
              _settingsSwitch(
                context,
                title: '显示路局图标',
                subtitle: '在查询结果中显示路局图标',
                icon: Icons.account_balance,
                value: settings.showBureauIcons,
                onChanged: settings.toggleBureauIcons,
              ),
              _settingsTile(
                context,
                icon: Icons.photo_library_outlined,
                title: '图标包管理',
                subtitle: settings.currentIconPack == 'default'
                    ? '使用默认图标包'
                    : '当前: ${settings.displayIconPackName}',
                trailing: Text(
                  '${settings.availableIconPacks.length} 个',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha:0.6), // 修正这里
                  ),
                ),
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => const IconPackManager(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 更新后的数据源设置卡片
          _sectionCard(
            context,
            icon: Icons.storage,
            title: '车次数据源设置',
            children: [
              _dataSourceTile(
                context,
                settings: settings,
                source: TrainDataSource.railRe,
                title: 'Rail.re',
                description: '第三方数据源，更新频率高',
                icon: Icons.cloud_upload,
              ),
              _dataSourceTile(
                context,
                settings: settings,
                source: TrainDataSource.official12306,
                title: '12306官方',
                description: '官方数据，最准确可靠',
                icon: Icons.train,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0), // 修正这里
                child: Text(
                  settings.dataSourceDescription,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.7), // 修正这里
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _sectionCard(
            context,
            icon: Icons.info,
            title: '应用信息',
            children: [
              _settingsTile(
                context,
                title: '版本',
                subtitle: '${AppConstants.version} | ${AppConstants.build}',
                trailingIcon: Icons.arrow_forward_ios,
                onTap: () => UpdateUI.showUpdateFlow(context),
              ),
              _settingsTile(
                context,
                title: '开发者',
                subtitle: 'Cr.YinLang',
                trailingIcon: Icons.arrow_forward_ios,
                onTap: () => _showDeveloperLinksDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        required List<Widget> children,
      }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _sectionTitle(context, icon, title),
          ...children,
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _settingsSwitch(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required bool value,
        required Function(bool) onChanged,
      }) {
    return SwitchListTile(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.7), // 修正这里
        ),
      ),
      secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _settingsTile(
      BuildContext context, {
        IconData? icon,
        required String title,
        String? subtitle,
        Widget? trailing,
        IconData? trailingIcon,
        VoidCallback? onTap,
      }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: icon != null
          ? Icon(icon, color: theme.colorScheme.primary, size: 24)
          : null,
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurface.withValues(alpha:0.7), // 修正这里
        ),
      )
          : null,
      trailing: trailing ??
          (trailingIcon != null
              ? Icon(
            trailingIcon,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          )
              : null),
      onTap: onTap,
    );
  }

  // 新增：数据源设置选项
  Widget _dataSourceTile(
      BuildContext context, {
        required AppSettings settings,
        required TrainDataSource source,
        required String title,
        required String description,
        required IconData icon,
      }) {
    final theme = Theme.of(context);
    final isSelected = settings.dataSource == source;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha:0.1)
              : theme.colorScheme.surfaceContainerHighest, // 修正这里
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      title: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
          ),
          if (isSelected) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '当前',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        description,
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: isSelected
          ? Icon(
        Icons.check_circle,
        color: theme.colorScheme.primary,
        size: 20,
      )
          : Icon(
        Icons.circle_outlined,
        color: theme.colorScheme.outline,
        size: 20,
      ),
      onTap: () {
        if (!isSelected) {
          _showDataSourceConfirmDialog(context, settings, source, title);
        }
      },
    );
  }

  // 新增：数据源切换确认对话框
  void _showDataSourceConfirmDialog(
      BuildContext context,
      AppSettings settings,
      TrainDataSource newSource,
      String sourceName,
      ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('切换数据源'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('确定要切换到 $sourceName 吗？'),
              const SizedBox(height: 8),
              Text(
                '切换后，所有查询将使用新的数据源。',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.6), // 修正这里
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await settings.setDataSource(newSource);
                  if (!context.mounted) return;
                  Navigator.of(context).pop();

                  // 显示切换成功的提示
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已切换到 $sourceName'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('切换失败: ${e.toString()}'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('切换'),
            ),
          ],
        );
      },
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
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha:0.3), // 修正这里
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/icon/CrYinLang.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha:0.1), // 修正这里
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
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.7), // 修正这里
                  ),
                ),
                const SizedBox(height: 4),

                Text(
                  'EmuAIO',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.5), // 修正这里
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 24),

                // 描述文本
                Text(
                  '欢迎关注我的社交账号获取更多信息',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.6), // 修正这里
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await launchSocialLink(
                            context,
                            'https://github.com/CrYinLang',
                          );
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
                        onPressed: () async {
                          await launchSocialLink(
                            context,
                            'https://www.douyin.com/user/MS4wLjABAAAA-bZxFhm96BhUle209c1gQ5HskPw4y-olT2PwOYevJ6fSkkHmIV23EuGfjaq1xHCx',
                          );
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

                // 关闭按钮
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
}