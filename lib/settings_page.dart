//settings_page.dart
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在打开链接...')),
      );
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('链接已复制')),
              );
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
                          launchSocialLink(context, 'https://github.com/CrYinLang');
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
                          launchSocialLink(context, 'https://www.douyin.com/user/MS4wLjABAAAA-bZxFhm96BhUle209c1gQ5HskPw4y-olT2PwOYevJ6fSkkHmIV23EuGfjaq1xHCx');
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
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => const IconPackManager(),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Opacity(
              opacity: 1.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.storage,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    title: DefaultTextStyle.merge(
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      child: const Text('车次数据源设置'),
                    ),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.cloud_upload,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    title: Text(
                      'Rail.re',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    trailing: Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    onTap: null, // 禁用点击
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.train,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    title: Text(
                      '12306',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    trailing: Icon(
                      Icons.lock,
                      color: Colors.grey[500],
                      size: 18,
                    ),
                    onTap: null, // 禁用点击
                  ),
                ],
              ),
            ),
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
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onTap: () => UpdateUI.showUpdateFlow(context),
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