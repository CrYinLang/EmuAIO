// settings_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

import 'main.dart';
import 'icon_pack.dart';
import 'update.dart';

Future<void> launchSocialLink(BuildContext context, String url) async {
  try {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('正在打开链接...')));
    } else {
      if (!context.mounted) return;
      _showLinkCopyDialog(context, url);
    }
  } catch (_) {
    _showLinkCopyDialog(context, url);
  }
}

void _showLinkCopyDialog(BuildContext context, String url) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('无法打开链接'),
      content: SelectableText(url),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: url));
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('链接已复制')));
            }
          },
          child: const Text('复制'),
        ),
      ],
    ),
  );
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
      appBar: AppBar(title: const Text('设置'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          /// 🎨 主题
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

          /// 🖼 图标
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
                trailing: Text('${settings.availableIconPacks.length} 个',
                    style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withAlpha(153))),
                onTap: () => showDialog(
                    context: context, builder: (_) => const IconPackManager()),
              ),
            ],
          ),

          const SizedBox(height: 16),

          /// 🚆 数据源
          _sectionCard(
            context,
            icon: Icons.storage,
            title: '车次数据源设置',
            children: [
              _settingsTile(context,
                  icon: Icons.cloud_upload,
                  title: 'Rail.re',
                  trailingIcon: Icons.check_circle),
              _settingsTile(context,
                  icon: Icons.train,
                  title: '12306',
                  trailingIcon: Icons.arrow_forward_ios),
            ],
          ),

          const SizedBox(height: 16),

          /// ℹ 应用信息
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

  /// ================= UI 模板层 =================

  Widget _sectionCard(BuildContext context,
      {required IconData icon,
        required String title,
        required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(children: [_sectionTitle(context, icon, title), ...children]),
    );
  }

  Widget _sectionTitle(BuildContext context, IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _settingsSwitch(BuildContext context,
      {required String title,
        required String subtitle,
        required IconData icon,
        required bool value,
        required Function(bool) onChanged}) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _settingsTile(BuildContext context,
      {IconData? icon,
        required String title,
        String? subtitle,
        Widget? trailing,
        IconData? trailingIcon,
        VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return ListTile(
      leading: icon != null
          ? Icon(icon, color: theme.colorScheme.primary)
          : null,
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing ??
          (trailingIcon != null
              ? Icon(trailingIcon,
              size: 16, color: theme.colorScheme.onSurfaceVariant)
              : null),
      onTap: onTap,
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

                Row(
                  children: [
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
}