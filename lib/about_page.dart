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
            _buildAnnouncementBar(context),
            const SizedBox(height: 28),
            _buildDataSourceSection(context),
            const SizedBox(height: 24),
            _buildCopyrightNotice(context),
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
        )
      ],
    );
  }

  Widget _buildAnnouncementBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FutureBuilder<Map<String, dynamic>?>(
      future: Vars.fetchVersionInfo(),
      builder: (context, snapshot) {
        const String baseText = 'EmuTrain系列的EmuAIO\n可以试试我的EmuTravel';
        String additionalText = '';
        bool hasNewVersion = false;

        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          final versionInfo = snapshot.data!;
          final remoteBuild = versionInfo['Build']?.toString() ?? '';
          final currentBuild = Vars.build;

          // 版本对比
          if (remoteBuild.isNotEmpty && currentBuild.isNotEmpty) {
            final remoteBuildNum = int.tryParse(remoteBuild) ?? 0;
            final currentBuildNum = int.tryParse(currentBuild) ?? 0;

            if (remoteBuildNum > currentBuildNum) {
              hasNewVersion = true;
              additionalText = '\n\n发现新版本${versionInfo['Version']}，更新内容：\n${versionInfo['describe'] ?? '修复了一些问题'}';
            }
          }

          // 添加远程公告
          if (!hasNewVersion) {
            final remoteAnnouncement = versionInfo['Announcement']?.toString() ?? '';
            if (remoteAnnouncement.isNotEmpty) {
              additionalText = '\n\n$remoteAnnouncement';
            }
          }
        }

        // 根据是否有新版本选择颜色
        final isWarning = hasNewVersion;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isWarning
                ? (isDark ? Color(0xFF330E0E) : Color(0xFFFFEBEE))
                : (isDark ? Color(0xFF0D1B2A) : Color(0xFFE3F2FD)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isWarning
                  ? (isDark ? Color(0xFF8C1D18) : Color(0xFFF44336))
                  : (isDark ? Color(0xFF1E3A5F) : Color(0xFF2196F3)),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isWarning ? Icons.warning_amber : Icons.info_outline,
                color: isWarning
                    ? (isDark ? Color(0xFFFAA9A3) : Color(0xFFD32F2F))
                    : (isDark ? Color(0xFF90CAF9) : Color(0xFF1565C0)),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  baseText + additionalText,
                  style: TextStyle(
                    fontSize: 14,
                    color: isWarning
                        ? (isDark ? Color(0xFFFAA9A3) : Color(0xFFB71C1C))
                        : (isDark ? Color(0xFF90CAF9) : Color(0xFF0D47A1)),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
          title: 'EmuPassearch',
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
          icon: Icons.cloud_upload,
          title: '12306',
          description: '联网交路查询',
        ),
        _buildDataSourceItemWithIconData(
          context: context,
          icon: Icons.cloud_download,
          title: 'MoeFactory',
          description: '联网车号交路查询',
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

}