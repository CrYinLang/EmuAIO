import 'package:flutter/material.dart';
import 'main.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于 EmuAIO-Flutter'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 28),
            _buildVersionInfo(context),
            const SizedBox(height: 28),
            _buildDataSourceSection(context),
            const SizedBox(height: 24),
            _buildCopyrightNotice(context),
            const SizedBox(height: 28),
            _buildImage(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '关于 EmuAIO 列车查询系统',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '这是一个集成了列车配属、交路查询等功能的综合性查询平台。',
          style: TextStyle(
            fontSize: 16,
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '为什么没有图标?因为版权没谈拢,但是有预设包,你可以自己制作,也可以发我审核,进行公开内置',
          style: TextStyle(
            fontSize: 16,
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildVersionInfo(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? theme.colorScheme.outlineVariant
              : Color.fromARGB(51, 0, 0, 0), // 使用 Color.fromARGB
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '版本信息',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '上次更新:${AppConstants.lastUpdate}',
                  style: TextStyle(
                    fontSize: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${AppConstants.version} | ${AppConstants.build}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color.fromARGB(
                      204, // 0.8 透明度对应 204
                      (theme.colorScheme.onSurfaceVariant.r * 255).round(),
                      (theme.colorScheme.onSurfaceVariant.g * 255).round(),
                      (theme.colorScheme.onSurfaceVariant.b * 255).round(),
                    ),
                  ),
                ),
                Text(
                  '开发：Cr.YinLang',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color.fromARGB(
                      204, // 0.8 透明度对应 204
                      (theme.colorScheme.onSurfaceVariant.r * 255).round(),
                      (theme.colorScheme.onSurfaceVariant.g * 255).round(),
                      (theme.colorScheme.onSurfaceVariant.b * 255).round(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSourceSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '数据来源',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        _buildDataSourceItemWithIconData(
          context: context,
          icon: Icons.storage,
          title: 'emu.passearch.info',
          description: '本地数据库',
        ),
        _buildDataSourceItemWithIconData(
          context: context,
          icon: Icons.cloud,
          title: 'rail.re',
          description: '联网交路查询',
        ),
        _buildDataSourceItemWithIconData(
          context: context,
          icon: Icons.cloud,
          title: '12306',
          description: '联网交路查询',
        ),
        _buildDataSourceItemWithIconData(
          context: context,
          icon: Icons.public,
          title: 'china-emu.cn',
          description: '完整动车图鉴页面',
        ),
      ],
    );
  }

  Widget _buildDataSourceItemWithIconData({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final surfaceColor = theme.colorScheme.surfaceContainerHighest;
    final outlineVariant = theme.colorScheme.outlineVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Color.fromARGB(
          128, // 0.5 透明度对应 128
          (surfaceColor.r * 255).round(),
          (surfaceColor.g * 255).round(),
          (surfaceColor.b * 255).round(),
        )
            : surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Color.fromARGB(
            77, // 0.3 透明度对应 77
            (outlineVariant.r * 255).round(),
            (outlineVariant.g * 255).round(),
            (outlineVariant.b * 255).round(),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyrightNotice(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final errorColor = isDark
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.error;

    final error = theme.colorScheme.error;
    final errorContainer = theme.colorScheme.errorContainer;
    final onErrorContainer = theme.colorScheme.onErrorContainer;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Color.fromARGB(
          51, // 0.2 透明度对应 51
          (errorContainer.r * 255).round(),
          (errorContainer.g * 255).round(),
          (errorContainer.b * 255).round(),
        )
            : errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? errorContainer
              : Color.fromARGB(
            51, // 0.2 透明度对应 51
            (error.r * 255).round(),
            (error.g * 255).round(),
            (error.b * 255).round(),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.copyright,
                color: errorColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '版权声明',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: errorColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '如您认为侵犯了您的 版权/著作权/名誉权',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: onErrorContainer,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {},
            child: Row(
              children: [
                Text(
                  '请联系: ',
                  style: TextStyle(
                    fontSize: 14,
                    color: onErrorContainer,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'iceiswpan@163.com',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.mail_outline,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '邮件联系下架修改',
            style: TextStyle(
              fontSize: 13,
              color: Color.fromARGB(
                204, // 0.8 透明度对应 204
                (onErrorContainer.r * 255).round(),
                (onErrorContainer.g * 255).round(),
                (onErrorContainer.b * 255).round(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;
    final surfaceContainerHighest = theme.colorScheme.surfaceContainerHighest;

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          height: 200,
          color: Colors.transparent,
          child: Image.asset(
            'assets/icon/banner.png',
            width: double.infinity,
            height: 200,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: double.infinity,
                height: 200,
                color: surfaceContainerHighest,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image,
                      size: 48,
                      color: Color.fromARGB(
                        128, // 0.5 透明度对应 128
                        (onSurfaceVariant.r * 255).round(),
                        (onSurfaceVariant.g * 255).round(),
                        (onSurfaceVariant.b * 255).round(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '图片加载失败',
                      style: TextStyle(
                        color: onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}