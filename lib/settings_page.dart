// settings_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'tool.dart';
import 'main.dart';
import 'icon_pack.dart';
import 'update.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(title: const Text('设置'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            icon: Icons.color_lens,
            title: '主题设置',
            children: [
              _buildSwitch(
                title: '深色主题',
                subtitle: '启用深色模式',
                icon: settings.themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                value: settings.themeMode == ThemeMode.dark,
                onChanged: settings.toggleTheme,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            icon: Icons.photo_library,
            title: '图标显示设置',
            children: [
              _buildSwitch(
                title: '显示列车图标',
                subtitle: '在查询结果中显示动车组图标',
                icon: Icons.train,
                value: settings.showTrainIcons,
                onChanged: settings.toggleTrainIcons,
              ),
              _buildSwitch(
                title: '显示路局图标',
                subtitle: '在查询结果中显示路局图标',
                icon: Icons.account_balance,
                value: settings.showBureauIcons,
                onChanged: settings.toggleBureauIcons,
              ),
              _buildTile(
                icon: Icons.photo_library_outlined,
                title: '图标包管理',
                subtitle: settings.currentIconPack == 'default'
                    ? '使用默认图标包'
                    : '当前: ${settings.displayIconPackName}',
                trailing: Text('${settings.availableIconPacks.length} 个',
                    style: TextStyle(fontSize: 12, color: onSurface.withValues(alpha:0.6))),
                onTap: () => showDialog(context: context, builder: (_) => const IconPackManager()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            icon: Icons.storage,
            title: '数据源设置',
            children: [
              // 车次数据源标题
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Text(
                  '车次数据源',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: onSurface.withValues(alpha: 0.9),
                  ),
                ),
              ),
              // 车次数据源
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTrainDataSourceCard(
                        settings: settings,
                        source: TrainDataSource.railRe,
                        title: 'Rail.re',
                        description: '第三方数据源',
                        icon: Icons.cloud_upload,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Expanded(
                    //   child: _buildTrainDataSourceCard(
                    //     settings: settings,
                    //     source: TrainDataSource.railGo,
                    //     title: 'RailGo',
                    //     description: '第三方数据源',
                    //     icon: Icons.cloud_download,
                    //   ),
                    // ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTrainDataSourceCard(
                        settings: settings,
                        source: TrainDataSource.official12306,
                        title: '12306',
                        description: '官方数据源',
                        icon: Icons.train,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  settings.dataSourceDescription,
                  style: TextStyle(
                    fontSize: 12,
                    color: onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 车号数据源标题
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Text(
                  '车号数据源',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: onSurface.withValues(alpha: 0.9),
                  ),
                ),
              ),
              // 车号数据源
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildEmuDataSourceCard(
                        settings: settings,
                        source: TrainEmuDataSource.railRe,
                        title: 'Rail.re',
                        description: '第三方数据源',
                        icon: Icons.cloud_upload,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Expanded(
                    //   child: _buildEmuDataSourceCard(
                    //     settings: settings,
                    //     source: TrainEmuDataSource.railGo,
                    //     title: 'RailGo',
                    //     description: '第三方数据源',
                    //     icon: Icons.cloud_download,
                    //   ),
                    // ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildEmuDataSourceCard(
                        settings: settings,
                        source: TrainEmuDataSource.moeFactory,
                        title: 'MoeFactory',
                        description: '第三方数据源',
                        icon: Icons.train,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  settings.dataEmuSourceDescription, // 使用车号数据源的描述
                  style: TextStyle(
                    fontSize: 12,
                    color: onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            icon: Icons.info,
            title: '应用信息',
            children: [
              _buildTile(
                title: '版本',
                subtitle: '${Vars.version} | ${Vars.build}',
                trailingIcon: Icons.arrow_forward_ios,
                onTap: () => UpdateUI.showUpdateFlow(context),
              ),

              const Divider(height: 1),

              _buildTile(
                title: '开发者',
                subtitle: 'Cr.YinLang',
                trailingIcon: Icons.arrow_forward_ios,
                onTap: () => Tool.showDeveloperDialog(context),
              ),

              const Divider(height: 1),

              Tool.buildSwitch(
                context: context,
                title: '自动检测更新',
                subtitle: '在有更新时自动弹出',
                icon: Icons.browser_updated_sharp,
                value: settings.showAutoUpdate,
                onChanged: settings.toggleAutoUpdate,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required IconData icon, required String title, required List<Widget> children}) =>
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min, // 使用 min 来避免溢出
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(children: children),
            ),
          ],
        ),
      );

  Widget _buildSwitch({required String title, required String subtitle, required IconData icon,
    required bool value, required Function(bool) onChanged}) => SwitchListTile(
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
    subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.7))),
    secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
    value: value,
    onChanged: onChanged,
  );

  Widget _buildTile({IconData? icon, required String title, String? subtitle, Widget? trailing,
    IconData? trailingIcon, VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return ListTile(
      leading: icon != null ? Icon(icon, color: theme.colorScheme.primary, size: 24) : null,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle,
          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha:0.7))) : null,
      trailing: trailing ?? (trailingIcon != null ?
      Icon(trailingIcon, size: 16, color: theme.colorScheme.onSurfaceVariant) : null),
      onTap: onTap,
    );
  }

  Widget _buildTrainDataSourceCard({
    required AppSettings settings,
    required TrainDataSource source,
    required String title,
    required String description,
    required IconData icon,
  }) {
    bool isSelected = settings.dataSource == source;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (!isSelected) {
            settings.setDataSource(source);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 100),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.8)
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              if (isSelected) ...[
                const SizedBox(height: 8),
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmuDataSourceCard({
    required AppSettings settings,
    required TrainEmuDataSource source,
    required String title,
    required String description,
    required IconData icon,
  }) {
    bool isSelected = settings.dataEmuSource == source;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (!isSelected) {
            settings.setEmuDataSource(source);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 100),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.8)
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              if (isSelected) ...[
                const SizedBox(height: 8),
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}