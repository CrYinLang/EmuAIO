import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'main.dart';
import 'color_theme.dart';

class UpdateService {
  static Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      final response = await http
          .get(Uri.parse(
          'https://gitee.com/CrYinLang/emu-aio/raw/master/version.json'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'error': '网络错误 ${response.statusCode}'};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}

/// ================= 对外调用入口 =================
class UpdateUI {
  static Future<void> showUpdateFlow(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CheckingDialog(),
    );

    final versionInfo = await UpdateService.checkForUpdate();

    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (_) => UpdateResultDialog(versionInfo: versionInfo),
    );
  }
}

/// ================= 检测中弹窗 =================
class _CheckingDialog extends StatelessWidget {
  const _CheckingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(strokeWidth: 4),
            ),
            SizedBox(height: 20),
            Text('正在检测更新...', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

/// ================= 更新结果弹窗 =================
class UpdateResultDialog extends StatelessWidget {
  final Map<String, dynamic>? versionInfo;

  const UpdateResultDialog({super.key, required this.versionInfo});

  @override
  Widget build(BuildContext context) {
    final currentBuild = int.tryParse(AppConstants.build) ?? 0;

    bool hasUpdate = false;
    String resultMessage = '';
    Color resultColor = AppColors.matchHigh;
    IconData resultIcon = Icons.check_circle;
    String? describeText;
    String? downloadUrl;
    String? downloadUrl1;
    String? newVersion;
    String? updateTime;

    if (versionInfo != null && versionInfo!.containsKey('error')) {
      resultMessage = '检查更新失败: ${versionInfo!['error']}';
      resultColor = AppColors.matchLow;
      resultIcon = Icons.error;
    } else if (versionInfo != null) {
      final remoteBuild = int.tryParse(versionInfo!['Build'].toString()) ?? 0;
      newVersion = versionInfo!['Version'];
      updateTime = versionInfo!['LastUpdate'];
      downloadUrl = versionInfo!['download'];
      downloadUrl1 = versionInfo!['download1'];
      describeText = versionInfo!['describe'] ?? '修复了一些已知问题';

      if (remoteBuild > currentBuild) {
        hasUpdate = true;
        resultMessage = '发现新版本 ${AppConstants.version}-->$newVersion\n\n更新时间: $updateTime\n\n更新介绍:\n$describeText\n\n请选择下载链接';
        resultColor = AppColors.matchMedium;
        resultIcon = Icons.system_update;
      } else {
        resultMessage =
        '已是最新版本\n当前版本: ${AppConstants.version} | ${AppConstants.build}';
      }
    } else {
      resultMessage = '检查更新失败: 未知错误';
      resultColor = AppColors.matchLow;
      resultIcon = Icons.error;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8, // 最大高度为屏幕的80%
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(resultIcon, size: 60, color: resultColor),
                const SizedBox(height: 20),
                Text(
                  hasUpdate ? '发现新版本' : '检查完成',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // 更新描述区域
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    resultMessage,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                if (hasUpdate) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _launchBrowser(context, downloadUrl!);
                          },
                          icon: const Icon(Icons.download),
                          label: const Text('Github'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _launchBrowser(context, downloadUrl1!);
                          },
                          icon: const Icon(Icons.download),
                          label: const Text('QQ群'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(hasUpdate ? '取消下载' : '关闭'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _launchBrowser(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('正在下载新版本')));
    }
  }
}
